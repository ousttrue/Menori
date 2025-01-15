require("lldebugger").start()

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
end

---@param dt number delta time seconds
function love.update(dt)
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

  if love.keyboard.isDown "escape" then
    love.event.quit()
  end
  love.mouse.setRelativeMode(love.mouse.isDown(2))
end

---@param x number
---@param y number
function love.wheelmoved(x, y)
  local current_scene = scenes[scene_iterator]
  if current_scene then
    current_scene:on_wheelmoved(x, y)
  end
end

-- https://love2d.org/wiki/love.keyreleased
---@param key string
---@param scancode integer
function love.keyreleased(key, scancode)
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

---@param key string
---@param scancode integer
function love.keypressed(key, scancode)
  local current_scene = scenes[scene_iterator]
  if current_scene then
    current_scene:on_keypressed(key, scancode)
  end
end

-- https://love2d.org/wiki/love.mousemoved
---@param x number
---@param y number
---@param dx number
---@param dy number
---@param istouch boolean
function love.mousemoved(x, y, dx, dy, istouch)
  local current_scene = scenes[scene_iterator]
  if current_scene then
    current_scene:on_mousemoved(x, y, dx, dy, istouch)
  end
end

-- https://love2d.org/wiki/love.mousepressed
---@param x number
---@param y number
---@param button number
---@param istouch boolean
function love.mousepressed(x, y, button, istouch)
  local current_scene = scenes[scene_iterator]
  if current_scene then
    current_scene:on_mousepressed(x, y, button, istouch)
  end
end
