function calculateChunk (pos)
  local chunkX = math.floor(pos.x / 16)
  local chunkZ = math.floor(pos.z / 16)

  return chunkX, chunkZ
end

--returns the center of the current chunk
function calculateChunkCenter(pos, y)
  local chunkX, chunkZ = calculateChunk(pos)
  local center = vector.new(chunkX * 16 + 8, pos.y, chunkZ * 16 + 8)

  if y then
    center.y = y
  end

  return center
end

function calculateChunkCorners (pos)
  local chunkX, chunkZ = calculateChunk(pos)
  local chunkPosX = chunkX * 16
  local chunkPosZ = chunkZ * 16

  return {
    vector.new(chunkPosX, 0, chunkPosZ),
    vector.new(chunkPosX + 15, 0, chunkPosZ),
    vector.new(chunkPosX, 0 , chunkPosZ + 15),
    vector.new(chunkPosX + 15, 0, chunkPosZ + 15)
  }
end

--checks if pos2 is in the same chunk as pos 1
function isWithinSameChunk(pos1, pos2)
  local chunkCorners = calculateChunkCorners(pos1)
  for k,v in ipairs(chunkCorners) do
  end
  if pos2.x >= chunkCorners[1].x and pos2.x <= chunkCorners[2].x and pos2.z >= chunkCorners[1].z and pos2.z <= chunkCorners[3].z then
    return true
  end
end

ChunkClass = {}
ChunkClass.new = function ()
  local self = {}
  self.pos = nil
  self.map = {}
  return self
end
