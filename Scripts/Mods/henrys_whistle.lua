local mod = KCDUtils.RegisterMod({ Name = "henrys_whistle" })
HenrysWhistle = mod

local log = mod.Logger
local whistleSongs = {
    firstSong  = { "blacksmith_030","blacksmith_032","blacksmith_035","blacksmith_036" },
    secondSong = { "blacksmith_041","blacksmith_045","blacksmith_049","blacksmith_053" },
    thirdSong  = { "blacksmith_058","blacksmith_063","blacksmith_068","blacksmith_075" },
    fourthSong = { "blacksmith_mag_01","blacksmith_mag_02","blacksmith_mag_03","blacksmith_mag_04" },
    fifthSong  = { "blacksmith_mag_05","blacksmith_mag_06","blacksmith_mag_07","blacksmith_mag_08" }
}

local MIN_DELAY = 5000
local MAX_DELAY = 12000
local LOOP_MIN = 50000
local LOOP_MAX = 70000

local currentTimerId = nil
local currentSoundId = nil
local currentOwnerId = nil
local isMounted = false

local function safeStopCurrentSound()
    if currentSoundId and currentOwnerId and player then
        pcall(function()
            player:StopAudioTrigger(currentSoundId, currentOwnerId)
        end)
        currentSoundId = nil
        currentOwnerId = nil
        log:Info("Stopped current whistle sound")
    end
end

local function tryWhistle()
    if not isMounted or not player then return end

    local songKeys = {}
    for k in pairs(whistleSongs) do table.insert(songKeys, k) end
    local randomSong = whistleSongs[songKeys[math.random(#songKeys)]]
    safeStopCurrentSound()
    currentSoundId = AudioUtils.LookupTriggerID(randomSong[math.random(#randomSong)])
    currentOwnerId = player:GetDefaultAuxAudioProxyID()
    player:ExecuteAudioTrigger(currentSoundId, currentOwnerId)
    log:Info("Executed whistle sound: "..tostring(currentSoundId))
end

local function loopWhistle(nTimerId)
    tryWhistle()
    if isMounted then
        currentTimerId = Script.SetTimer(math.random(LOOP_MIN, LOOP_MAX), loopWhistle)
    else
        currentTimerId = nil
    end
end

local function startWhistleTimer()
    local delay = math.random(MIN_DELAY, MAX_DELAY)
    log:Info("Initial whistle scheduled in "..delay.." ms")
    currentTimerId = Script.SetTimer(delay, loopWhistle)
end

mod.On.MountedStateChanged = function(data)
    if data.isMounted then
        isMounted = true
        if currentTimerId then
            Script.KillTimer(currentTimerId)
            currentTimerId = nil
        end
        startWhistleTimer()
    else
        isMounted = false
        if currentTimerId then
            Script.KillTimer(currentTimerId)
            currentTimerId = nil
        end
        safeStopCurrentSound()
    end
end

local function dumpTable(t, indent, seen)
    indent = indent or ""
    seen = seen or {}

    if seen[t] then
        log:Info(indent .. "*recursive reference*")
        return
    end
    seen[t] = true

    for k, v in pairs(t) do
        local key = tostring(k)
        local valType = type(v)
        if valType == "table" then
            log:Info(indent .. key .. " = table")
            dumpTable(v, indent .. "  ", seen)
        elseif valType == "function" then
            log:Info(indent .. key .. " = function")
        else
            log:Info(indent .. key .. " = " .. tostring(v))
        end
    end
end

mod.OnGameplayStarted = function()
    KCDUtils.UI.ShowNotification("Henry's Whistle mod activated.")
    if Sound then
        log:Info("=== Sound Table Explorer Start ===")
        dumpTable(Sound)
        log:Info("=== Sound Table Explorer Ende ===")
    else
        log:Info("Sound table nicht gefunden!")
    end
end