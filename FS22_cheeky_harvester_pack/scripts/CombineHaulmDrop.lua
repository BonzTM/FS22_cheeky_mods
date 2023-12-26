CombineHaulmDrop = {
	MOD_NAME = g_currentModName,
	SPEC_NAME = g_currentModName .. ".combineHaulmDrop"
}
CombineHaulmDrop.SPEC_TABLE_NAME = "spec_" .. CombineHaulmDrop.SPEC_NAME

function CombineHaulmDrop.prerequisitesPresent(specializations)
	return SpecializationUtil.hasSpecialization(Combine, specializations)
end

function CombineHaulmDrop.initSpecialization()
	g_workAreaTypeManager:addWorkAreaType("combineHaulmDrop", true)

	local schema = Vehicle.xmlSchema

	schema:setXMLSpecializationType("CombineHaulmDrop")
	schema:register(XMLValueType.TIME, "vehicle.combineHaulmDrop#delay", "Delay between pickup and drop", 0)
	schema:setXMLSpecializationType()
end

function CombineHaulmDrop.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "processCombineHaulmDropArea", CombineHaulmDrop.processCombineHaulmDropArea)
end

function CombineHaulmDrop.registerOverwrittenFunctions(vehicleType)
end

function CombineHaulmDrop.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", CombineHaulmDrop)
end

function CombineHaulmDrop:onLoad(savegame)
	local spec = self[CombineHaulmDrop.SPEC_TABLE_NAME]
	spec.delay = self.xmlFile:getValue("vehicle.combineHaulmDrop#delay", 0)
	spec.valueDelay = ValueDelay.new(spec.delay)
end

function CombineHaulmDrop:processCombineHaulmDropArea(workArea, dt)
	local spec = self[CombineHaulmDrop.SPEC_TABLE_NAME]
	local spec_combine = self.spec_combine
	local value = spec.valueDelay:add(spec_combine.isFilling and 1 or 0, dt)

	if value == 0 then
		return 0, 0
	end

	local fruitType = spec_combine.lastValidInputFruitType

	if fruitType ~= nil and fruitType ~= FruitType.UNKNOWN then
		local sx, _, sz = getWorldTranslation(workArea.start)
		local wx, _, wz = getWorldTranslation(workArea.width)
		local hx, _, hz = getWorldTranslation(workArea.height)
		local area = FSDensityMapUtil.updateFruitHaulmArea(fruitType, sx, sz, wx, wz, hx, hz)

		if area > 0 then
			FSDensityMapUtil.eraseTireTrack(sx, sz, wx, wz, hx, hz)
		end

		return area, area
	end

	return 0, 0
end
