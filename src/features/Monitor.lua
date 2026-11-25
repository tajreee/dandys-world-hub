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
