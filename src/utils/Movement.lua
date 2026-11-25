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
