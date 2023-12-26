CombinedEffect = {
	STATE_OFF = 0,
	STATE_TURNING_ON = 1,
	STATE_ON = 2,
	STATE_TURNING_OFF = 3
}
local CombinedEffect_mt = Class(CombinedEffect, Effect)

function CombinedEffect.new(customMt)
	local self = Effect.new(customMt or CombinedEffect_mt)

	return self
end

function CombinedEffect:load(xmlFile, baseName, rootNodes, parent, i3dMapping)
	self.parent = parent
	self.effects = g_effectManager:loadEffect(xmlFile, baseName, rootNodes, parent, i3dMapping)
	self.state = CombinedEffect.STATE_OFF
	self.fadeIn = 0
	self.fadeOut = 0
	self.fadeDuration = 0

	for i, effect in ipairs(self.effects) do
		if effect:isa(MotionPathEffect) then
			self.fadeDuration = math.max(effect.delay + 1 / effect.effectSpeedScaleOrig, self.fadeDuration)
			effect.minDensity = 1
		elseif effect:isa(MorphPositionEffect) then
			self.fadeDuration = math.max((effect.startDelay + effect.fadeInTime) * 0.001, self.fadeDuration)
		end

		local key = string.format("%s.effectNode(%d)", baseName, i - 1)
		effect.testAreaSubIndex = xmlFile:getInt(key .. "#testAreaSubIndex")
	end

	self.testAreaIndex = xmlFile:getInt(baseName .. "#testAreaIndex")

	return self
end

function CombinedEffect:delete()
	for _, effect in ipairs(self.effects) do
		effect:delete()
	end
end

function CombinedEffect:update(dt)
	if self.state == CombinedEffect.STATE_TURNING_ON then
		self.fadeIn = math.min(self.fadeIn + dt * 0.001 / self.fadeDuration, 1)

		if self.fadeIn == 1 then
			self.state = CombinedEffect.STATE_ON
		end
	elseif self.state == CombinedEffect.STATE_TURNING_OFF then
		self.fadeIn = math.min(self.fadeIn + dt * 0.001 / self.fadeDuration, 1)
		self.fadeOut = math.min(self.fadeOut + dt * 0.001 / self.fadeDuration, 1)

		if self.fadeOut == 1 then
			self.state = CombinedEffect.STATE_OFF
		end
	end

	local updateEffectWidth = false

	if self.state ~= CombinedEffect.STATE_TURNING_OFF and self.testAreaIndex ~= nil then
		local currentTestAreaMinX, currentTestAreaMaxX, testAreaMinX, testAreaMaxX = self.parent:getTestAreaWidthByWorkAreaIndex(self.testAreaIndex)

		if currentTestAreaMinX ~= -math.huge and currentTestAreaMaxX ~= math.huge then
			for i, effect in ipairs(self.effects) do
				if effect.setMinMaxWidth ~= nil and effect.testAreaSubIndex == nil then
					effect:setMinMaxWidth(currentTestAreaMinX, currentTestAreaMaxX, -(currentTestAreaMinX / testAreaMinX), -(currentTestAreaMaxX / testAreaMaxX), false)
				end
			end

			updateEffectWidth = true
		end
	end

	for i, effect in ipairs(self.effects) do
		if effect:isa(MotionPathEffect) then
			local startAlpha = effect.delay
			local endAlpha = effect.delay + 1 / effect.effectSpeedScaleOrig
			local fadeInPos = MathUtil.inverseLerp(startAlpha, endAlpha, self.fadeIn * self.fadeDuration)
			local fadeOutPos = MathUtil.inverseLerp(startAlpha, endAlpha, self.fadeOut * self.fadeDuration)
			effect.state = MotionPathEffect.STATE_ON
			effect.fadeIn = fadeInPos
			effect.fadeOut = fadeOutPos

			if updateEffectWidth and effect:isa(CutterMotionPathEffect) and effect.testAreaSubIndex ~= nil then
				local spec = self.parent.spec_testAreas
				local testAreas = spec.testAreasByWorkAreaIndex[self.testAreaIndex]

				if testAreas ~= nil then
					local minWidthNorm = 0
					local maxWidthNorm = 0

					if testAreas[effect.testAreaSubIndex] ~= nil and testAreas[effect.testAreaSubIndex].hasContact then
						maxWidthNorm = 1
						minWidthNorm = 1
					end

					minWidthNorm = minWidthNorm + 1
					maxWidthNorm = 2 - maxWidthNorm + 1
					minWidthNorm = effect.minValueDelay:add(minWidthNorm)
					maxWidthNorm = effect.maxValueDelay:add(maxWidthNorm)
					minWidthNorm = minWidthNorm - 1
					maxWidthNorm = 2 - maxWidthNorm + 1
					effect.effectMinValue = minWidthNorm * effect.widthScale - effect.offset
					effect.effectMaxValue = maxWidthNorm * effect.widthScale + effect.offset
				end
			end

			effect:update(dt)
		elseif effect:isa(MorphPositionEffect) then
			local startAlpha = effect.startDelay * 0.001
			local endAlpha = (effect.startDelay + effect.fadeInTime) * 0.001
			local fadeInPos = MathUtil.inverseLerp(startAlpha, endAlpha, self.fadeIn * self.fadeDuration)
			local fadeOutPos = MathUtil.inverseLerp(startAlpha, endAlpha, self.fadeOut * self.fadeDuration)
			effect.fadeCur[1] = fadeOutPos
			effect.fadeCur[2] = fadeInPos

			g_animationManager:setPrevShaderParameter(effect.node, "morphPosition", effect.fadeCur[1], effect.fadeCur[2], 1, effect.speed, false, "prevMorphPosition")

			if effect.scrollUpdate then
				effect.scrollPosition = (effect.scrollPosition + dt * effect.scrollSpeed) % effect.scrollLength
				local _, y, z, w = getShaderParameter(effect.node, "offsetUV")

				setShaderParameter(effect.node, "offsetUV", effect.scrollPosition, y, z, w, false)
			end

			setVisibility(effect.node, self.state ~= CombinedEffect.STATE_OFF)
		end
	end
end

function CombinedEffect:isRunning()
	return self.state ~= CombinedEffect.STATE_OFF
end

function CombinedEffect:start()
	if self.state ~= CombinedEffect.STATE_ON and self.state ~= CombinedEffect.STATE_TURNING_ON then
		self.state = CombinedEffect.STATE_TURNING_ON

		if self.fadeOut > 0.5 then
			self.fadeIn = 0
		end

		self.fadeOut = 0
	end

	return true
end

function CombinedEffect:stop()
	if self.state == CombinedEffect.STATE_ON or self.state == CombinedEffect.STATE_TURNING_ON then
		self.state = CombinedEffect.STATE_TURNING_OFF
	end

	return true
end

function CombinedEffect:reset()
	self.state = CombinedEffect.STATE_OFF
	self.fadeIn = 0
	self.fadeOut = 0
end

function CombinedEffect:setFillType(fillType, force)
	for _, effect in ipairs(self.effects) do
		if effect.setFillType ~= nil then
			effect:setFillType(fillType, force)
		end
	end

	self.fadeDuration = 0

	for i, effect in ipairs(self.effects) do
		if effect:isa(MotionPathEffect) then
			self.fadeDuration = math.max(effect.delay + 1 / effect.effectSpeedScaleOrig, self.fadeDuration)
		elseif effect:isa(MorphPositionEffect) then
			self.fadeDuration = math.max((effect.startDelay + effect.fadeInTime) * 0.001, self.fadeDuration)
		end
	end

	return true
end

function CombinedEffect:setDistance(distance)
	for _, effect in ipairs(self.effects) do
		if effect.setDistance ~= nil then
			effect:setDistance(distance)
		end
	end

	return true
end

function CombinedEffect:getIsVisible()
	return self.state ~= CombinedEffect.STATE_OFF
end

function CombinedEffect:getIsFullyVisible()
	return self.state ~= CombinedEffect.STATE_OFF and self.fadeIn == 1
end

function CombinedEffect:setDensity(density)
	for _, effect in ipairs(self.effects) do
		if effect.setDensity ~= nil then
			effect:setDensity(density)
		end
	end
end

function CombinedEffect.registerEffectXMLPaths(schema, basePath)
	schema:register(XMLValueType.INT, basePath .. "#testAreaIndex", "Index of work area which contains a test area to be used")
	schema:register(XMLValueType.STRING, basePath .. ".effectNode(?)#effectClass", "Effect class", "ShaderPlaneEffect")
	Effect.registerEffectXMLPaths(schema, basePath .. ".effectNode(?)")
	LevelerEffect.registerEffectXMLPaths(schema, basePath .. ".effectNode(?)")
	MorphPositionEffect.registerEffectXMLPaths(schema, basePath .. ".effectNode(?)")
	ParticleEffect.registerEffectXMLPaths(schema, basePath .. ".effectNode(?)")
	PipeEffect.registerEffectXMLPaths(schema, basePath .. ".effectNode(?)")
	ShaderPlaneEffect.registerEffectXMLPaths(schema, basePath .. ".effectNode(?)")
	SlurrySideToSideEffect.registerEffectXMLPaths(schema, basePath .. ".effectNode(?)")
	WindrowerEffect.registerEffectXMLPaths(schema, basePath .. ".effectNode(?)")
	GrainTankEffect.registerEffectXMLPaths(schema, basePath .. ".effectNode(?)")
	CutterMotionPathEffect.registerEffectXMLPaths(schema, basePath .. ".effectNode(?)")
	CultivatorMotionPathEffect.registerEffectXMLPaths(schema, basePath .. ".effectNode(?)")
	PlowMotionPathEffect.registerEffectXMLPaths(schema, basePath .. ".effectNode(?)")
	WindrowerMotionPathEffect.registerEffectXMLPaths(schema, basePath .. ".effectNode(?)")
	MotionPathEffect.registerEffectXMLPaths(schema, basePath .. ".effectNode(?)")
end

g_effectManager:registerEffectClass("CombinedEffect", CombinedEffect)
