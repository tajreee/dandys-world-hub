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
