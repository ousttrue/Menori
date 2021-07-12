--[[
-------------------------------------------------------------------------------
	Menori
	@author rozenmad
	2021
-------------------------------------------------------------------------------
--]]

--[[--
An environment is a class that sends information about the current settings of the environment (such as ambient color, fog, light sources, camera transformation matrices) etc to the shader.
]]
-- @module menori.Environment

local modules = (...):match('(.*%menori.modules.)')
local class = require (modules .. 'libs.class')
local utils = require (modules .. 'libs.utils')
local UniformList = require (modules .. 'core3d.uniform_list')

--- Class members
-- @table Environment
-- @field camera The camera associated with the current Environment.
-- @field uniform_list List of uniforms of the current Environment. Uniforms in the list are automatically sent to the shader, which will be used to display objects with this environment.
-- @field lights List of light sources.

local Environment = class('Environment')

--- init
-- @tparam Сamera camera camera that will be associated with this environment
function Environment:init(camera)
	self.camera = camera

	self.uniform_list = UniformList()
	self.lights = {}

	self._shader_object_cache = nil
end

--- Add light source.
-- @tparam strign uniform_name Name of uniform used in the shader
-- @tparam UniformList light
function Environment:add_light(uniform_name, light)
	local t = self.lights[uniform_name] or {}
	self.lights[uniform_name] = t
	table.insert(t, light)
end

--- Sends all the environment uniforms to the shader. This function can be used when creating your own display objects, or for shading technique.
-- @tparam Shader shader
function Environment:send_uniforms_to(shader)
	self.uniform_list:send_to(shader)

	love.graphics.setShader(shader)
	local camera = self.camera
	shader:send("m_view", camera.m_view.data)
	shader:send("m_projection", camera.m_projection.data)

	self:send_light_sources_to(shader)
end

--- Apply shader.
-- @tparam Shader shader
function Environment:apply_shader(shader)
	if self._shader_object_cache ~= shader then
            love.graphics.setShader(shader)

	      self:send_uniforms_to(shader)
            self._shader_object_cache = shader
      end
end

--- Sends light sources uniforms to the shader. This function can be used when creating your own display objects, or for shading technique.
-- @tparam Shader shader
function Environment:send_light_sources_to(shader)
	for k, v in pairs(self.lights) do
		utils.noexcept_send_uniform(shader, k .. '_count', #v)
		for i, light in ipairs(v) do
			light:send_to(shader, k .. "[" .. (i - 1) .. "].")
		end
	end
end

return
Environment