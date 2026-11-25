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
