--[[
-------------------------------------------------------------------------------
      Menori
      @author rozenmad
      2022
-------------------------------------------------------------------------------
]]

--[[--
Singleton object.
The main class for managing scenes and the viewport.
]]
--- @classmod App

---@class menori.App
---@field current_scene menori.Scene?
local App = {}
App.__index = App

local graphics_w, graphics_h = love.graphics.getDimensions()

local app = {
  ox = 0,
  oy = 0,
  sx = 1,
  sy = 1,
  scenes = {},
  accumulator = 0,
  tick_period = 1.0 / 60.0,
}

--- Get current scene.
-- @return Scene object
function App:get_current_scene()
  return self.current_scene
end

--- Get viewport width.
-- @treturn number
function App:get_viewport_w()
  return self.w or graphics_w
end

--- Get viewport height.
-- @treturn number
function App:get_viewport_h()
  return self.h or graphics_h
end

--- Add scene to the scene list.
-- @tparam string name
-- @tparam menori.Scene scene object
function App:add_scene(name, scene)
  self.scenes[name] = scene
end

--- Get scene from the scene list by the name.
-- @tparam string name
-- @treturn menori.Scene object
function App:set_scene(name)
  self.current_scene = self.scenes[name]
end

--- Main update function.
-- @tparam number dt
function App:update(dt)
  self.accumulator = self.accumulator + dt

  local target_dt = self.tick_period

  local steps = math.floor(self.accumulator / target_dt)

  if steps > 0 then
    self.accumulator = self.accumulator - steps * target_dt
  end

  local interpolation_dt = self.accumulator / target_dt
  local scene = self.current_scene

  if scene and scene.update then
    self.current_scene.interpolation_dt = interpolation_dt
    self.current_scene.dt = target_dt

    while steps > 0 do
      self.current_scene:update(target_dt)
      steps = steps - 1
    end
  end
end

--- Main render function.
function App:render()
  if self.current_scene and self.current_scene.render then
    self.current_scene:render()
  end
end

---@param x number
---@param y number
---@param dx number
---@param dy number
---@param istouch boolean
function App:mousemoved(x, y, dx, dy, istouch)
  local current_scene = self.current_scene
  if current_scene then
    -- local event = current_scene["mousemoved"]
    -- if current_scene and event then
    current_scene:on_mousemoved(x, y, dx, dy, istouch)
    -- end
  end
end

--- Handling any LOVE event. Redirects an event call to an overridden function in the active scene.
---@param eventname 'wheelmoved'|'keypressed'|'keyreleased'|'mousemoved'|'mousepressed'|'mousereleased'
function App:handle_event(eventname, ...)
  local current_scene = self.current_scene
  if current_scene then
    local event = current_scene[eventname]
    if current_scene and event then
      event(current_scene, ...)
    end
  end
end

return setmetatable(app, App)
