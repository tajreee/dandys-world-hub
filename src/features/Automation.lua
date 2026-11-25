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
