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
