local mod = KCDUtils.RegisterMod({ Name = "henrys_whistle" })

-- mod.Config = {
--     chanceToWhistle = 1,
--     minDelay = 5000,
--     maxDelay = 12000,
--     loopMin  = 50000,
--     loopMax  = 70000,
--     firstMount = false,

--     speedThreshold = 11,
--     useMod = true,
--     useCombatRestriction = true,
--     useGallopRestriction = true
-- }

mod.Config = KCDUtils.UI.ConfigBuilder({
    chanceToWhistle = { 1, type="value", min=0, max=1, tooltip="Chance (0-1)" },
    minDelay = { 5000, type="value", min=1000, max=60000, tooltip="Minimum delay (ms)" },
    maxDelay = { 12000, type="value", min=1000, max=60000, tooltip="Maximum delay (ms)" },
    loopMin  = { 50000, type="value", min=30000, max=120000, tooltip="Minimum loop delay (ms)" },
    loopMax  = { 70000, type="value", min=30000, max=120000, tooltip="Maximum loop delay (ms)" },
    speedThreshold = { 11, type="value", min=1, max=50, tooltip="Minimum speed" },
    firstMount = { false, type="choice", choices={"Disabled", "Enabled"}, valueMap={false, true}, hidden = true },
    useMod = { true, type="choice", choices={"Off","On"}, valueMap={false,true} },
    useCombatRestriction = { true, type="choice", choices={"Off","On"}, valueMap={false,true} },
    useGallopRestriction = { true, type="choice", choices={"Off","On"}, valueMap={false,true} }
})

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
    if math.random() > config.chanceToWhistle then
        log:Info("Whistle skipped due to chance roll")
        return
    end
    KCDUtils.AudioTrigger:PlayRandom(mod.Name, player, whistleSongs)
end

local function loopWhistle(nTimerId)
    if nTimerId ~= currentTimerId then return end
    whistleEvent.Trigger()
    tryWhistle()
    if isMounted then
        currentTimerId = Script.SetTimer(math.random(config.loopMin, config.loopMax), loopWhistle)
    else
        currentTimerId = nil
    end
end

local function startWhistleTimer()
    local delay = math.random(config.minDelay, config.maxDelay)
    currentTimerId = Script.SetTimer(delay, loopWhistle)
end

local function updateWhistleState()
    if not config.useMod then
        if currentTimerId then
            Script.KillTimer(currentTimerId)
            currentTimerId = nil
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

function HenrysWhistle:SetDelayRange(line)
    local minStr, maxStr = line:match("^(%S+)%s*(%S*)$")
    maxStr = maxStr ~= "" and maxStr or minStr
    local minNum = tonumber(minStr)
    local maxNum = tonumber(maxStr)

    if minNum and maxNum and minNum > 0 and maxNum >= minNum then
        config.minDelay = minNum * 1000
        config.maxDelay = maxNum * 1000
        log:Info("Henry's Whistle delay range set to "..tostring(config.minDelay).." - "..tostring(config.maxDelay).." ms")
        updateWhistleState()
        db:Set("minDelay", config.minDelay)
        db:Set("maxDelay", config.maxDelay)
    else
        log:Error("Invalid delay range values: "..tostring(minStr)..", "..tostring(maxStr))
    end
end

function HenrysWhistle:SetLoopDelayRange(line)
    local minStr, maxStr = line:match("^(%S+)%s*(%S*)$")
    maxStr = maxStr ~= "" and maxStr or minStr
    local minNum = tonumber(minStr)
    local maxNum = tonumber(maxStr)

    if minNum and maxNum and minNum > 0 and maxNum >= minNum then
        -- Sicherstellen, dass Minimum 30 ist
        if minNum < 30 then minNum = 30 end
        if maxNum < 30 then maxNum = 30 end

        config.loopMin = minNum * 1000
        config.loopMax = maxNum * 1000
        log:Info("Henry's Whistle loop delay range set to "..tostring(config.loopMin).." - "..tostring(config.loopMax).." ms")
        updateWhistleState()
        db:Set("loopMin", config.loopMin)
        db:Set("loopMax", config.loopMax)
    else
        log:Error("Invalid loop delay range values: "..tostring(minStr)..", "..tostring(maxStr))
    end
end

function HenrysWhistle:SetWhistleChance(param)
    local num = tonumber(param)
    if num and num >= 0 and num <= 1 then
        config.chanceToWhistle = num
        log:Info("Henry's Whistle chance to whistle set to "..tostring(num * 100).." %")
        updateWhistleState()
        db:Set("chanceToWhistle", config.chanceToWhistle)
    else
        log:Error("Invalid chance to whistle value: "..tostring(param)..". Must be between 0 and 1.")
    end
end

local function showStatus()
    log:Info("Henry's Whistle Mod Status:")
    log:Info("  Enabled: " .. tostring(config.useMod))
    log:Info("  Combat Restriction: " .. tostring(config.useCombatRestriction))
    log:Info("  Gallop Restriction: " .. tostring(config.useGallopRestriction))
    log:Info("  Speed Threshold: " .. tostring(config.speedThreshold))
    log:Info("  Delay Range: " .. tostring(config.minDelay / 1000) .. " - " .. tostring(config.maxDelay / 1000) .. " seconds")
    log:Info("  Loop Delay Range: " .. tostring(config.loopMin / 1000) .. " - " .. tostring(config.loopMax / 1000) .. " seconds")
    log:Info("  Chance to Whistle: " .. tostring(config.chanceToWhistle * 100) .. " %")
end

local function resetConfig()
    config.chanceToWhistle = 0.5
    config.speedThreshold = 11
    config.minDelay = 5000
    config.maxDelay = 12000
    config.loopMin  = 50000
    config.loopMax  = 70000

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
    log:Info("  hw_toggle_combat         - Toggle combat restriction")
    log:Info("  hw_toggle_gallop         - Toggle gallop restriction")
    log:Info("  hw_speed <value>        - Set riding speed threshold (default: 11)")
    log:Info("  hw_delay <min> [max]   - Set whistle delay in seconds; max optional (default: 5-12s)")
    log:Info("  hw_loop_delay <min> [max] - Set loop delay in seconds; max optional (default: 50-70s)")
    log:Info("  hw_chance <0.0-1.0>      - Chance to whistle, 0.0-1.0 (default: 0.5 = 50%)")
    log:Info("  hw_show_status           - Show current config")
    log:Info("  hw_reset                 - Reset config to defaults")
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
KCDUtils.Command.Add("hw", "delay", "HenrysWhistle:SetDelayRange(%line)", "Sets the delay range for Henry's Whistle")
KCDUtils.Command.Add("hw", "loop_delay", "HenrysWhistle:SetLoopDelayRange(%line)", "Sets the loop delay range for Henry's Whistle")
KCDUtils.Command.Add("hw", "chance", "HenrysWhistle:SetWhistleChance(%1)", "Sets the chance to whistle (0.0 to 1.0) for Henry's Whistle")

-- #endregion Commands