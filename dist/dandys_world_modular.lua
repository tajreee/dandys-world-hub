-- Dandy's World-inspired prototype for experiences you own or are authorized to test.
-- Not verified against the public game. No executor or remote bypass is included.
-- Module: core/Config
local Config = (function()
return function()
    local settings = {
        Machine = true, Twisted = true, Capsule = true,
        Item = true, Elevator = true, Player = true,
        AutoResearch = false, AutoMachine = false, AutoEvade = false,
        AutoElevator = false, AutoSkill = false,
    }
    local colors = {
        Machine = Color3.fromRGB(75, 208, 255), Twisted = Color3.fromRGB(255, 85, 100),
        Capsule = Color3.fromRGB(193, 124, 255), Item = Color3.fromRGB(255, 205, 90),
        Elevator = Color3.fromRGB(90, 225, 150), Player = Color3.fromRGB(235, 235, 235),
    }
    -- Tag objective Models or BaseParts in your own Studio place with these tags.
    local tags = { Machine = "DW_Machine", Twisted = "DW_Twisted", Capsule = "DW_Capsule", Item = "DW_Item", Elevator = "DW_Elevator" }
    return {settings = settings, colors = colors, tags = tags, safeRadius = 45, retryDelay = 4, tickInterval = 0.25, scanInterval = 1, markerLimit = 150}
end
end)()

-- Module: core/Registry
local Registry = (function()
return function(player, config)
    local Players = game:GetService("Players")
    local CollectionService = game:GetService("CollectionService")
    local tags = config.tags
    local SAFE_RADIUS = config.safeRadius
    local RETRY_DELAY = config.retryDelay
    local targets = {}

    local function partOf(object)
        if not object then return nil end
        if object:IsA("BasePart") then return object end
        if object:IsA("Model") then
            return object.PrimaryPart or object:FindFirstChild("HumanoidRootPart") or object:FindFirstChildWhichIsA("BasePart", true)
        end
    end
    local function root()
        local c = player.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if not h or h.Health <= 0 then return nil end
        return c:FindFirstChild("HumanoidRootPart")
    end
    local function valid(object)
        return object and object:IsDescendantOf(workspace) and partOf(object) ~= nil
    end
    local function completed(object)
        local progress = object:GetAttribute("Progress") -- convention: 0..1
        return object:GetAttribute("Completed") == true or object:GetAttribute("Collected") == true or (type(progress) == "number" and progress >= 1)
    end
    local function refresh()
        for category, tag in pairs(tags) do
            targets[category] = {}
            for _, obj in ipairs(CollectionService:GetTagged(tag)) do
                if valid(obj) then table.insert(targets[category], obj) end
            end
        end
        targets.Player = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and valid(p.Character) then table.insert(targets.Player, p.Character) end
        end
    end
    local function nearestThreat(position)
        local best, distance = nil, math.huge
        for _, obj in ipairs(targets.Twisted or {}) do
            local p = valid(obj) and partOf(obj)
            if p then
                local d = (position - p.Position).Magnitude
                if d < distance then best, distance = obj, d end
            end
        end
        return best, distance
    end
    local function safeAt(position)
        local _, distance = nearestThreat(position)
        return distance >= SAFE_RADIUS
    end
    local function nearestObjective(category, position, attempts)
        local best, distance = nil, math.huge
        for _, obj in ipairs(targets[category] or {}) do
            local p = valid(obj) and partOf(obj)
            if p and not completed(obj) and (not attempts[obj] or os.clock() - attempts[obj] >= RETRY_DELAY) and safeAt(p.Position) then
                local d = (position - p.Position).Magnitude
                if d < distance then best, distance = obj, d end
            end
        end
        return best
    end

    local function allMachinesDone()
        local list = targets.Machine or {}
        if #list == 0 then return false end
        for _, obj in ipairs(list) do if valid(obj) and not completed(obj) then return false end end
        return true
    end

    return {
        partOf = partOf, root = root, valid = valid, completed = completed,
        refresh = refresh, targets = targets, nearestThreat = nearestThreat,
        safeAt = safeAt, nearestObjective = nearestObjective, allMachinesDone = allMachinesDone,
    }
end
end)()

-- Module: utils/Movement
local Movement = (function()
return function(player, registry)
    local root, safeAt = registry.root, registry.safeAt
    local lastTeleport = -math.huge

    -- Only moves to explicitly designated safe/test locations in an authorized map.
    local function moveTo(position)
        local r = root()
        if not r or not safeAt(position) or os.clock() - lastTeleport < 1 then return false end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {player.Character}
        local hit = workspace:Raycast(position + Vector3.new(0, 5, 0), Vector3.new(0, -18, 0), params)
        if not hit or hit.Normal.Y < 0.7 then return false end
        local landing = hit.Position + Vector3.new(0, 3, 0)
        if not safeAt(landing) then return false end
        local overlap = OverlapParams.new()
        overlap.FilterType = Enum.RaycastFilterType.Exclude
        overlap.FilterDescendantsInstances = {player.Character}
        for _, obstruction in ipairs(workspace:GetPartBoundsInBox(CFrame.new(landing), Vector3.new(2.5, 4.5, 2.5), overlap)) do
            if obstruction.CanCollide then return false end
        end
        r.AssemblyLinearVelocity = Vector3.zero
        player.Character:PivotTo(CFrame.new(landing))
        lastTeleport = os.clock()
        return true
    end

    return {moveTo = moveTo}
end
end)()

-- Module: utils/Interaction
local Interaction = (function()
return function(player, registry, movement)
    local valid, partOf, root = registry.valid, registry.partOf, registry.root
    local moveTo = movement.moveTo
    local attempts = setmetatable({}, {__mode = "k"})
    local status = "Idle"
    local currentPrompt, currentTarget, promptUntil = nil, nil, 0

    local function stopPrompt()
        if currentPrompt then pcall(function() currentPrompt:InputHoldEnd() end) end
        currentPrompt, currentTarget, promptUntil = nil, nil, 0
    end

    local function interact(obj)
        if not valid(obj) then return end
        local p = partOf(obj)
        local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
        if not prompt or not prompt.Enabled then attempts[obj] = os.clock(); status = "No enabled prompt: " .. obj.Name; return end
        local anchor = prompt.Parent
        local pos = p.Position
        if anchor:IsA("Attachment") then pos = anchor.WorldPosition elseif anchor:IsA("BasePart") then pos = anchor.Position end
        local r = root()
        if not r then return end
        if (r.Position - pos).Magnitude > math.min(prompt.MaxActivationDistance, 5) then
            local offset = Vector3.new(r.Position.X - pos.X, 0, r.Position.Z - pos.Z)
            if offset.Magnitude < 0.01 then offset = Vector3.new(1, 0, 0) end
            if not moveTo(pos + offset.Unit * 3) then attempts[obj] = os.clock(); status = "No safe landing"; return end
        end
        r = root()
        if not r or (r.Position - pos).Magnitude > prompt.MaxActivationDistance then attempts[obj] = os.clock(); return end
        if prompt.RequiresLineOfSight then
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = {player.Character}
            local hit = workspace:Raycast(r.Position, pos - r.Position, params)
            if hit and hit.Instance ~= obj and not hit.Instance:IsDescendantOf(obj) then attempts[obj] = os.clock(); status = "Prompt obstructed"; return end
        end
        attempts[obj] = os.clock()
        local ok = pcall(function() prompt:InputHoldBegin() end)
        if ok then currentPrompt, currentTarget = prompt, obj; promptUntil = os.clock() + math.max(prompt.HoldDuration, 0.1) + 0.15 end
        status = ok and ("Interacting: " .. obj.Name) or "Interaction unavailable"
    end

    return {
        attempts = attempts, stop = stopPrompt, interact = interact,
        active = function() return currentPrompt, currentTarget, promptUntil end,
        status = function() return status end,
    }
end
end)()

-- Module: features/Evade
local Evade = (function()
return function(registry, movement)
    local CollectionService = game:GetService("CollectionService")
    local valid, partOf = registry.valid, registry.partOf
    local safeAt, nearestThreat = registry.safeAt, registry.nearestThreat
    local moveTo = movement.moveTo

    local function evade(position)
        local best, score = nil, -math.huge
        for _, obj in ipairs(CollectionService:GetTagged("DW_SafePoint")) do
            local p = valid(obj) and partOf(obj)
            if p and safeAt(p.Position) then
                local _, dist = nearestThreat(p.Position)
                local value = math.min(dist, 250) - (position - p.Position).Magnitude * 0.2
                if value > score then best, score = p, value end
            end
        end
        if best and moveTo(best.Position) then return "Evading to safe point" end
        return "Danger: no verified safe point"
    end

    return {run = evade}
end
end)()

-- Module: ui/Interface
local Interface = (function()
return function(guiParent, config)
    local settings = config.settings

    local gui = Instance.new("ScreenGui")
    gui.Name = "DW_TestHub"; gui.ResetOnSpawn = false; gui.Parent = guiParent
    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.fromOffset(318, 500); frame.Position = UDim2.new(0, 20, 0.5, -250)
    frame.BackgroundColor3 = Color3.fromRGB(24, 27, 36); frame.BorderSizePixel = 0
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)
    local function label(parent, text, height)
        local l = Instance.new("TextLabel", parent)
        l.Size = UDim2.new(1, -16, 0, height); l.BackgroundTransparency = 1
        l.Text = text; l.TextColor3 = Color3.fromRGB(232, 237, 245); l.TextSize = 13
        l.Font = Enum.Font.Gotham; l.TextWrapped = true; return l
    end
    local title = label(frame, "DW / Authorized Test Hub", 36); title.Position = UDim2.fromOffset(8, 0); title.TextSize = 17
    local body = Instance.new("ScrollingFrame", frame)
    body.Position = UDim2.fromOffset(8, 38); body.Size = UDim2.new(1, -16, 1, -120)
    body.BackgroundTransparency = 1; body.BorderSizePixel = 0; body.ScrollBarThickness = 4
    body.CanvasSize = UDim2.new(); body.AutomaticCanvasSize = Enum.AutomaticSize.Y
    local layout = Instance.new("UIListLayout", body); layout.Padding = UDim.new(0, 5)
    local function toggle(key, caption)
        local b = Instance.new("TextButton", body); b.Size = UDim2.new(1, -8, 0, 32); b.BorderSizePixel = 0
        b.Font = Enum.Font.Gotham; b.TextSize = 13; b.TextColor3 = Color3.new(1,1,1)
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        local function draw()
            b.Text = caption .. (settings[key] and "  [ON]" or "  [OFF]")
            b.BackgroundColor3 = settings[key] and Color3.fromRGB(35, 100, 83) or Color3.fromRGB(52, 56, 70)
        end
        draw(); b.Activated:Connect(function() settings[key] = not settings[key]; draw() end)
    end
    for _, pair in ipairs({{"Machine", "Machine tracker"}, {"Twisted", "Twisted tracker"}, {"Capsule", "Research tracker"}, {"Item", "Item tracker"}, {"Elevator", "Elevator tracker"}, {"Player", "Player tracker"}, {"AutoResearch", "Auto research"}, {"AutoMachine", "Auto machine"}, {"AutoEvade", "Auto evade"}, {"AutoElevator", "Auto elevator"}, {"AutoSkill", "Skill check monitor"}}) do toggle(pair[1], pair[2]) end
    local info = label(frame, "Starting", 47); info.Position = UDim2.new(0, 8, 1, -79); info.TextSize = 12
    local stop = Instance.new("TextButton", frame); stop.Size = UDim2.new(1, -16, 0, 25); stop.Position = UDim2.new(0, 8, 1, -28); stop.Text = "STOP / CLOSE"; stop.BackgroundColor3 = Color3.fromRGB(120, 45, 56); stop.TextColor3 = Color3.new(1,1,1); stop.BorderSizePixel = 0

    return {gui = gui, info = info, stop = stop, label = label}
end
end)()

-- Module: features/Tracker
local Tracker = (function()
return function(registry, ui, config)
    local gui, label = ui.gui, ui.label
    local settings, colors = config.settings, config.colors
    local targets, valid, completed, partOf = registry.targets, registry.valid, registry.completed, registry.partOf
    local markers = {}

    local function clearMarker(obj)
        local m = markers[obj]; if m then m.highlight:Destroy(); m.billboard:Destroy(); markers[obj] = nil end
    end
    local function updateMarkers(r)
        local seen = {}; local count = 0
        for category, list in pairs(targets) do
            if settings[category] then
                for _, obj in ipairs(list) do
                    if valid(obj) and not completed(obj) and count < config.markerLimit then
                        count += 1; seen[obj] = true
                        local p = partOf(obj); local m = markers[obj]
                        if not m then
                            local highlight = Instance.new("Highlight", gui); highlight.Adornee = obj; highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; highlight.FillColor = colors[category]; highlight.OutlineColor = colors[category]; highlight.FillTransparency = 0.8
                            local billboard = Instance.new("BillboardGui", gui); billboard.Adornee = p; billboard.Size = UDim2.fromOffset(180, 34); billboard.StudsOffset = Vector3.new(0, 3, 0); billboard.AlwaysOnTop = true
                            local txt = label(billboard, "", 34); txt.TextColor3 = colors[category]; txt.TextStrokeTransparency = 0.3
                            m = {highlight = highlight, billboard = billboard, text = txt}; markers[obj] = m
                        end
                        local progress = obj:GetAttribute("Progress")
                        local extra = category == "Machine" and type(progress) == "number" and string.format(" | %.0f%%", math.clamp(progress,0,1)*100) or ""
                        m.text.Text = string.format("%s | %.0f studs%s", obj.Name, (r.Position-p.Position).Magnitude, extra)
                    end
                end
            end
        end
        for obj in pairs(markers) do if not seen[obj] then clearMarker(obj) end end
    end

    local function clear()
        for obj in pairs(markers) do clearMarker(obj) end
    end
    return {update = updateMarkers, clear = clear}
end
end)()

-- Module: features/Automation
local Automation = (function()
return function(config, registry, interaction, evade)
    local settings = config.settings
    local function step(root)
        local _, threatDistance = registry.nearestThreat(root.Position)
        local prompt, target, deadline = interaction.active()
        if prompt and (not registry.valid(target) or registry.completed(target) or os.clock() >= deadline) then
            interaction.stop()
            prompt, target = nil, nil
        end
        local function nextTarget(category)
            return registry.nearestObjective(category, root.Position, interaction.attempts)
        end
        local function interactWith(object)
            interaction.interact(object)
            return interaction.status()
        end
        local status
        if settings.AutoEvade and threatDistance < config.safeRadius then
            interaction.stop()
            status = evade.run(root.Position)
        elseif prompt then
            status = "Interacting: " .. target.Name
        elseif settings.AutoElevator and registry.allMachinesDone() then
            local object = nextTarget("Elevator")
            status = object and interactWith(object) or "Waiting for elevator"
        else
            local object = settings.AutoResearch and nextTarget("Capsule") or nil
            if not object and settings.AutoMachine then object = nextTarget("Machine") end
            status = object and interactWith(object) or "Idle / no safe target"
        end
        return status, threatDistance
    end
    return {step = step, stop = interaction.stop}
end
end)()

-- Module: features/Monitor
local Monitor = (function()
return function(player, config, ui)
    local function update(status, threatDistance)
        local character = player.Character
        local stamina = player:GetAttribute("Stamina") or (character and character:GetAttribute("Stamina")) or "N/A"
        local floor = workspace:GetAttribute("Floor") or "N/A"
        local skill = config.settings.AutoSkill and (player:GetAttribute("SkillCheckActive") and " | Skill check active" or " | Skill: monitor") or ""
        ui.info.Text = string.format("Floor %s | Stamina %s | Threat %s\n%s%s", tostring(floor), tostring(stamina), threatDistance == math.huge and "N/A" or string.format("%.0f",threatDistance), status, skill)
    end
    return {update = update}
end
end)()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
assert(player, "This prototype must run as a LocalScript")
local guiParent = player:WaitForChild("PlayerGui")
local old = guiParent:FindFirstChild("DW_TestHub")
if old then old:Destroy() end

local config = Config()
local registry = Registry(player, config)
local movement = Movement(player, registry)
local interaction = Interaction(player, registry, movement)
local evade = Evade(registry, movement)
local ui = Interface(guiParent, config)
local tracker = Tracker(registry, ui, config)
local automation = Automation(config, registry, interaction, evade)
local monitor = Monitor(player, config, ui)
local running = true
local connections = {}

local function shutdown()
    if not running then return end
    running = false
    automation.stop()
    for _, connection in ipairs(connections) do connection:Disconnect() end
    table.clear(connections)
    tracker.clear()
    if ui.gui.Parent then ui.gui:Destroy() end
end

table.insert(connections, ui.stop.Activated:Connect(shutdown))
table.insert(connections, ui.gui.Destroying:Connect(shutdown))
registry.refresh()
local elapsed, scan = 0, 0
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
    if not running then return end
    elapsed += dt
    scan += dt
    if elapsed < config.tickInterval then return end
    elapsed = 0
    if scan >= config.scanInterval then registry.refresh(); scan = 0 end
    local root = registry.root()
    if not root then automation.stop(); tracker.clear(); return end
    tracker.update(root)
    local status, threatDistance = automation.step(root)
    monitor.update(status, threatDistance)
end))
