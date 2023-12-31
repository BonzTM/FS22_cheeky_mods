
-- Confrontation
addConstructionCategory = {};
local modDirectory = g_currentModDirectory or ""

-- Conversation
function addConstructionCategory:addOwnCategory()

    g_storeManager:addConstructionCategory("Cheeky", "Cheeky", "$dataS/menu/construction/ui_construction_icons.png", GuiUtils.getUVs("40px 160px 32px 32px",string.getVectorN("256 256", 2)),"")
		g_storeManager:addConstructionTab("Cheeky", "factories", "Factories", "$dataS/menu/construction/ui_construction_icons.dds", GuiUtils.getUVs("40px 40px 32px 32px",string.getVectorN("256 256", 2)), "")
		-- g_storeManager:addConstructionTab("Cheeky", "factoriesPlat", "Platinum Factories", "$dataS/menu/construction/ui_construction_icons.dds", GuiUtils.getUVs("40px 40px 32px 32px",string.getVectorN("256 256", 2)), "")
		-- g_storeManager:addConstructionTab("Cheeky", "factoriesPrem", "Premium Factories", "$dataS/menu/construction/ui_construction_icons.dds", GuiUtils.getUVs("40px 40px 32px 32px",string.getVectorN("256 256", 2)), "")
		g_storeManager:addConstructionTab("Cheeky", "animals", "Animals", "$dataS/menu/construction/ui_construction_icons.png", GuiUtils.getUVs("40px 120px 32px 32px",string.getVectorN("256 256", 2)), "")
		g_storeManager:addConstructionTab("Cheeky", "sellingPoints", "Selling Points", "$dataS/menu/construction/ui_construction_icons.dds", GuiUtils.getUVs("80px 120px 32px 32px",string.getVectorN("256 256", 2)), "")
		g_storeManager:addConstructionTab("Cheeky", "silos", "Silos", "$dataS/menu/construction/ui_construction_icons.dds", GuiUtils.getUVs("80px 0 32px 32px",string.getVectorN("256 256", 2)), "")
		-- g_storeManager:addConstructionTab("Cheeky", "siloExtensions", "Silo Extensions", "$dataS/menu/construction/ui_construction_icons.png", GuiUtils.getUVs("200px 0px 32px 32px",string.getVectorN("256 256", 2)), "")
        g_storeManager:addConstructionTab("Cheeky", "storages", "Storages", "$dataS/menu/construction/ui_construction_icons.dds", GuiUtils.getUVs("80px 0 32px 32px",string.getVectorN("256 256", 2)), "")
		g_storeManager:addConstructionTab("Cheeky", "greenhouses", "Greenhouses", "$dataS/menu/construction/ui_construction_icons.dds", GuiUtils.getUVs("80px 0 32px 32px",string.getVectorN("256 256", 2)), "")
		-- g_storeManager:addConstructionTab("Cheeky", "containers", "Containers", "$dataS/menu/construction/ui_construction_icons.dds", GuiUtils.getUVs("120px 0 32px 32px",string.getVectorN("256 256", 2)), "")
		
end
--Commitment
function loadMapData(xmlFile, missionInfo, baseDirectory)
    addConstructionCategory:addOwnCategory()
end


--Closure
StoreManager.loadMapData = Utils.appendedFunction(StoreManager.loadMapData, loadMapData)