
local modDirectory = g_currentModDirectory or ""
local modName = g_currentModName or "unknown"

---Init the mod.
local function init()
    print("LumberSilo main.init");
    g_placeableSpecializationManager:addSpecialization("aLumberSilo", "ALumberSilo", modDirectory .. "scripts/aLumberSilo.lua", nil)

    source(modDirectory .. "scripts/SpawnLumberAtSiloEvent.lua")
    source(modDirectory .. "scripts/LumberSiloInputEvent.lua")
    -- source(modDirectory .. "scripts/DespawnLumberAtSiloEvent.lua")
end

init()