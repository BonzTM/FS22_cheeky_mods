LumberSiloInputEvent = {}
local LumberSiloInputEvent_mt = Class(LumberSiloInputEvent, Event)

InitEventClass(LumberSiloInputEvent, "LumberSiloInputEvent", EventIds.EVENT_SELL_WOOD)

function LumberSiloInputEvent.emptyNew()
	local self = Event.new(LumberSiloInputEvent_mt)

	return self
end

function LumberSiloInputEvent.new(aLumberSiloTrigger, farmId)
	local self = LumberSiloInputEvent.emptyNew()

	assert(g_server == nil, "Client->Server event")

	self.aLumberSiloTrigger = aLumberSiloTrigger
	self.farmId = farmId

	return self
end

function LumberSiloInputEvent:readStream(streamId, connection)
	self.aLumberSiloTrigger = NetworkUtil.readNodeObject(streamId)
	self.farmId = streamReadUIntN(streamId, FarmManager.FARM_ID_SEND_NUM_BITS)

	self:run(connection)
end

function LumberSiloInputEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.aLumberSiloTrigger)
	streamWriteUIntN(streamId, self.farmId, FarmManager.FARM_ID_SEND_NUM_BITS)
end

function LumberSiloInputEvent:run(connection)
	if not connection:getIsServer() then
		self.aLumberSiloTrigger:processInputLogs(self.farmId)
	end
end
