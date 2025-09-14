------------------------------------------------------------
--- Define the main mod table / namespace.
--- This ensures that HenrysWhistle exists and can
--- store all mod-related data and functions.
------------------------------------------------------------
HenrysWhistle = HenrysWhistle or {} -- die Mod-Tabelle

------------------------------------------------------------
--- 1. Config table with default values.
--- Use this table to store mod settings that can be
--- saved and loaded from the database.
--- Example: SomeSetting = "Default Value"
------------------------------------------------------------
HenrysWhistle.Config = HenrysWhistle.Config or {
    SomeSetting = "Default Value",
    AnotherSetting = 42,
    YetAnotherSetting = true
}

------------------------------------------------------------
--- 2. ConfigMethods namespace.
--- All methods that interact with the Config table
--- are grouped here, keeping the main namespace clean.
------------------------------------------------------------
HenrysWhistle.ConfigMethods = HenrysWhistle.ConfigMethods or {}

------------------------------------------------------------
--- Load(): reads saved settings from the database
--- into HenrysWhistle.Config.
------------------------------------------------------------
function HenrysWhistle.ConfigMethods.Load()
    KCDUtils.Config.LoadFromDB("HenrysWhistle", HenrysWhistle.Config)
end

------------------------------------------------------------
--- Save(): writes the current config table to the database.
------------------------------------------------------------
function HenrysWhistle.ConfigMethods.Save()
    KCDUtils.Config.SaveAll("HenrysWhistle", HenrysWhistle.Config)
end

------------------------------------------------------------
--- Dump(): prints the current config table to the console/log
--- for debugging purposes.
------------------------------------------------------------
function HenrysWhistle.ConfigMethods.Dump()
    KCDUtils.Config.Dump("HenrysWhistle")
end

------------------------------------------------------------
--- Initial load of the config when the mod starts.
------------------------------------------------------------
HenrysWhistle.ConfigMethods.Load() -- Initiales Laden der Config
