local mod = KCDUtils.RegisterMod({ Name = "henrys_whistle" })

mod.Config = {
    chanceToWhistle = 100,
    triggerDelayPreset = "Medium",
    loopDelayPreset = "Medium",
    firstMount = false,
    speedThreshold = 11,
    useMod = true,
    useCombatRestriction = true,
    useGallopRestriction = true
}

local menuConfigTable = {
    { key = "useMod", type = "choice", choices = {"No","Yes"}, valueMap = {false,true}, default = mod.Config.useMod, tooltip = "Enable/disable the mod" },
    { key = "chanceToWhistle", type = "choice", choices = {"0","10","20","30","40","50","60","70","80","90","100"}, valueMap = {0,10,20,30,40,50,60,70,80,90,100}, default = mod.Config.chanceToWhistle, tooltip = "Chance to whistle (%)" },
    { key = "triggerDelayPreset", type = "choice", choices = {"Short","Medium","Long"}, valueMap = {"Short","Medium","Long"}, default = mod.Config.triggerDelayPreset, tooltip = "Initial whistle delay after mounting" },
    { key = "loopDelayPreset", type = "choice", choices = {"Short","Medium","Long"}, valueMap = {"Short","Medium","Long"}, default = mod.Config.loopDelayPreset, tooltip = "Loop whistle delay while mounted" },
    { key = "useCombatRestriction", type = "choice", choices = {"No","Yes"}, valueMap = {false,true}, default = mod.Config.useCombatRestriction, tooltip = "Enable/disable combat restriction" },
    { key = "useGallopRestriction", type = "choice", choices = {"No","Yes"}, valueMap = {false,true}, default = mod.Config.useGallopRestriction, tooltip = "Enable/disable gallop restriction" },
    { key = "speedThreshold", type = "value", min = 1, max = 50, default = mod.Config.speedThreshold, tooltip = "Minimum speed" }
}

KCDUtils.UI.MenuBuilder(mod, menuConfigTable)
HenrysWhistle = mod

local log = HenrysWhistle.Logger
local db = HenrysWhistle.DB
local config = HenrysWhistle.Config
local currentTimerId = nil
local isMounted = false
local isInCombat = false
local isInDialog = false
local isGalloping = false
local whistleEvent = nil
local triggerDelayPresets = {
    Short  = { min = 3000,  max = 6000 },
    Medium = { min = 5000,  max = 12000 },
    Long   = { min = 10000, max = 20000 }
}

local loopDelayPresets = {
    Short  = { min = 30000, max = 50000 },
    Medium = { min = 50000, max = 70000 },
    Long   = { min = 70000, max = 120000 }
}

local whistleSongs = {
    "blacksmith_030","blacksmith_032","blacksmith_035","blacksmith_036",
    "blacksmith_041","blacksmith_045","blacksmith_049","blacksmith_053",
    "blacksmith_058","blacksmith_063","blacksmith_068","blacksmith_075",
    "blacksmith_mag_01","blacksmith_mag_02","blacksmith_mag_03","blacksmith_mag_04",
    "blacksmith_mag_05","blacksmith_mag_06","blacksmith_mag_07","blacksmith_mag_08",
    "raven_whistling"
}

local function safeStopCurrentWhistle()
    KCDUtils.AudioTrigger:StopAll(mod.Name, player)
end

local function tryWhistle()
    if not isMounted or not player then return end

    local roll = math.random(0, 100)
    if roll > config.chanceToWhistle then
        log:Info("Whistle skipped due to chance roll (" .. roll .. " > " .. config.chanceToWhistle .. ")")
        return
    end

    KCDUtils.AudioTrigger:PlayRandom(mod.Name, player, whistleSongs)
end

local function loopWhistle(nTimerId)
    if nTimerId ~= currentTimerId then return end
    if whistleEvent then whistleEvent:Trigger() end
    tryWhistle()

    if isMounted then
        local preset = loopDelayPresets[config.loopDelayPreset] or loopDelayPresets.Medium
        local delayMs = math.random(preset.min, preset.max)
        currentTimerId = Script.SetTimer(delayMs, loopWhistle)
    else
        currentTimerId = nil
    end
end

local function startWhistleTimer()
    local preset = triggerDelayPresets[config.triggerDelayPreset] or triggerDelayPresets.Medium
    local delayMs = math.random(preset.min, preset.max)
    currentTimerId = Script.SetTimer(delayMs, loopWhistle)
end

local function updateWhistleState()
    if not config.useMod then
        if currentTimerId then
            Script.KillTimer(currentTimerId)
            currentTimerId = nil
            log:Info("Whistle timer killed")
        end
        safeStopCurrentWhistle()
        return
    end

    local blockedByCombat = config.useCombatRestriction and isInCombat
    local blockedByGallop = config.useGallopRestriction and isGalloping

    if not isMounted or blockedByCombat or blockedByGallop or isInDialog then
        if currentTimerId then
            Script.KillTimer(currentTimerId)
            currentTimerId = nil
        end
        safeStopCurrentWhistle()
    else
        if not config.firstMount then
            config.firstMount = true
            db:Set("firstMount", true)
            KCDUtils.UI.ShowTutorial("@ui_tutorial_hw_49oE", 8000, true)
        end
        if not currentTimerId then
            startWhistleTimer()
        end
    end
end

mod.On.MenuChanged = function(newConfig)
    for k, cfg in pairs(newConfig) do
        if cfg._selectedIndex then
            -- Choice mit valueMap
            config[k] = cfg.valueMap[cfg._selectedIndex + 1]
        elseif cfg.value ~= nil then
            -- normale value oder choice ohne valueMap
            config[k] = cfg.value
        end
    end
    KCDUtils.Config.SaveAll(mod.Name, config)
    updateWhistleState()
end

mod.On.MountedStateChanged = function(data)
    isMounted = data.isMounted
    updateWhistleState()
end

mod.On.CombatStateChanged = function(data)
    isInCombat = data.inCombat
    updateWhistleState()
end

mod.On.DialogStateChanged = function(data)
    isInDialog = data.inDialog
    updateWhistleState()
end

mod.On.DistanceTravelled = function(data)
    if player and isMounted then
        local speed = data.speed
        isGalloping = (speed > config.speedThreshold)
        updateWhistleState()
    end
end

mod.OnGameplayStarted = function()
    KCDUtils.UI.ShowNotification("@ui_notification_hw_initialized")
    whistleEvent = KCDUtils.Events.CreateEvent("WhistleTriggered")

    if player and player.human:IsMounted() then
        isMounted = true
    else
        isMounted = false
    end
    KCDUtils.Config.LoadFromDB(mod.Name, config)
    updateWhistleState()
end

----------------------------------------------------------------
--- Commands
----------------------------------------------------------------
-- #region Commands

local function toggleMod()
    config.useMod = not config.useMod
    if config.useMod then
        KCDUtils.UI.ShowNotification("@ui_notification_hw_enabled")
        log:Info("Henry's Whistle enabled.")
    else
        KCDUtils.UI.ShowNotification("@ui_notification_hw_disabled")
        log:Info("Henry's Whistle disabled.")
    end
    db:Set("useMod", config.useMod)
    updateWhistleState()
end

local function toggleCombatRestriction()
    config.useCombatRestriction = not config.useCombatRestriction
    if config.useCombatRestriction then
        log:Info("Henry's Whistle combat restriction enabled.")
    else
        log:Info("Henry's Whistle combat restriction disabled.")
    end
    db:Set("useCombatRestriction", config.useCombatRestriction)
    updateWhistleState()
end

local function toggleGallopRestriction()
    config.useGallopRestriction = not config.useGallopRestriction
    if config.useGallopRestriction then
        log:Info("Henry's Whistle gallop restriction enabled.")
    else
        log:Info("Henry's Whistle gallop restriction disabled.")
    end
    db:Set("useGallopRestriction", config.useGallopRestriction)
    updateWhistleState()
end

function HenrysWhistle:SetSpeedThreshold(param)
    local num = tonumber(param)
    if num and num > 0 then
        config.speedThreshold = num
        log:Info("Henry's Whistle speed threshold set to "..tostring(config.speedThreshold))
        updateWhistleState()
        db:Set("speedThreshold", config.speedThreshold)
    else
        log:Error("Invalid speed threshold value: "..tostring(param))
    end
end

function HenrysWhistle:SetTriggerDelayPreset(preset)
    if triggerDelayPresets[preset] then
        config.triggerDelayPreset = preset
        db:Set("triggerDelayPreset", preset)
        log:Info("Trigger delay preset set to "..preset)
        updateWhistleState()
    else
        log:Error("Invalid trigger delay preset: "..tostring(preset))
    end
end

function HenrysWhistle:SetLoopDelayPreset(preset)
    if loopDelayPresets[preset] then
        config.loopDelayPreset = preset
        db:Set("loopDelayPreset", preset)
        log:Info("Loop delay preset set to "..preset)
        updateWhistleState()
    else
        log:Error("Invalid loop delay preset: "..tostring(preset))
    end
end

function HenrysWhistle:SetWhistleChance(param)
    local num = tonumber(param)
    if num and num >= 0 and num <= 100 then
        config.chanceToWhistle = math.floor(num)  -- immer integer
        log:Info("Henry's Whistle chance to whistle set to " .. tostring(config.chanceToWhistle) .. " %")
        updateWhistleState()
        db:Set("chanceToWhistle", config.chanceToWhistle)
    else
        log:Error("Invalid chance to whistle value: " .. tostring(param) .. ". Must be between 0 and 100.")
    end
end

local function showStatus()
    log:Info("Henry's Whistle Mod Status:")
    log:Info("  Enabled: " .. tostring(config.useMod))
    log:Info("  Combat Restriction: " .. tostring(config.useCombatRestriction))
    log:Info("  Gallop Restriction: " .. tostring(config.useGallopRestriction))
    log:Info("  Speed Threshold: " .. tostring(config.speedThreshold))
    log:Info("  Trigger Delay Preset: " .. tostring(config.triggerDelayPreset))
    log:Info("  Loop Delay Preset: " .. tostring(config.loopDelayPreset))
    log:Info("  Chance to Whistle: " .. tostring(config.chanceToWhistle) .. " %")
end

local function resetConfig()
    config.chanceToWhistle = 100
    config.speedThreshold = 11
    config.triggerDelayPreset = "Medium"
    config.loopDelayPreset = "Medium"
    config.firstMount = false
    config.useMod = true
    config.useCombatRestriction = true
    config.useGallopRestriction = true

    KCDUtils.Config.SaveAll(mod.Name, config)
    log:Info("Henry's Whistle configuration reset to defaults.")
    updateWhistleState()
end

local function printHelp()
    log:Info("Henry's Whistle Commands:")
    log:Info("  hw_toggle            - Toggle the mod on/off")
    log:Info("  hw_toggle_combat     - Toggle combat restriction")
    log:Info("  hw_toggle_gallop     - Toggle gallop restriction")
    log:Info("  hw_speed <value>     - Set riding speed threshold (default: 11)")
    log:Info("  hw_trigger_delay <Short|Medium|Long> - Set initial whistle delay preset")
    log:Info("  hw_loop_delay <Short|Medium|Long>    - Set loop whistle delay preset")
    log:Info("  hw_chance <0-100>   - Chance to whistle, 0 - 100 % (default: 100 %)")
    log:Info("  hw_show_status       - Show current config")
    log:Info("  hw_reset             - Reset config to defaults")
end

--- @bindingCommand hw_toggle
--- @bindingMap movement
KCDUtils.Command.AddFunction("hw", "toggle", toggleMod, "Toggles Henry's Whistle on or off")
KCDUtils.Command.AddFunction("hw", "toggle_combat", toggleCombatRestriction, "Toggles combat restriction for Henry's Whistle")
KCDUtils.Command.AddFunction("hw", "toggle_gallop", toggleGallopRestriction, "Toggles gallop restriction for Henry's Whistle")
KCDUtils.Command.AddFunction("hw", "show_status", showStatus, "Shows current configuration and status")
KCDUtils.Command.AddFunction("hw", "reset", resetConfig, "Resets configuration to default values")
KCDUtils.Command.AddFunction("hw", "help", printHelp, "Shows help for Henry's Whistle commands")
KCDUtils.Command.Add("hw", "speed", "HenrysWhistle:SetSpeedThreshold(%1)", "Sets the speed threshold for Henry's Whistle")
KCDUtils.Command.Add("hw", "trigger_delay", "HenrysWhistle:SetTriggerDelayPreset(%1)", "Sets the initial trigger delay preset")
KCDUtils.Command.Add("hw", "loop_delay", "HenrysWhistle:SetLoopDelayPreset(%1)", "Sets the loop delay preset")
KCDUtils.Command.Add("hw", "chance", "HenrysWhistle:SetWhistleChance(%1)", "Sets the chance to whistle (0 to 100) for Henry's Whistle")