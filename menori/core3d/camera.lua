--[[
-------------------------------------------------------------------------------
	Menori
	@author rozenmad
	2023
-------------------------------------------------------------------------------
]]

--[[--
Perspective camera class.
]]
-- @classmod PerspectiveCamera

local ml = require("menori.ml")

local mat4 = ml.mat4
local vec2 = ml.vec2
local vec3 = ml.vec3
local vec4 = ml.vec4

---@class menori.PerspectiveCamera
---@field m_projection menori.mat4 Projection matrix.
---@field m_inv_projection menori.mat4  Inverse projection matrix.
---@field m_view menori.mat4  View matrix.
---@field center menori.vec3  Position where the camera is looking at.
---@field eye menori.vec3  Position of the camera.
---@field up menori.vec3  Normalized up vector, how the camera is oriented.
local PerspectiveCamera = {}
PerspectiveCamera.__index = PerspectiveCamera

---@param fov number Field of view of the Camera, in degrees.
---@param aspect number The aspect ratio.
---@param nclip number The distance of the near clipping plane from the the Camera.
---@param fclip number The distance of the far clipping plane from the Camera.
---@return menori.PerspectiveCamera
function PerspectiveCamera.new(fov, aspect, nclip, fclip)
    fov = fov or 60
    aspect = aspect or 1.6666667
    nclip = nclip or 0.1
    fclip = fclip or 2048.0

    local self = setmetatable({}, PerspectiveCamera)

    self.m_projection = mat4():perspective_RH_NO(fov, aspect, nclip, fclip)
    self.m_inv_projection = self.m_projection:clone():inverse()
    self.m_view = mat4()

    self.eye = vec3(0, 0, 0)
    self.center = vec3(0, 0, 1)
    self.up = vec3(0, 1, 0)

    return self
end

----
-- Updating the view matrix.
function PerspectiveCamera:update_view_matrix()
    self.m_view:identity()
    self.m_view:look_at_RH(self.eye, self.center, self.up)
end

----
-- Get a ray going from camera through screen point.
-- @tparam number x screen position x
-- @tparam number y screen position y
-- @tparam table viewport (optional) viewport rectangle (x, y, w, h)
-- @treturn table that containing {position = vec3, direction = vec3}
function PerspectiveCamera:screen_point_to_ray(x, y, viewport)
    local w, h = love.graphics.getDimensions()

    local m_pos = vec3(mat4.unproject(vec3(x, y, 1), self.m_view, self.m_projection, { 0, 0, w, h }))
    local c_pos = self.eye:clone()
    local direction = vec3():sub(m_pos, self.eye):normalize()
    return {
        position = c_pos,
        direction = direction,
    }
end

----
-- Transform position from world space into screen space.
-- @tparam number x
-- screen position x or vec3
-- @tparam number y screen position y
-- @tparam number z screen position z
-- @treturn vec2 object
function PerspectiveCamera:world_to_screen_point(x, y, z, viewport)
    local w, h = love.graphics.getDimensions()

    local m_proj = self.m_projection
    local m_view = self.m_view

    local view_p = m_view:multiply_vec4(vec4(x, y, z, 1))
    local proj_p = m_proj:multiply_vec4(view_p)

    if proj_p.w < 0 then
        return vec2(0, 0)
    end

    local ndc_space_pos = vec2(proj_p.x / proj_p.w, proj_p.y / proj_p.w)

    local screen_space_pos = vec2((ndc_space_pos.x + 1) / 2 * w, (ndc_space_pos.y - 1) / -2 * h)

    return screen_space_pos
end

----
-- Get direction.
-- @treturn vec3 object
function PerspectiveCamera:get_direction()
    return (self.center - self.eye):normalize()
end

return PerspectiveCamera
