CropRowAdjustedNodes = {
	MOD_NAME = g_currentModName,
	SPEC_NAME = g_currentModName .. ".cropRowAdjustedNodes"
}
CropRowAdjustedNodes.SPEC_TABLE_NAME = "spec_" .. CropRowAdjustedNodes.SPEC_NAME

function CropRowAdjustedNodes.prerequisitesPresent(specializations)
	return true
end

function CropRowAdjustedNodes.initSpecialization()
	local schema = Vehicle.xmlSchema

	schema:setXMLSpecializationType("CropRowAdjustedNodes")
	schema:register(XMLValueType.FLOAT, "vehicle.cropRowAdjustedNodes#maxUpdateDistance", "If the player is more than this distance away the nodes will no longer be updated", 100)

	local adjustedNodePath = "vehicle.cropRowAdjustedNodes.adjustedNode(?)"

	schema:register(XMLValueType.NODE_INDEX, adjustedNodePath .. "#node", "Row adjusted node")
	schema:register(XMLValueType.INT, adjustedNodePath .. "#transAxis", "Translation Axis", 1)
	schema:register(XMLValueType.FLOAT, adjustedNodePath .. "#minTrans", "Min. translation value", -0.25)
	schema:register(XMLValueType.FLOAT, adjustedNodePath .. "#maxTrans", "Max. translation value", 0.25)
	schema:register(XMLValueType.FLOAT, adjustedNodePath .. "#moveSpeed", "Move speed (m/sec)", 0.25)
	schema:register(XMLValueType.FLOAT, adjustedNodePath .. "#fruitSpacing", "Spacing between plants/units", 0.7618875)
	schema:register(XMLValueType.BOOL, adjustedNodePath .. "#betweenRows", "Defines if the node is aligned on the rows or the middle between the rows", true)
	schema:register(XMLValueType.STRING, adjustedNodePath .. "#fruitTypes", "List of supported fruit types separated by a whitespace", "maize potato sunflower")
	schema:register(XMLValueType.FLOAT, adjustedNodePath .. ".foldable#minLimit", "Fold min. time", 0)
	schema:register(XMLValueType.FLOAT, adjustedNodePath .. ".foldable#maxLimit", "Fold max. time", 1)
	schema:setXMLSpecializationType()
end

function CropRowAdjustedNodes.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "loadCropRowAdjustedNodeFromXML", CropRowAdjustedNodes.loadCropRowAdjustedNodeFromXML)
	SpecializationUtil.registerFunction(vehicleType, "updateCropRowAdjustedNode", CropRowAdjustedNodes.updateCropRowAdjustedNode)
	SpecializationUtil.registerFunction(vehicleType, "getIsCropRowAdjustedNodeActive", CropRowAdjustedNodes.getIsCropRowAdjustedNodeActive)
end

function CropRowAdjustedNodes.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", CropRowAdjustedNodes)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", CropRowAdjustedNodes)
end

function CropRowAdjustedNodes:onLoad(savegame)
	local spec = self[CropRowAdjustedNodes.SPEC_TABLE_NAME]
	spec.raycastNodesByNode = {}
	spec.maxUpdateDistance = self.xmlFile:getValue("vehicle.cropRowAdjustedNodes#maxUpdateDistance", 100)
	spec.adjustedNodes = {}

	self.xmlFile:iterate("vehicle.cropRowAdjustedNodes.adjustedNode", function (index, key)
		local adjustedNode = {}

		if self:loadCropRowAdjustedNodeFromXML(self.xmlFile, key, adjustedNode) then
			table.insert(spec.adjustedNodes, adjustedNode)
		end
	end)

	if #spec.adjustedNodes == 0 then
		SpecializationUtil.removeEventListener(self, "onUpdate", CropRowAdjustedNodes)
	end
end

function CropRowAdjustedNodes:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	local spec = self[CropRowAdjustedNodes.SPEC_TABLE_NAME]

	if self.currentUpdateDistance < spec.maxUpdateDistance then
		for _, adjustedNode in pairs(spec.adjustedNodes) do
			self:updateCropRowAdjustedNode(adjustedNode, dt)
		end
	end
end

function CropRowAdjustedNodes:loadCropRowAdjustedNodeFromXML(xmlFile, key, adjustedNode)
	adjustedNode.node = xmlFile:getValue(key .. "#node", nil, self.components, self.i3dMappings)

	if adjustedNode.node ~= nil then
		adjustedNode.referenceFrame = createTransformGroup("cropRowAdjustedNodeRefFrame")

		link(getParent(adjustedNode.node), adjustedNode.referenceFrame)
		setTranslation(adjustedNode.referenceFrame, getTranslation(adjustedNode.node))
		setRotation(adjustedNode.referenceFrame, getRotation(adjustedNode.node))

		adjustedNode.startTrans = {
			getTranslation(adjustedNode.node)
		}
		adjustedNode.curTrans = {
			getTranslation(adjustedNode.node)
		}
		adjustedNode.transAxis = xmlFile:getValue(key .. "#transAxis", 1)
		adjustedNode.minTrans = xmlFile:getValue(key .. "#minTrans", -0.25)
		adjustedNode.maxTrans = xmlFile:getValue(key .. "#maxTrans", 0.25)
		adjustedNode.moveSpeed = xmlFile:getValue(key .. "#moveSpeed", 0.25) / 1000
		adjustedNode.fruitSpacing = xmlFile:getValue(key .. "#fruitSpacing", 0.7618875)
		adjustedNode.betweenRows = xmlFile:getValue(key .. "#betweenRows", true)
		adjustedNode.fruitTypes = {}
		local fruitTypesStr = xmlFile:getValue(key .. "#fruitTypes", "maize potato sunflower")

		if fruitTypesStr ~= nil then
			local fruitTypes = fruitTypesStr:split(" ")

			for _, fruitTypeName in pairs(fruitTypes) do
				local fruitType = g_fruitTypeManager:getFruitTypeByName(fruitTypeName)

				if fruitType ~= nil then
					adjustedNode.fruitTypes[fruitType.index] = true
				end
			end
		end

		if next(adjustedNode.fruitTypes) ~= nil then
			adjustedNode.foldMinLimit = xmlFile:getValue(key .. ".foldable#minLimit", 0)
			adjustedNode.foldMaxLimit = xmlFile:getValue(key .. ".foldable#maxLimit", 1)

			return true
		else
			Logging.xmlWarning(xmlFile, "Missing fruit types in '%s'", key)
		end
	else
		Logging.xmlWarning(xmlFile, "Missing node in '%s'", key)
	end

	return false
end

CropRowAdjustedNodes.MAX_ACTIVE_ANGLE = math.rad(10)

local function rasterize(x, z, spacing, terrainSize, betweenRows)
	local halfMapSize = terrainSize * 0.5

	if betweenRows then
		halfMapSize = halfMapSize - spacing * 0.5
	end

	z = z + halfMapSize
	x = x + halfMapSize
	local rasteredX = MathUtil.round(x / spacing) * spacing
	local rasteredZ = MathUtil.round(z / spacing) * spacing

	return -halfMapSize + rasteredX, -halfMapSize + rasteredZ
end

function CropRowAdjustedNodes:updateCropRowAdjustedNode(adjustedNode, dt)
	local wasActive = adjustedNode.isActive
	adjustedNode.isActive = self:getIsCropRowAdjustedNodeActive(adjustedNode)

	if adjustedNode.isActive then
		local wx, _, wz = getWorldTranslation(adjustedNode.referenceFrame)
		local rasteredX1, rasteredZ1 = rasterize(wx, wz, adjustedNode.fruitSpacing, g_currentMission.terrainSize, adjustedNode.betweenRows)
		local wx2, _, wz2 = localToWorld(adjustedNode.referenceFrame, 0, 0, adjustedNode.fruitSpacing + 0.1)
		local rasteredX2, rasteredZ2 = rasterize(wx2, wz2, adjustedNode.fruitSpacing, g_currentMission.terrainSize, adjustedNode.betweenRows)
		local normlineDirX, normlineDirZ = MathUtil.vector2Normalize(rasteredX2 - rasteredX1, rasteredZ2 - rasteredZ1)
		local lineX = rasteredX1 - normlineDirX
		local lineZ = rasteredZ1 - normlineDirZ
		local signedDistance = MathUtil.getSignedDistanceToLineSegment2D(wx, wz, lineX, lineZ, normlineDirX, normlineDirZ, adjustedNode.fruitSpacing + 1)
		local transX = MathUtil.clamp(-signedDistance, adjustedNode.startTrans[adjustedNode.transAxis] + adjustedNode.minTrans, adjustedNode.startTrans[adjustedNode.transAxis] + adjustedNode.maxTrans)
		adjustedNode.targetTrans = transX
		local difference = adjustedNode.targetTrans - adjustedNode.curTrans[adjustedNode.transAxis]

		if math.abs(difference) > 0.001 then
			adjustedNode.isDirty = true
		end
	elseif wasActive then
		adjustedNode.targetTrans = adjustedNode.startTrans[adjustedNode.transAxis]
		adjustedNode.isDirty = true
	end

	if adjustedNode.isDirty then
		adjustedNode.curTrans[1], adjustedNode.curTrans[2], adjustedNode.curTrans[3] = getTranslation(adjustedNode.node)
		local difference = adjustedNode.targetTrans - adjustedNode.curTrans[adjustedNode.transAxis]

		if math.abs(difference) > 0.001 then
			local direction = MathUtil.sign(difference)
			local limit = direction > 0 and math.min or math.max
			adjustedNode.curTrans[adjustedNode.transAxis] = limit(adjustedNode.curTrans[adjustedNode.transAxis] + direction * adjustedNode.moveSpeed * dt, adjustedNode.targetTrans)

			setTranslation(adjustedNode.node, adjustedNode.curTrans[1], adjustedNode.curTrans[2], adjustedNode.curTrans[3])

			if self.setMovingToolDirty ~= nil then
				self:setMovingToolDirty(adjustedNode.node)
			end
		else
			adjustedNode.isDirty = false
		end
	end
end

function CropRowAdjustedNodes:getIsCropRowAdjustedNodeActive(adjustedNode)
	local spec_foldable = self.spec_foldable

	if spec_foldable ~= nil then
		local foldAnimTime = spec_foldable.foldAnimTime

		if foldAnimTime ~= nil and (adjustedNode.foldMaxLimit < foldAnimTime or foldAnimTime < adjustedNode.foldMinLimit) then
			return false
		end
	end

	if self.getIsLowered == nil or not self:getIsLowered() then
		return false
	end

	local wx, _, wz = getWorldTranslation(adjustedNode.referenceFrame)
	local fruitTypeIndex, _ = FSDensityMapUtil.getFruitTypeIndexAtWorldPos(wx, wz)

	if adjustedNode.fruitTypes[fruitTypeIndex] == nil then
		return false
	end

	local dx, _, dz = localDirectionToWorld(adjustedNode.referenceFrame, 0, 0, 1)
	local yRot = MathUtil.getYRotationFromDirection(MathUtil.vector2Normalize(dx, dz))
	yRot = yRot % (math.pi * 0.5)

	if math.abs(yRot) < CropRowAdjustedNodes.MAX_ACTIVE_ANGLE or math.abs(yRot) > 1.5708 - CropRowAdjustedNodes.MAX_ACTIVE_ANGLE then
		return true
	end

	return false
end
