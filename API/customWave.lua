local wave = { }
wave.version = "0.1.5.1"

wave._oldSoundMap = {"harp", "bassattack", "bd", "snare", "hat"}
wave._newSoundMap = {
    "harp", --0
    "bass", -- 1
    "basedrum", -- 2
    "snare", -- 3
    "hat", -- 4
    "guitar", -- 5
    "flute", -- 6
    "bell", -- 7
    "chime", --8
    "xylophone", -- 9
    "iron_xylophone", -- 10
    "cow_bell", -- 11
    "didgeridoo", --12
    "bit", -- 13
    "banjo", --14
    "pling" --15

}
wave._defaultThrottle = 99
wave._defaultClipMode = 1
wave._maxInterval = 1
wave._isNewSystem = false
if _HOST then
	wave._isNewSystem = _HOST:sub(15, #_HOST) >= "1.80"
end

wave.context = { }
wave.output = { }
wave.track = { }
wave.instance = { }

function wave.createContext(clock, volume)
	clock = clock or os.clock()
	volume = volume or 1.0

	local context = setmetatable({ }, {__index = wave.context})
	context.outputs = { }
	context.instances = { }
	context.vs = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
	context.prevClock = clock
	context.volume = volume
	return context
end

function wave.context:addInstance(...)
	local instance = wave.createInstance(...)
	self.instances[#self.instances + 1] = instance
	return instance
end

function wave.context:removeInstance(instance)
	if type(instance) == "number" then
		table.remove(self.instances, instance)
	else
		for i = 1, #self.instances do
			if self.instances == instance then
				table.remove(self.instances, i)
				return
			end
		end
	end
end
function wave.context:playNote(note, pitch, volume)
	volume = volume or 1.0

	self.vs[note] = self.vs[note] + volume
	for i = 1, #self.outputs do
		self.outputs[i]:playNote(note, pitch, volume * self.volume)
	end
end

function wave.context:update(interval)
	local clock = os.clock()
	interval = interval or (clock - self.prevClock)

	self.prevClock = clock
	if interval > wave._maxInterval then
		interval = wave._maxInterval
	end
	for i = 1, #self.outputs do
		self.outputs[i].notes = 0
	end
	for i = 1, 16 do
		self.vs[i] = 0
	end
	if interval > 0 then
		for i = 1, #self.instances do
			local notes = self.instances[i]:update(interval)
			for j = 1, #notes / 3 do
				self:playNote(notes[j * 3 - 2], notes[j * 3 - 1], notes[j * 3])
			end
		end
	end
end

function wave.context:playNote(note, pitch, volume)
	volume = volume or 1.0

	self.vs[note] = self.vs[note] + volume
	for i = 1, #self.outputs do
		if self.outputs[i]:playNote(note, pitch, volume * self.volume) then break; end
	end
end

function wave.output:playNote(note, pitch, volume)
	volume = volume or 1.0

	if self.clipMode == 1 then
		if pitch < 0 then
			pitch = 0
		elseif pitch > 24 then
			pitch = 24
		end
	elseif self.clipMode == 2 then
		if pitch < 0 then
			while pitch < 0 do
				pitch = pitch + 12
			end
		elseif pitch > 24 then
			while pitch > 24 do
				pitch = pitch - 12
			end
		end
	end
	if self.filter[note] and self.notes < self.throttle then
		self.nativePlayNote(note, pitch, volume * self.volume)
		self.notes = self.notes + 1
	end
end

function wave.loadTrack(path)
	local track = setmetatable({ }, {__index = wave.track})
	local handle = fs.open(path, "rb")
	if not handle then return end

	local function readInt(size)
		local num = 0
		for i = 0, size - 1 do
			local byte = handle.read()
			if not byte then -- dont leave open file handles no matter what
				handle.close()
				return
			end
			num = num + byte * (256 ^ i)
		end
		return num
	end
	local function readStr()
		local length = readInt(4)
		if not length then return end
		local data = { }
		for i = 1, length do
			data[i] = string.char(handle.read())
		end
		return table.concat(data)
	end

	-- Part #1: Metadata
  track.oldFormat = readInt(2)
	track.NBSVersion = readInt(1)
	track.vanillaInstrumentCount = readInt(1)
	track.length = readInt(2) -- song length (ticks)
	track.height = readInt(2) -- song height
	track.name = readStr() -- song name
	track.author = readStr() -- song author
	track.originalAuthor = readStr() -- original song author
	track.description = readStr() -- song description
	track.tempo = readInt(2) / 100 -- tempo (ticks per second)
	track.autoSaving = readInt(1) == 0 and true or false -- auto-saving
	track.autoSavingDuration = readInt(1) -- auto-saving duration
	track.timeSignature = readInt(1) -- time signature (3 = 3/4)
	track.minutesSpent = readInt(4) -- minutes spent
	track.leftClicks = readInt(4) -- left clicks
	track.rightClicks = readInt(4) -- right clicks
	track.blocksAdded = readInt(4) -- blocks added
	track.blocksRemoved = readInt(4) -- blocks removed
	track.schematicFileName = readStr() -- midi/schematic file name
  track.loop = readInt(1)
  track.maxLoops = readInt(1)
  track.loopStartTick = readInt(2)

	-- Part #2: Notes
	track.layers = { }
	for i = 1, track.height do
		track.layers[i] = {name = "Layer "..i, volume = 1.0}
		track.layers[i].notes = { }
	end

	local tick = 0
	while true do
		local tickJumps = readInt(2)
		if tickJumps == 0 then break end
		tick = tick + tickJumps
		local layer = 0
		while true do
			local layerJumps = readInt(2)
			if layerJumps == 0 then break end
			layer = layer + layerJumps
			if layer > track.height then -- nbs can be buggy
				for i = track.height + 1, layer do
					track.layers[i] = {name = "Layer "..i, volume = 1.0}
					track.layers[i].notes = { }
				end
				track.height = layer
			end
			local instrument = readInt(1)
			local key = readInt(1)
      local velocity = readInt(1)
      local panning = readInt(1)
      local pitch = readInt(2)
			if instrument < track.vanillaInstrumentCount then -- nbs can be buggy
				track.layers[layer].notes[tick * 2 - 1] = instrument + 1
				track.layers[layer].notes[tick * 2] = key - 33
			end
		end
	end

	-- Part #3: Layers
	for i = 1, track.height do
		local name = readStr()
		if not name then break end -- if layer data doesnt exist, abort
		track.layers[i].name = name
    track.layers[i].locked = readInt(1)
		track.layers[i].volume = readInt(1) / 100
    track.layers[i].stereo = readInt(1)
	end

	handle.close()
	return track
end



function wave.createInstance(track, volume, playing, loop)
	volume = volume or 1.0
	playing = (playing == nil) or playing
	loop = (loop ~=  nil) and loop

	if getmetatable(track).__index == wave.instance then
		return track
	end
	local instance = setmetatable({ }, {__index = wave.instance})
	instance.track = track
	instance.volume = volume or 1.0
	instance.playing = playing
	instance.loop = loop
	instance.tick = 1
	return instance
end

function wave.instance:update(interval)
	local notes = { }
	if self.playing then
		local dticks = interval * self.track.tempo
		local starttick = self.tick
		local endtick = starttick + dticks
		local istarttick = math.ceil(starttick)
		local iendtick = math.ceil(endtick) - 1
		for i = istarttick, iendtick do
			for j = 1, self.track.height do
				if self.track.layers[j].notes[i * 2 - 1] then
					notes[#notes + 1] = self.track.layers[j].notes[i * 2 - 1]
					notes[#notes + 1] = self.track.layers[j].notes[i * 2]
					notes[#notes + 1] = self.track.layers[j].volume
				end
			end
		end
		self.tick = self.tick + dticks

		if endtick > self.track.length then
			self.tick = 1
      if self.loop then
        self.tick = self.track.loopStartTick
      end
			self.playing = self.loop
		end
	end
	return notes
end

return wave
