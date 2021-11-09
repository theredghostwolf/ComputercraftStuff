function tableToString (table)
    local str = "{ \n"
    for k,v in pairs (table) do
      local addStr = tostring(v)
      if type(v) == "table" then
        addStr = tableToString(v) .. ""
      elseif type(v) == "string" then
        addStr = '"' .. v .. '"'
      end
      str = str .. " " ..  k .. " = " .. addStr .. ", \n"
      end
  return string.sub(str,1,#str - 3) .. "\n }"
end

function stringToTable (str)
  return loadstring("return " .. str)()
end

function splitString (inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={}
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                table.insert(t, str)
        end
        return t
end

ConfigClass = {}
ConfigClass.new = function (file)
  self = {}

  self.tag = {}
  self.file = file

  self.fileExists  = function ()
   return fs.exists (self.file)
  end

  self.generateFile = function ()
    if not self.fileExists() then
      local f = fs.open(self.file, "w")
      f.close()
      return true
    end
    return false
  end

  self.load = function ()
    if self.fileExists() then
      local f = fs.open(self.file, "r")
      self.tag = textutils.unserialize(f.readAll())
      f.close()
      return true
    else
      return false
    end
  end

  self.save = function ()
    if not self.fileExists() then
      if not self.generateFile() then
        return false
      end
    end

    local f = fs.open(self.file, "w")
    f.write(textutils.serialize(self.tag))
    f.close()
    return true
  end

  self.add = function (key, data, save)
    if not self.tag then
      self.tag = {}
    end
    self.tag[key] = data
    if save then
      self.save()
    end
  end

  self.get = function (key)
    return self.tag[key]
  end

  self.remove = function (key)
    table.remove(self.tag, key)
  end

  return self
end
