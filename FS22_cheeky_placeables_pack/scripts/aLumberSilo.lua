
ALumberSilo = {}

--source("LumberSiloInputEvent.lua")

LumberSiloInActivatable = {}

local LumberSiloInActivatable_mt = Class(LumberSiloInActivatable, Object)

function LumberSiloInActivatable.new(placable, isServer, customMt)
    local self = Object.new(isServer, isClient, customMt or LumberSiloInActivatable_mt)

    self.placable     = placable
    self.activateText = g_i18n:getText("InputLogs")

    return self
end

---Called when press activate to store.
function LumberSiloInActivatable:run()
    self.placable:processInputLogs(g_currentMission:getFarmId())
    self.placable:setVisuals()
end

LumberSiloActivatable = {}

local LumberSiloActivatable_mt = Class(LumberSiloActivatable, Object)

function LumberSiloActivatable.new(placable, isServer, customMt)
    local self = Object.new(isServer, isClient, customMt or LumberSiloActivatable_mt)

    self.placable     = placable
    self.activateText = g_i18n:getText("ExtractLogs")

    return self
end

---Called when press activate. In the test cases there were no parameters
function LumberSiloActivatable:run()
    local spec          = self.placable.spec_aLumberSilo
    local availableWood = 0
    local newLogVolume  = 1862
    local newLogMass    = 875
    local availableLogs = 0
    local maxOutputLogs = spec.maxPerSpawn

    if ( spec.isPine ) then
        newLogVolume = 973
        newLogMass   = 506
    end

    for _, storage in pairs (self.placable.spec_silo.storages) do
        for fillTypeIndex, fillLevel in pairs (storage.fillLevels) do
            if (fillLevel > 1) and fillTypeIndex == FillType.WOOD then
                availableWood = availableWood + fillLevel
            end
        end
    end

    availableLogs = Utils.getNoNil(math.floor(availableWood / newLogVolume), 0)

    local selectableOptions = {}
    local options           = {}

    if availableLogs < maxOutputLogs then
        -- Max output is defined via the placeable XML
        maxOutputLogs = availableLogs
    end

    if maxOutputLogs == 0 then
        g_currentMission:showBlinkingWarning(g_i18n:getText("NoLogsToOutput"), 2000)
        return
    end

    for v=1, maxOutputLogs do
        local textToDisplay = tostring(v) .. " "

        if ( v > 1 ) then
            textToDisplay = textToDisplay .. g_i18n:getText("MultiLog")
        else
            textToDisplay = textToDisplay .. g_i18n:getText("SingleLog")
        end
        textToDisplay = textToDisplay .. " (" .. tostring(newLogVolume * v) .. "l / " .. tostring(newLogMass * v) .. "kg)"

        table.insert(selectableOptions, v)
        table.insert(options, textToDisplay)
    end

    -- Choose number of logs to output / Anzahl der auszugebenden Protokolle wählen
    local dialogArguments = {
        text     = g_i18n:getText("ChooseOutputAmount"),
        title    = self.placable:getName(),
        options  = options,
        target   = self,
        args     = selectableOptions,
        callback = self.spawnLogs
    }

    --TODO: hack to reset the "remembered" option (i.e. solve a bug in the game engine)
    local dialog = g_gui.guis["OptionDialog"]
    if dialog ~= nil then
        dialog.target:setOptions({""}) -- Add fake option to force a "reset"
    end

    g_gui:showOptionDialog(dialogArguments)
end

function LumberSiloActivatable:spawnLogs(selectedOption, args)
    local spec           = self.placable.spec_aLumberSilo
    local selectedAmount = args[selectedOption]
    local newLogVolume   = 1862

    if selectedAmount == nil or selectedAmount == 0 then return end

    spec.queuedLogs = spec.queuedLogs + selectedAmount
    for _ = 1, selectedAmount do
        local delta = newLogVolume

        for _, storage in ipairs(self.placable.spec_silo.storages) do
            local available = storage.fillLevels[FillType.WOOD];
            if available ~= nil and available > 0 then
                local moved = math.min(delta, available)
                storage:setFillLevel(available - moved, FillType.WOOD)

                delta = delta - moved
            end

            if delta <= 0.001 then
                break
            end
        end
    end

    SpecializationUtil.raiseEvent(self.placable, "onUpdate", 0)

    -- TODO: display fill level of logs.
    self.placable:setVisuals()
end

function ALumberSilo:processInputLogs(farmId, noEventSend)
    if not self.isServer then
        g_client:getServerConnection():sendEvent(LumberSiloInputEvent.new(self, farmId))
        return
    end

    local spec          = self.spec_aLumberSilo
    local invalidFactor = spec.chipRatio
    local didChippy     = false
    local cantChippy    = false
    local outOfCapacity = false
    local storage       = self.spec_silo.storages[1]
    local storageChip   = self.spec_silo.storages[2]

    for _, nodeId in pairs(spec.woodInTrigger) do
        local didSomethingToLog = false
        if entityExists(nodeId) then
            local validLog = false

            local splitType = g_splitTypeManager:getSplitTypeByIndex(getSplitType(nodeId))

            if spec.isPine and ( splitType.splitTypeIndex == 2 or splitType.splitTypeIndex == 17 ) then
                validLog = true
            elseif (not spec.isPine) and splitType.splitTypeIndex == 1 then
                validLog = true
            end

            local volume, qualityScale = WoodUnloadTrigger:calculateWoodBaseValue(nodeId)

            if ( validLog ) then
                local unusedCapactiy = storage:getFreeCapacity(FillType.WOOD)

                if ( volume * 0.9 < unusedCapactiy ) then
                    -- we have at least 90% of the room we need, put it in
                    local currentLevel  = storage:getFillLevel(FillType.WOOD)
                    local totalCapacity = storage:getCapacity(FillType.WOOD)
                    local newLevel      = currentLevel + volume
                    if ( newLevel > totalCapacity ) then
                        -- too much, top it off
                        newLevel = totalCapacity
                    end
                    storage:setFillLevel(newLevel, FillType.WOOD)
                    didSomethingToLog = true
                else
                    outOfCapacity = true
                end
            else
                -- we chip invalid logs, at a steep reduction factor
                if ( spec.useWoodChips ) then
                    local adjustedVolume = volume * invalidFactor * splitType.woodChipsPerLiter
                    local unusedCapactiy = storageChip:getFreeCapacity(FillType.WOODCHIPS)

                    if ( adjustedVolume * 0.9 < unusedCapactiy ) then
                        -- we have at least 90% of the room we need, put it in
                        local currentLevel  = storageChip:getFillLevel(FillType.WOODCHIPS)
                        local totalCapacity = storageChip:getCapacity(FillType.WOODCHIPS)
                        local newLevel      = currentLevel + adjustedVolume
                        if ( newLevel > totalCapacity ) then
                            -- too much, top it off
                            newLevel = totalCapacity
                        end
                        storageChip:setFillLevel(newLevel, FillType.WOODCHIPS)

                        didSomethingToLog = true
                        didChippy = true
                    end
                else
                    cantChippy = true
                end
            end
            if didSomethingToLog then
                g_currentMission:removeKnownSplitShape(nodeId)
                delete(nodeId)
                g_treePlantManager:removingSplitShape(nodeId)
            end
        end
    end

    if cantChippy then
        g_currentMission:showBlinkingWarning(g_i18n:getText("BadInputNotChipped"), 1500)
    end
    if didChippy then
        g_currentMission:showBlinkingWarning(g_i18n:getText("BadInputChipped"), 1500)
    end
    if outOfCapacity then
        g_currentMission:showBlinkingWarning(g_i18n:getText("FullStorage"), 1500)
    end

    self:raiseActive()
end


function ALumberSilo:makeALog(treeType, length, growthState, x, y, z, dirX, dirY, dirZ)
    if treeType == nil or x == nil or y == nil or z == nil then
        return
    end

    local treeTypeDesc = g_treePlantManager:getTreeTypeDescFromIndex(treeType)

    if treeTypeDesc == nil or #treeTypeDesc.treeFilenames <= 1 then
        return
    end

    length      = 6
    growthState = math.min(math.max((growthState or 1), 0), 1)

    if self.isServer then
        local spec = self.spec_aLumberSilo
        local growthStateI = math.floor(growthState * (#treeTypeDesc.treeFilenames - 1)) + 1
        local treeId, splitShapeFileId = g_treePlantManager:loadTreeNode(treeTypeDesc, x, y, z, 0, 0, 0, growthStateI)

        if getFileIdHasSplitShapes(splitShapeFileId) then
            table.insert(g_treePlantManager.treesData.splitTrees, {
                x                = x,
                y                = y,
                z                = z,
                rx               = 0,
                ry               = 0,
                rz               = 0,
                node             = treeId,
                treeType         = treeType,
                growthState      = growthState,
                splitShapeFileId = splitShapeFileId,
                hasSplitShapes   = true
            })

            g_server:broadcastEvent(TreePlantEvent.new(treeType, x, y, z, 0, 0, 0, growthState, splitShapeFileId, false))


            spec.addingTreeToCut = true

            if spec.treesToCut == nil then
                spec.treesToCut = {}
            end

            table.insert(spec.treesToCut, {
                x          = x,
                y          = y,
                z          = z,
                dirX       = dirX,
                dirY       = dirY,
                dirZ       = dirZ,
                offset     = 0.5,
                framesLeft = 2,
                length     = length,
                dataAdded  = false,
                shape      = treeId + 2
            })

            spec.addingTreeToCut = false
            self:raiseActive()
        else
            delete(treeId)
        end
    else
        local params = {
            treeType    = treeType,
            length      = length,
            growthState = growthState,
            rx          = dirX,
            ry          = dirY,
            rz          = dirZ,
            x           = x,
            y           = y,
            z           = z
        }
        g_client:getServerConnection():sendEvent(SpawnLumberAtSiloEvent.new(self, 0, params))
    end
end

function ALumberSilo:onUpdate(dt)
    self:setVisuals()
    local spec           = self.spec_aLumberSilo

    if self.isServer and spec.treesToCut ~= nil then
        local numTrees = #spec.treesToCut

        if g_treePlantManager.loadTreeTrunkData == nil then
            for _, treeToCut in pairs (spec.treesToCut) do
                if treeToCut.dataAdded then
                    numTrees = numTrees - 1
                else
                    g_treePlantManager.loadTreeTrunkData = treeToCut
                    treeToCut.dataAdded = true
                end
            end
        end

        if numTrees <= 0 and not spec.addingTreeToCut then
            spec.treesToCut = nil
        end
    end

    --local spec           = self.spec_aLumberSilo
    local deltaXtable    = { 1.5, 0.5, -0.5, -1.5 }

    spec.loadDelayTime = spec.loadDelayTime or 0
    if spec.loadDelayTime > spec.delayDt then
        -- It's time to do something!
        spec.loadDelayTime = 0
        spec.queuedLogs    = spec.queuedLogs - 1

        if spec.logPlacement == 5 then
            spec.logPlacement = 1
        end

        local treeType = "SPRUCE1"

        if spec.isPine then treeType = "PINE" end

        local treeTypeDesc = g_treePlantManager:getTreeTypeDescFromName(treeType)

        if treeTypeDesc ~= nil then
            local growthState = #treeTypeDesc.treeFilenames
            local x           = 0
            local y           = 0
            local z           = 0
            local dirX        = 1
            local dirY        = 0
            local dirZ        = 0
            local deltaZ      = -3.5
            local deltaX      = deltaXtable[spec.logPlacement]

            if spec.isPine then
                growthState = 6 --maybe
            end

            x, y, z          = localToWorld(spec.spawnNode, deltaX, 0, deltaZ)
            dirX, dirY, dirZ = localDirectionToWorld(spec.spawnNode, 0, 0, 1)

            y = y + 2

            -- actually make the log (MP safe?  Definatally save safe)
            self:makeALog(treeTypeDesc.index, 6, growthState, x, y, z, dirX, dirY, dirZ)
            spec.logPlacement = spec.logPlacement + 1
        end
    else
        -- It is NOT time to do something, increment delay counter
        spec.loadDelayTime = spec.loadDelayTime + dt
    end

    if spec.queuedLogs > 0 then
        -- We should try and do something again soon!
        self:raiseActive()
    else
        -- reset the placement offset thing
        spec.logPlacement = 1
    end
end


function ALumberSilo.prerequisitesPresent(specializations)
    return true
end

function ALumberSilo.initSpecialization()
    local schema = Placeable.xmlSchema
    schema:setXMLSpecializationType("ALumberSilo")

    local baseXmlPath = "placeable.aLumberSilo"

    schema:register(XMLValueType.NODE_INDEX, baseXmlPath .. "#triggerNode", "Trigger node for access menu")
    schema:register(XMLValueType.NODE_INDEX, baseXmlPath .. "#inputTriggerNode", "Trigger node for input action")
    schema:register(XMLValueType.NODE_INDEX, baseXmlPath .. "#inputNode", "Input log node")
    schema:register(XMLValueType.NODE_INDEX, baseXmlPath .. "#spawnNode", "Spawn node for output logs")
    schema:register(XMLValueType.BOOL,       baseXmlPath .. "#isPine", "Pine/true, Spruce/false", false)
    schema:register(XMLValueType.BOOL,       baseXmlPath .. "#useWoodChips", "Allow chipping invalid logs", true)
    schema:register(XMLValueType.INT,        baseXmlPath .. "#maxPerSpawn", "Max logs to drop per spawn (default:18)", 18)
    schema:register(XMLValueType.FLOAT,      baseXmlPath .. "#woodchipRatio", "Percentage for woodchip conversion (default 1/2)", 0.5)
    schema:register(XMLValueType.FLOAT,      baseXmlPath .. ".logFill(?)#showPercent", "Fill percentage to show")
    schema:register(XMLValueType.NODE_INDEX, baseXmlPath .. ".logFill(?)#showNode", "Node to toggle")

    schema:setXMLSpecializationType()

    PlaceableSilo.INFO_TRIGGER_NUM_DISPLAYED_FILLTYPES = 25;
end

---
function ALumberSilo.registerFunctions(placeableType)
    SpecializationUtil.registerFunction(placeableType, "onTriggerNodeCallback", ALumberSilo.onTriggerNodeCallback)
    SpecializationUtil.registerFunction(placeableType, "onTriggerInNodeCallback", ALumberSilo.onTriggerInNodeCallback)
    SpecializationUtil.registerFunction(placeableType, "woodTriggerCallback", ALumberSilo.woodTriggerCallback)
    SpecializationUtil.registerFunction(placeableType, "setVisuals", ALumberSilo.setVisuals)
    SpecializationUtil.registerFunction(placeableType, "processInputLogs", ALumberSilo.processInputLogs)
    SpecializationUtil.registerFunction(placeableType, "makeALog", ALumberSilo.makeALog)
end

---
function ALumberSilo.registerOverwrittenFunctions(placeableType)
    SpecializationUtil.registerOverwrittenFunction(placeableType, "updateInfo", ALumberSilo.updateInfo)
end

---
function ALumberSilo.registerEventListeners(placeableType)
    SpecializationUtil.registerEventListener(placeableType, "onLoad", ALumberSilo)
    SpecializationUtil.registerEventListener(placeableType, "onDelete", ALumberSilo)
    SpecializationUtil.registerEventListener(placeableType, "onUpdate", ALumberSilo)
    SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", ALumberSilo)
    SpecializationUtil.registerEventListener(placeableType, "onRegisterActionEvents", ALumberSilo)
end

---
function ALumberSilo:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
end

---Called on loading
-- @param table savegame savegame
function ALumberSilo:onLoad(savegame)

    local baseXmlPath = "placeable.aLumberSilo"

    self.spec_aLumberSilo = {}

    local spec = self.spec_aLumberSilo

    spec.available     = false
    spec.loadDelayTime = 0
    spec.delayDt       = 400
    spec.queuedLogs    = 0
    spec.logPlacement  = 1
    spec.woodInTrigger = {}
    spec.fillVisuals   = {}
    spec.isPine        = self.xmlFile:getValue(baseXmlPath.."#isPine", true)
    spec.maxPerSpawn   = self.xmlFile:getValue(baseXmlPath.."#maxPerSpawn", 18)
    spec.chipRatio     = self.xmlFile:getValue(baseXmlPath.."#woodchipRatio", 0.5)
    spec.useWoodChips  = self.xmlFile:getValue(baseXmlPath.."#useWoodChips", true)
    spec.triggerNode   = self.xmlFile:getValue(baseXmlPath.."#triggerNode", nil, self.components, self.i3dMappings);
    spec.triggerInput  = self.xmlFile:getValue(baseXmlPath.."#inputTriggerNode", nil, self.components, self.i3dMappings);
    spec.spawnNode     = self.xmlFile:getValue(baseXmlPath.."#spawnNode", nil, self.components, self.i3dMappings);
    spec.inputNode     = self.xmlFile:getValue(baseXmlPath.."#inputNode", nil, self.components, self.i3dMappings);

    if spec.spawnNode == nil then
        Logging.xmlError(self.xmlFile, "Spawn node not found, silo will be unable to output anything")
    end

    if spec.inputNode ~= nil then
        local colMask = getCollisionMask(spec.inputNode)

        if bitAND(SplitTypeManager.COLLISIONMASK_TRIGGER, colMask) == 0 then
            Logging.xmlWarning(self.xmlFile, "Invalid collision mask for wood trigger. Bit 24 needs to be set!")

            return false
        end

        addTrigger(spec.inputNode, "woodTriggerCallback", self)
    else
        Logging.xmlError(self.xmlFile, "Input node not found, silo will be unable to input anything")
    end

    if spec.triggerNode ~= nil then
        if not CollisionFlag.getHasFlagSet(spec.triggerNode, CollisionFlag.TRIGGER_PLAYER) then
            Logging.xmlWarning(self.xmlFile, "Output trigger collison mask is missing bit 'TRIGGER_PLAYER' (%d)", CollisionFlag.getBit(CollisionFlag.TRIGGER_PLAYER))
        end
    end

    if spec.triggerInput ~= nil then
        if not CollisionFlag.getHasFlagSet(spec.triggerInput, CollisionFlag.TRIGGER_PLAYER) then
            Logging.xmlWarning(self.xmlFile, "Input trigger collison mask is missing bit 'TRIGGER_PLAYER' (%d)", CollisionFlag.getBit(CollisionFlag.TRIGGER_PLAYER))
        end
    end

    self.xmlFile:iterate(baseXmlPath..".logFill", function(index, logKey)
        local percentage = self.xmlFile:getValue(logKey .. "#showPercent")
        local nodeID     = self.xmlFile:getValue(logKey .. "#showNode", nil, self.components, self.i3dMappings)
        if nodeID == nil then
            Logging.xmlWarning(self.xmlFile, "Node note found '%s'", nodeID)
        else
            table.insert(spec.fillVisuals, {percentage, nodeID})
        end
    end)

    spec.inputactivatable = LumberSiloInActivatable.new(self, self.isServer)
    spec.activatable      = LumberSiloActivatable.new(self, self.isServer)
    spec.initialized      = true;

    self:setVisuals()
end


function ALumberSilo:onDelete()
    local spec = self.spec_aLumberSilo

    g_currentMission.activatableObjectsSystem:removeActivatable(spec.activatable)
    g_currentMission.activatableObjectsSystem:removeActivatable(spec.inputactivatable)

    if spec.triggerNode ~= nil then
        removeTrigger(spec.triggerNode)
        spec.triggerNode = nil
    end

    if spec.triggerInput ~= nil then
        removeTrigger(spec.triggerInput)
        spec.triggerInput = nil
    end

    if spec.inputNode ~= nil then
        removeTrigger(spec.inputNode)
        spec.inputNode = nil
    end
end

function ALumberSilo:onFinalizePlacement()
    local spec = self.spec_aLumberSilo
    if spec.triggerNode ~= nil then
        addTrigger(spec.triggerNode, "onTriggerNodeCallback", self)
    end
    if spec.triggerInput ~= nil then
        addTrigger(spec.triggerInput, "onTriggerInNodeCallback", self)
    end

end


function ALumberSilo:onTriggerNodeCallback(triggerId, otherId, onEnter, onLeave, onStay)
    local spec = self.spec_aLumberSilo

    if g_currentMission.player ~= nil and otherId == g_currentMission.player.rootNode then
        if onEnter then
            g_currentMission.activatableObjectsSystem:addActivatable(spec.activatable)
        else
            g_currentMission.activatableObjectsSystem:removeActivatable(spec.activatable)
        end
    end
end

function ALumberSilo:onTriggerInNodeCallback(triggerId, otherId, onEnter, onLeave, onStay)
    local spec = self.spec_aLumberSilo

    if g_currentMission.player ~= nil and otherId == g_currentMission.player.rootNode then

        if onEnter then
            g_currentMission.activatableObjectsSystem:addActivatable(spec.inputactivatable)
        else
            g_currentMission.activatableObjectsSystem:removeActivatable(spec.inputactivatable)
        end
    end
end

function ALumberSilo:woodTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
    local spec = self.spec_aLumberSilo

    if otherId ~= 0 then
        local splitType = g_splitTypeManager:getSplitTypeByIndex(getSplitType(otherId))

        if splitType ~= nil and splitType.pricePerLiter > 0 then
            if onEnter then
                spec.woodInTrigger[otherId] = otherId

            else
                spec.woodInTrigger[otherId] = nil
            end
        end
    end
end

function ALumberSilo:setVisuals()
    local spec          = self.spec_aLumberSilo
    local storage       = self.spec_silo.storages[1]
    local currentLevel  = storage:getFillLevel(FillType.WOOD)
    local totalCapacity = storage:getCapacity(FillType.WOOD)
    local percDecimal   = currentLevel / totalCapacity

    for _, thisVis in ipairs(spec.fillVisuals) do
        if ( percDecimal >= thisVis[1] ) then
            setCollisionMask(thisVis[2], 255)
            setVisibility(thisVis[2], true)
        else
            setVisibility(thisVis[2], false)
            setCollisionMask(thisVis[2], 0)
        end
    end
end

function ALumberSilo:updateInfo(superFunc, infoTable)
    local owningFarm  = g_farmManager:getFarmById(self:getOwnerFarmId())
    local spec        = self.spec_silo
    local storageWood = self.spec_silo.storages[1]
    local storageChip = self.spec_silo.storages[2]
    local isPine      = self.spec_aLumberSilo.isPine

    for fillType, fillLevel in pairs(self:getFillLevels()) do
        spec.fillTypesAndLevelsAuxiliary[fillType] = (spec.fillTypesAndLevelsAuxiliary[fillType] or 0) + fillLevel
    end

    table.clear(spec.infoTriggerFillTypesAndLevels)

    for fillType, fillLevel in pairs(spec.fillTypesAndLevelsAuxiliary) do
        if fillLevel > 0.1 then
            spec.fillTypeToFillTypeStorageTable[fillType] = spec.fillTypeToFillTypeStorageTable[fillType] or {
                fillType  = fillType,
                fillLevel = fillLevel
            }
            spec.fillTypeToFillTypeStorageTable[fillType].fillLevel = fillLevel

            table.insert(spec.infoTriggerFillTypesAndLevels, spec.fillTypeToFillTypeStorageTable[fillType])
        end
    end

    table.clear(spec.fillTypesAndLevelsAuxiliary)
    table.sort(spec.infoTriggerFillTypesAndLevels, function (a, b)
        return b.fillLevel < a.fillLevel
    end)

    local numEntries = math.min(#spec.infoTriggerFillTypesAndLevels, PlaceableSilo.INFO_TRIGGER_NUM_DISPLAYED_FILLTYPES)
    local woodFull   = false

    table.insert(infoTable, {
        title = g_i18n:getText("fieldInfo_ownedBy"),
        text  = owningFarm.name
    })

    if numEntries > 0 then
        for i = 1, numEntries do
            local fillTypeAndLevel   = spec.infoTriggerFillTypesAndLevels[i]
            local thisFillCapacity   = 0
            local thisFillPercentage = 0

            local thisTitle = g_fillTypeManager:getFillTypeTitleByIndex(fillTypeAndLevel.fillType)
            if ( fillTypeAndLevel.fillType == FillType.WOOD ) then
                thisFillCapacity   = storageWood:getCapacity(fillTypeAndLevel.fillType)
                thisFillPercentage = math.min(math.ceil((fillTypeAndLevel.fillLevel / thisFillCapacity) * 100), 100)
                if thisFillPercentage > 98 then
                    woodFull = true
                end
                if isPine then
                    thisTitle = thisTitle .. " - " .. g_i18n:getText("treeType_pine")
                else
                    thisTitle = thisTitle .. " - " .. g_i18n:getText("treeType_spruce")
                end
            else
                thisFillCapacity   = storageChip:getCapacity(fillTypeAndLevel.fillType)
                thisFillPercentage = math.max(0, math.min(math.ceil((fillTypeAndLevel.fillLevel / thisFillCapacity) * 100), 100))
            end

            table.insert(infoTable, {
                title = thisTitle,
                text  = g_i18n:formatVolume(fillTypeAndLevel.fillLevel, 0)
            })
            table.insert(infoTable, {
                title = thisTitle,
                text  = tostring(thisFillPercentage) .. " % " .. g_i18n:getText("InfoHudFull")
            })

        end
        if woodFull then
            table.insert(infoTable, {
                title      = "-",
                text       = g_i18n:getText("InfoHudIsFull"),
                accentuate = true
            })
        end
    else
        table.insert(infoTable, {
            title      = "-",
            text       = g_i18n:getText("infohud_siloEmpty"),
            accentuate = true
        })
    end
end
