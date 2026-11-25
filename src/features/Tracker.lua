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
