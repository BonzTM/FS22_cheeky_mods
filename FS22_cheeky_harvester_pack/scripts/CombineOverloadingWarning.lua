CombineOverloadingWarning = {
	MOD_NAME = g_currentModName,
	SPEC_NAME = g_currentModName .. ".combineOverloadingWarning"
}
CombineOverloadingWarning.SPEC_TABLE_NAME = "spec_" .. CombineOverloadingWarning.SPEC_NAME

function CombineOverloadingWarning.prerequisitesPresent(specializations)
	return true
end

function CombineOverloadingWarning.initSpecialization()
end

function CombineOverloadingWarning.registerFunctions(vehicleType)
end

function CombineOverloadingWarning.registerOverwrittenFunctions(vehicleType)
end

function CombineOverloadingWarning.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", CombineOverloadingWarning)
	SpecializationUtil.registerEventListener(vehicleType, "onDraw", CombineOverloadingWarning)
end

function CombineOverloadingWarning:onLoad(savegame)
	local spec = self[CombineOverloadingWarning.SPEC_TABLE_NAME]
	spec.warningText = g_i18n:getText("warning_harvesterRequiresTrailer", CombineOverloadingWarning.MOD_NAME)
end

function CombineOverloadingWarning:onDraw(isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	if isActiveForInputIgnoreSelection and self:getIsTurnedOn() then
		local dischargeNode = self:getCurrentDischargeNode()

		if dischargeNode ~= nil and not dischargeNode.dischargeHitObject then
			local spec = self[CombineOverloadingWarning.SPEC_TABLE_NAME]

			g_currentMission:addExtraPrintText(spec.warningText)
		end
	end
end
