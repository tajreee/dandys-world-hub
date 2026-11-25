-- Dandy's World-inspired prototype for experiences you own or are authorized to test.
-- Not verified against the public game. No executor or remote bypass is included.
-- BEGIN IMPORTS
local Config = require(script.Parent.core.Config)
local Registry = require(script.Parent.core.Registry)
local Movement = require(script.Parent.utils.Movement)
local Interaction = require(script.Parent.utils.Interaction)
local Evade = require(script.Parent.features.Evade)
local Interface = require(script.Parent.ui.Interface)
local Tracker = require(script.Parent.features.Tracker)
local Automation = require(script.Parent.features.Automation)
local Monitor = require(script.Parent.features.Monitor)
-- END IMPORTS

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
assert(player, "This prototype must run as a LocalScript")
local guiParent = player:WaitForChild("PlayerGui")
local old = guiParent:FindFirstChild("DW_TestHub")
if old then old:Destroy() end

local config = Config()
local registry = Registry(player, config)
local movement = Movement(player, registry)
local interaction = Interaction(player, registry, movement)
local evade = Evade(registry, movement)
local ui = Interface(guiParent, config)
local tracker = Tracker(registry, ui, config)
local automation = Automation(config, registry, interaction, evade)
local monitor = Monitor(player, config, ui)
local running = true
local connections = {}

local function shutdown()
    if not running then return end
    running = false
    automation.stop()
    for _, connection in ipairs(connections) do connection:Disconnect() end
    table.clear(connections)
    tracker.clear()
    if ui.gui.Parent then ui.gui:Destroy() end
end

table.insert(connections, ui.stop.Activated:Connect(shutdown))
table.insert(connections, ui.gui.Destroying:Connect(shutdown))
registry.refresh()
local elapsed, scan = 0, 0
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
    if not running then return end
    elapsed += dt
    scan += dt
    if elapsed < config.tickInterval then return end
    elapsed = 0
    if scan >= config.scanInterval then registry.refresh(); scan = 0 end
    local root = registry.root()
    if not root then automation.stop(); tracker.clear(); return end
    tracker.update(root)
    local status, threatDistance = automation.step(root)
    monitor.update(status, threatDistance)
end))
