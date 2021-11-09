function tableContains (table, val)
  for k,v in pairs(table) do
    if v == val then
      return true
    end
  end
  return false
end

function getTableSize (t)
  local s = 0
  for k,v in pairs(t) do
    s = s + 1
  end
  return s
end

function sameValues (table, start, stop, value)
  for i = start, stop do
    if table[i] ~= value then
      return false
    end
  end
  return true
end

Queue = {}
Queue.new = function ()
	local self = {}

	self.first = 0
	self.last = -1
  self.list = {}

	self.pushLeft = function (val)
		self.first = self.first - 1
		self.list[self.first] = val
	end

	self.pushRight = function (val)
		self.last = self.last + 1
		self.list[self.last] = val
	end

	self.popLeft = function ()
		if self.first > self.last then
			--list is empty
			return nil
		else
			local val = self.list[self.first]
			self.list[self.first] = nil
			self.first = self.first + 1
			return val
		end
	end

	self.popRight = function ()
		if self.first > self.last then
			--list is empty
			return nil
		else
			local val = self.list[self.last]
			self.list[self.last] = nil
			self.last = self.last - 1
			return val
		end
	end

  self.getQueue = function ()
    return self.list
  end

	return self
end
