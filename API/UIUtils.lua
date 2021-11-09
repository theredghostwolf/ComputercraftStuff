--handles screen positions

local id = 0

PositionClass = {}
PositionClass.new = function ()
  local self = {}

  self.x = 0
  self.y = 0

  return self
end

--base screen object

BaseScreenObjectClass = {}
BaseScreenObjectClass.new = function ()
  local self = {}

  self.pos = PositionClass.new()
  self.width = 0
  self.height = 0
  self.id = id
  id = id + 1

  self.visible = true

  self.textColor = colors.black
  self.primaryColor = colors.green
  self.secondaryColor = colors.red

  self.data = nil
  self.text = ""
  self.tags = {}

  self.type = "base"

  function self.draw()
    --override based on class
  end

  function self.setPos (x, y)
    self.pos.x = x
    self.pos.y = y
  end

  function self.update ()
    if self.dataSource then
      self.data = self.dataSource()
    end
  end

  function self.centerCursor ()
    term.setCursorPos(self.pos.x + math.floor(self.width / 2) - math.floor(string.len(self.text) / 2), self.pos.y + math.floor(self.height / 2))
  end

  function self.setTag(tag)
    self.tags[tag] = true
  end

  function self.hasTag(tag)
    return self.tags[tag]
  end

  function self.removeTag(tag)
    table.remove(self.tags, tag)
  end

  return self
end

--progress bar
ProgressBarClass = {}
ProgressBarClass.new = function ()
  local self = BaseScreenObjectClass.new()

  self.horizontal = true -- if false will assume vetrical
  self.data = 0
  self.dataSource = nil

  self.type = "bar"

  function self.draw ()
    paintutils.drawFilledBox(self.pos.x, self.pos.y, self.pos.x + self.width, self.pos.y + self.height, self.secondaryColor)
    if self.data > 0 then
      if self.horizontal then
        paintutils.drawFilledBox(self.pos.x, self.pos.y, self.pos.x + self.width * self.data, self.pos.y + self.height, self.primaryColor)
      else
        paintutils.drawFilledBox(self.pos.x, self.pos.y + (self.height * (1 - self.data)), self.pos.x + self.width, self.pos.y + self.height, self.primaryColor)
      end
    end
    local str = (math.floor(self.data * 100)) .. "%"
    term.setCursorPos(self.pos.x + ((self.width / 2) - (#str / 2)) + 1, self.pos.y + self.height / 2)
    term.setTextColor(self.textColor)

    local cursorX, cursorY = term.getCursorPos()
    if self.horizontal then
      for i = 1, #str do
        if cursorX > self.pos.x + self.width * self.data then
          term.setBackgroundColor(self.secondaryColor)
        else
          term.setBackgroundColor(self.primaryColor)
        end
        term.write(string.sub(str,i,i))
        cursorX = cursorX + 1
      end

    else
      --print(cursorY, math.floor(self.pos.y + (self.height * (1 - self.data)) + 0.5), self.pos.y + (self.height * (1 - self.data)))
      if cursorY <  math.floor(self.pos.y + (self.height * (1 - self.data))) then
        term.setBackgroundColor(self.secondaryColor)
      end
      term.write(str)
    end
  end

  return self
end

--button class
ButtonClass = {}
ButtonClass.new = function ()
  local self = BaseScreenObjectClass.new()

  self.onClick = nil
  self.active = false
  self.page = 0

  self.subText = ""

  self.isRadio = false
  self.radioTag = nil

  self.type = "button"

  --toggles the button active status
  function self.toggle ()
    self.active = not self.active
  end

  function self.draw(page)
    if not page or page == self.page or self.page == 0 then
      color = self.secondaryColor
      if self.active then
        color = self.primaryColor
      end
      paintutils.drawFilledBox(self.pos.x, self.pos.y, self.pos.x + self.width, self.pos.y + self.height, color)
      self.centerCursor()
      term.setTextColor(self.textColor)
      if #tostring(self.text) <= 2 and self.width <= 2 then
        term.setCursorPos(self.pos.x, self.pos.y + self.height / 2)
        term.write(self.text)
      elseif (#tostring(self.text) > self.width - 2) then
        term.setCursorPos(self.pos.x + 1, self.pos.y +  (self.height / 2))
        term.write(string.sub(self.text,1,self.width  - 1))
      else
        term.write(self.text)
      end

      term.setCursorPos(self.pos.x + (self.width / 2 - #self.subText / 2)  + 1, self.pos.y + (self.height / 2) + 1)
      term.write(self.subText)

    end
  end

  return self
end

--default button handler
local function buttonHandler (UI, event, side,  x, y, page)
  for k,v in pairs (UI.objects) do
    if v.type == "button" and x >= v.pos.x and x <= v.pos.x + v.width and y >= v.pos.y and y <= v.pos.y + v.height and v.visible then
      if not page or v.page == page or v.page == 0 then
        if v.isRadio then
          v.active = not v.active
          for k1,v1 in pairs(UI.objects) do
            if v1 ~= v and v1.isRadio and v1.radioTag == v.radioTag then
              v1.active = false
            end
          end
        end
        if v.onClick then
          v.onClick(v.data)
        end
      end
    end
  end
end

--UI class
UIClass = {}
UIClass.new = function ()
  local self =  {}
  self.name = ""
  self.objects = {}
  self.page = 1
  self.pages = 1

  function self.update ()
    for k,v in pairs (self.objects) do
      v.update()
    end
  end

  function self.draw ()
    for k,v in pairs(self.objects) do
      if v.visible then
        v.draw(self.page)
      end
    end
  end

  function self.addObject (o)
    table.insert(self.objects, o)
  end

  function self.addObjects(o)
    for k,v in pairs(o) do
      table.insert(self.objects, v)
    end
  end

  function self.findObjectsWithTag(tag)
    local objects = {}
    for k,v in pairs (self.objects) do
      if v.hasTag(tag) then
        table.insert(objects, v)
      end
    end
    return objects
  end

  self.handler = buttonHandler

  return self
end

--text class
TextClass = {}
TextClass.new = function ()
  local self = BaseScreenObjectClass.new()
  self.type = "text"
  function self.draw()
    term.setTextColor(self.textColor)
    term.setBackgroundColor(self.primaryColor)
    term.setCursorPos(self.pos.x, self.pos.y)
    term.write(self.text)
  end

  function self.update ()
    if self.dataSource then
      self.text = self.dataSource()
    end
  end

  return self
end

--navBar
NavbarClass = {}
NavbarClass.new = function ()
  local self = BaseScreenObjectClass.new()
  self.options = {}
  self.divider = ">>"
  self.type = "navbar"
  function self.draw ()
    local t = self.divider .. " "
    for k,v in pairs(self.options) do
      t = t .. v .. " " .. self.divider .. " "
    end
    if #t > #self.divider + 1 then
      t = string.sub(t, 1, (#self.divider + 2) * -1)
    end
    paintutils.drawFilledBox(self.pos.x, self.pos.y, self.pos.x + self.width, self.pos.y + self.height, self.primaryColor)
    term.setBackgroundColor(self.primaryColor)
    term.setTextColor(self.textColor)
    if self.pos.x > 1 then
      term.setCursorPos(self.pos.x, self.pos.y)
    else
      term.setCursorPos(2, self.pos.y)
    end
    local m = term.current()

    term.write(t)

  end

  return self
end

--messages used in the log
MessageClass = {}
MessageClass.new = function ()
  local self = {}

  self.infoColor = colors.blue
  self.errorColor = colors.red
  self.successColor = colors.green
  self.warningColor = colors.orange

  self.text = ""
  self.type = 1 -- 1 = info, 2 = error 3 = success 4- warning

  function self.getColor ()
    if self.type == 1 then
      return self.infoColor
    elseif self.type == 2 then
      return self.errorColor
    elseif self.type == 3 then
      return self.successColor
    elseif self.type == 4 then
      return self.warningColor
    else
      return colors.white -- default
    end
  end

  return self
end

LogClass = {}
LogClass.new = function ()
  local self = BaseScreenObjectClass.new()

  self.messages = {}
  self.recentMessages = {}
  self.type = "log"

  function self.addToRecentMessage (m)
    local t = m.text

    if #t > self.width then
      while #t > 0 do
        local message = MessageClass.new()
        message.type = m.type
        message.text = string.sub(t,1,self.width)
        table.insert(self.recentMessages, message)
        t = string.sub(t,self.width + 1, #t)
      end
    else
      table.insert(self.recentMessages, m)
    end
    while #self.recentMessages > self.height do
      table.remove(self.recentMessages, 1)
    end
  end

  function self.addMessage (m, t)
    if type(m) == "table" then
      table.insert(self.messages, m)
      self.addToRecentMessage(m)
    else
      local message = MessageClass.new()
      message.text = tostring(m)
      message.type = t
      self.addToRecentMessage(message)
      table.insert(self.messages, message)
    end
  end

  function self.clear()
    self.messages = {}
    self.recentMessages = {}
  end

  function self.draw()
    paintutils.drawFilledBox(self.pos.x, self.pos.y, self.pos.x + self.width, self.pos.y + self.height, self.primaryColor)
    term.setCursorPos(self.pos.x, self.pos.y)
    term.setBackgroundColor(self.primaryColor)
    term.setTextColor(self.textColor)
    term.write("Log: ")

    if #self.recentMessages > 0 then
      for i = 1, #self.recentMessages do
        term.setCursorPos(self.pos.x + 1, self.pos.y + i)
        term.setTextColor(self.recentMessages[i].getColor())
        term.write(string.sub(self.recentMessages[i].text,1,self.width))
      end
    end
  end

  return self
end

AnimationClass = {}
AnimationClass.new = function ()
  local self = BaseScreenObjectClass.new()

  self.frames = {}
  self.currentFrame = 1
  self.speed = 10
  self.timer = 0
  self.paused = false
  self.pauseOnLastFrame = false

  self.pause = function ()
    self.paused = true
  end

  self.unpause = function ()
    self.paused = false
  end

  self.draw = function ()
    paintutils.drawImage(self.frames[self.currentFrame].img, self.pos.x, self.pos.y)
    if not self.paused then
    self.timer = self.timer + 1
      if self.timer >= self.speed then
        self.timer = 0
        self.currentFrame = self.currentFrame + 1
        if self.pauseOnLastFrame and self.currentFrame == #self.frames then
          self.pause()
          self.pauseOnLastFrame = false
        end

        if self.currentFrame > #self.frames then
          self.currentFrame = 1
        end
      end
    end
  end

  self.changeColor = function (oldColor, newColor)
    for k,v in pairs (self.frames) do
      v.changeColor(oldColor, newColor)
    end
  end

  self.setToOriginal = function ()
    for k,v in pairs (self.frames) do
      v.setToOriginal()
    end
  end

  self.reset = function ()
    self.currentFrame = 1
    self.timer = 0
  end

  return self
end

ImageClass = {}
ImageClass.new = function (source)
  local self = BaseScreenObjectClass.new()

  self.source = source
  self.original = nil
  self.img = nil

  self.setToOriginal = function ()
    self.img = self.original
  end

  self.changeColor = function (oldColor, newColor)
    local out = {}
    for k,v in pairs (self.img) do
      local temp = {}
      for k2, v2 in pairs(v) do
        if v2 == oldColor then
          v2 = newColor
        end
        table.insert(temp, v2)
      end
      table.insert(out, temp)
    end
    self.img = out
  end

  self.reload = function ()
    if self.source then
      self.img = paintutils.loadImage(source)
      self.original = self.img
      return true
    else
      return false
    end
  end

  self.draw = function ()
    paintutils.drawImage(self.img, self.pos.x, self.pos.y)
  end

  self.reload()

  return self
end

QueueClass = {}
QueueClass.new = function ()
  local self = BaseScreenObjectClass.new()

  self.draw = function ()
    local entryCount = 0
    local y = 0
    for k,v in pairs(self.data) do
      if (entryCount % 2) == 0 then
        term.setBackgroundColor(self.primaryColor)
      else
        term.setBackgroundColor(self.secondaryColor)
      end

      local text = v.queueLabel
      local messages = {}
      if #text > self.width then
        while #text > 0 do
          table.insert(messages, string.sub(text,1,self.width))
          text = string.sub(text, self.width + 1, #text)
        end
      else
        messages[1] = text
      end

      term.setTextColor(self.textColor)

      for k2, v2 in pairs(messages) do
        term.setCursorPos(self.pos.x, self.pos.y + y)
        if #v2 < self.width then
          local filler = ""
          for i = 1, (self.width - #v2) do
            filler = filler .. " "
          end
          v2 = v2 .. filler
        end
        term.write(v2)
        y = y + 1
        if y > self.height then
          break
        end
      end
      if y > self.height then
        break
      end
      entryCount = entryCount + 1
    end
  end

  return self
end


function generateButtons (monitor, amount , startX, startY, endX, endY, collums, rows, primaryColor, secondaryColor, textColor, onclick)
  --local monw, monh = monitor.getSize()
  local bWidth = math.floor(((endX - startX) - collums) / collums)
  local bHeight = math.floor(((endY - startY) - rows) / rows)
  local buttons = {}

  local curX, curY = startX, startY
  local made = 0

  for i = 1, math.ceil(amount / (collums * rows)) do
    for row = 1, rows do
      for col = 1, collums do
        if made < amount then
          local b = ButtonClass.new()
          b.pos.x = curX
          b.pos.y = curY
          b.width = bWidth
          b.height = bHeight
          b.page = i
          b.text = "button"

          b.primaryColor = primaryColor
          b.secondaryColor = secondaryColor
          b.textColor = textColor
          b.onClick = onclick

          curX = curX + bWidth + 2
          table.insert(buttons, b)
          made = made + 1
        end
      end
      curY = curY + bHeight + 2
      curX = startX
    end
    curX, curY = startX, startY
  end

  return buttons
end
