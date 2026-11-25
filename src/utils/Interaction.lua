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
