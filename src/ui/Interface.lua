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
