-- Dandy's World-inspired automation prototype.
-- For a Roblox experience you own or are authorized to test, as a LocalScript.
-- Not verified against Dandy's World. No executor or remote bypass included.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local guiParent = player:WaitForChild("PlayerGui")
local old = guiParent:FindFirstChild("DW_TestHub")
if old then old:Destroy() end

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
local targets, markers, connections = {}, {}, {}
local running = true
local SAFE_RADIUS = 45
local RETRY_DELAY = 4
local attempts = setmetatable({}, {__mode = "k"})
local status = "Idle"
local currentPrompt, currentTarget, promptUntil = nil, nil, 0
local lastTeleport = -math.huge

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
local function nearestObjective(category, position)
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
local function stopPrompt()
    if currentPrompt then pcall(function() currentPrompt:InputHoldEnd() end) end
    currentPrompt, currentTarget, promptUntil = nil, nil, 0
end
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
    if best and moveTo(best.Position) then status = "Evading to safe point" else status = "Danger: no verified safe point" end
end
local function allMachinesDone()
    local list = targets.Machine or {}
    if #list == 0 then return false end
    for _, obj in ipairs(list) do if valid(obj) and not completed(obj) then return false end end
    return true
end

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
local function clearMarker(obj)
    local m = markers[obj]; if m then m.highlight:Destroy(); m.billboard:Destroy(); markers[obj] = nil end
end
local function updateMarkers(r)
    local seen = {}; local count = 0
    for category, list in pairs(targets) do
        if settings[category] then
            for _, obj in ipairs(list) do
                if valid(obj) and not completed(obj) and count < 150 then
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
local function shutdown()
    if not running then return end
    running = false; stopPrompt()
    for _, c in ipairs(connections) do c:Disconnect() end
    for obj in pairs(markers) do clearMarker(obj) end
    if gui.Parent then gui:Destroy() end
end
stop.Activated:Connect(shutdown)
table.insert(connections, gui.Destroying:Connect(shutdown))
refresh()
local elapsed, scan = 0, 0
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
    if not running then return end
    elapsed += dt; scan += dt
    if elapsed < 0.25 then return end; elapsed = 0
    if scan >= 1 then refresh(); scan = 0 end
    local r = root(); if not r then stopPrompt(); return end
    updateMarkers(r)
    local _, threatDistance = nearestThreat(r.Position)
    if currentPrompt and (not valid(currentTarget) or completed(currentTarget) or os.clock() >= promptUntil) then stopPrompt() end
    if settings.AutoEvade and threatDistance < SAFE_RADIUS then
        stopPrompt(); evade(r.Position)
    elseif currentPrompt then
        status = "Interacting: " .. currentTarget.Name
    elseif settings.AutoElevator and allMachinesDone() then
        local obj = nearestObjective("Elevator", r.Position); if obj then interact(obj) else status = "Waiting for elevator" end
    else
        local obj = settings.AutoResearch and nearestObjective("Capsule", r.Position) or nil
        if not obj and settings.AutoMachine then obj = nearestObjective("Machine", r.Position) end
        if obj then interact(obj) else status = "Idle / no safe target" end
    end
    local stamina = player:GetAttribute("Stamina") or player.Character:GetAttribute("Stamina") or "N/A"
    local floor = workspace:GetAttribute("Floor") or "N/A"
    local skill = settings.AutoSkill and (player:GetAttribute("SkillCheckActive") and " | Skill check active" or " | Skill: monitor") or ""
    info.Text = string.format("Floor %s | Stamina %s | Threat %s\n%s%s", tostring(floor), tostring(stamina), threatDistance == math.huge and "N/A" or string.format("%.0f",threatDistance), status, skill)
end))
