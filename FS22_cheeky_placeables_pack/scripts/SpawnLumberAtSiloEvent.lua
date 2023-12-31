SpawnLumberAtSiloEvent = {}

SpawnLumberAtSiloEvent.SEND_NUM_BITS = 2

local SpawnLumberAtSiloEvent_mt = Class(SpawnLumberAtSiloEvent, Event)
InitEventClass(SpawnLumberAtSiloEvent, "SpawnLumberAtSiloEvent")

function SpawnLumberAtSiloEvent.emptyNew()
    local self = Event.new(SpawnLumberAtSiloEvent_mt)

    return self
end

function SpawnLumberAtSiloEvent.new(placable, typeId, params)
    local self = SpawnLumberAtSiloEvent.emptyNew()

    self.placable    = placable

    self.typeId      = typeId or 0

    self.treeType    = params.treeType

    self.length      = params.length
    self.growthState = params.growthState

    self.rx = params.rx
    self.ry = params.ry
    self.rz = params.rz

    self.x = params.x
    self.y = params.y
    self.z = params.z

    return self
end


function SpawnLumberAtSiloEvent:readStream(streamId, connection)
    self.placable    = NetworkUtil.readNodeObject(streamId)

    self.typeId      = streamReadUIntN(streamId, SpawnLumberAtSiloEvent.SEND_NUM_BITS)
    self.treeType    = streamReadInt32(streamId)
    self.length      = streamReadInt8(streamId)
    self.growthState = streamReadInt8(streamId)

    self.rx = streamReadFloat32(streamId)
    self.ry = streamReadFloat32(streamId)
    self.rz = streamReadFloat32(streamId)

    self.x = streamReadFloat32(streamId)
    self.y = streamReadFloat32(streamId)
    self.z = streamReadFloat32(streamId)

    self:run(connection)
end

function SpawnLumberAtSiloEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.placable)

    streamWriteUIntN(streamId, self.typeId, SpawnLumberAtSiloEvent.SEND_NUM_BITS)

    streamWriteInt32(streamId, self.treeType)

    streamWriteInt8(streamId, self.length)
    streamWriteInt8(streamId, self.growthState)

    streamWriteFloat32(streamId, self.rx)
    streamWriteFloat32(streamId, self.ry)
    streamWriteFloat32(streamId, self.rz)

    streamWriteFloat32(streamId, self.x)
    streamWriteFloat32(streamId, self.y)
    streamWriteFloat32(streamId, self.z)
end

function SpawnLumberAtSiloEvent:run(connection)
    if not connection:getIsServer() then
        local player = g_currentMission:getPlayerByConnection(connection)
        
        if player ~= nil then
            local farmId = player.farmId

            if farmId ~= nil and farmId ~= FarmManager.SPECTATOR_FARM_ID then
                local message

                message = self.placable:makeALog(self.treeType, self.length, self.growthState, self.x, self.y, self.z, self.rx, self.ry, self.rz)

                if g_dedicatedServer ~= nil and message ~= nil then
                    Logging.info(message)
                end
            else
                Logging.info("Failed to spawn object, invalid or no farm!")
            end

        end
    else
        print("  Error: SpawnLumberAtSiloEvent is a client to server only event!")
    end
end
