if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
  require("lldebugger").start()
end

local imgui = require("cimgui") -- cimgui is the folder containing the Lua module (the "src" folder in the git repository)

---@type menori.Scene[]
local scenes = {}
local scene_iterator = 1
local function prev_scene()
  scene_iterator = scene_iterator - 1
  if scene_iterator < 1 then
    scene_iterator = #scenes
  end
end
local function next_scene()
  scene_iterator = scene_iterator + 1
  if scene_iterator > #scenes then
    scene_iterator = 1
  end
end

local accumulator = 0.0
local tick_period = 1.0 / 60.0

function love.load()
  imgui.love.Init() -- or imgui.love.Init("RGBA32") or imgui.love.Init("Alpha8")

  table.insert(scenes, require("examples.minimal.scene").new())
  table.insert(scenes, require("examples.basic_lighting.scene").new())
  table.insert(scenes, require("examples.SSAO.scene").new())
  table.insert(scenes, require("examples.raycast_bvh.scene").new())
end

function love.draw()
  local current_scene = scenes[scene_iterator]
  if current_scene and current_scene.render then
    current_scene:render()
  end

  local font = love.graphics.getFont()
  local w, h = love.graphics.getDimensions()

  love.graphics.setColor(1, 0.5, 0, 1)
  love.graphics.print(love.timer.getFPS(), 10, 10)
  love.graphics.setColor(1, 1, 1, 1)
  local prev_str = "Prev scene (press A)"
  local next_str = "Next scene (press D)"
  if current_scene then
    love.graphics.print("Example: " .. current_scene.title, 10, 25)
  end
  love.graphics.print(prev_str, 10, h - 30)
  love.graphics.print(next_str, w - font:getWidth(next_str) - 10, h - 30)

  -- example window
  imgui.ShowDemoWindow()

  -- code to render imgui
  imgui.Render()
  imgui.love.RenderDrawLists()
end

---@param dt number delta time seconds
function love.update(dt)
  imgui.love.Update(dt)
  imgui.NewFrame()

  -- update time
  accumulator = accumulator + dt
  local steps = math.floor(accumulator / tick_period)
  if steps > 0 then
    accumulator = accumulator - steps * tick_period
  end

  local current_scene = scenes[scene_iterator]
  if current_scene and current_scene.update then
    -- update scene
    while steps > 0 do
      current_scene:update(tick_period)
      steps = steps - 1
    end
  end

  if love.keyboard.isDown("escape") then
    love.event.quit()
  end
  love.mouse.setRelativeMode(love.mouse.isDown(2))
end

---@param x number
---@param y number
function love.wheelmoved(x, y)
  imgui.love.WheelMoved(x, y)
  if not imgui.love.GetWantCaptureMouse() then
    local current_scene = scenes[scene_iterator]
    if current_scene then
      current_scene:on_wheelmoved(x, y)
    end
  end
end

---@param key string
---@param scancode integer
function love.keypressed(key, scancode)
  imgui.love.KeyPressed(key)
  if not imgui.love.GetWantCaptureKeyboard() then
    local current_scene = scenes[scene_iterator]
    if current_scene then
      current_scene:on_keypressed(key, scancode)
    end
  end
end

-- https://love2d.org/wiki/love.keyreleased
---@param key string
---@param scancode integer
function love.keyreleased(key, scancode)
  imgui.love.KeyReleased(key)
  if not imgui.love.GetWantCaptureKeyboard() then
    local current_scene = scenes[scene_iterator]
    if current_scene then
      if key == "a" then
        prev_scene()
      elseif key == "d" then
        next_scene()
      end
      current_scene:on_keyreleased(key, scancode)
    end
  end
end

-- https://love2d.org/wiki/love.mousemoved
---@param x number
---@param y number
---@param dx number
---@param dy number
---@param istouch boolean
function love.mousemoved(x, y, dx, dy, istouch)
  imgui.love.MouseMoved(x, y)
  if not imgui.love.GetWantCaptureMouse() then
    local current_scene = scenes[scene_iterator]
    if current_scene then
      current_scene:on_mousemoved(x, y, dx, dy, istouch)
    end
  end
end

-- https://love2d.org/wiki/love.mousepressed
---@param x number
---@param y number
---@param button number
---@param istouch boolean
function love.mousepressed(x, y, button, istouch)
  imgui.love.MousePressed(button)
  if not imgui.love.GetWantCaptureMouse() then
    local current_scene = scenes[scene_iterator]
    if current_scene then
      current_scene:on_mousepressed(x, y, button, istouch)
    end
  end
end

function love.mousereleased(x, y, button, ...)
  imgui.love.MouseReleased(button)
  if not imgui.love.GetWantCaptureMouse() then
    -- your code here
  end
end

love.textinput = function(t)
  imgui.love.TextInput(t)
  if imgui.love.GetWantCaptureKeyboard() then
    -- your code here
  end
end

love.quit = function()
  return imgui.love.Shutdown()
end

-- for gamepad support also add the following:

love.joystickadded = function(joystick)
  imgui.love.JoystickAdded(joystick)
  -- your code here
end

love.joystickremoved = function(joystick)
  imgui.love.JoystickRemoved()
  -- your code here
end

love.gamepadpressed = function(joystick, button)
  imgui.love.GamepadPressed(button)
  -- your code here
end

love.gamepadreleased = function(joystick, button)
  imgui.love.GamepadReleased(button)
  -- your code here
end

-- choose threshold for considering analog controllers active, defaults to 0 if unspecified
local threshold = 0.2

love.gamepadaxis = function(joystick, axis, value)
  imgui.love.GamepadAxis(axis, value, threshold)
  -- your code here
end
