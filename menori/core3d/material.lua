--[[
-------------------------------------------------------------------------------
	Menori
	@author rozenmad
	2022
-------------------------------------------------------------------------------
]]

--[[--
Base class for materials. A material describes the appearance of an object. (Inherited from UniformList)
]]
-- @classmod Material
-- @see UniformList

local utils = require("menori.libs.utils")
local UniformList = require("menori.core3d.uniform_list")

local ShaderUtils = require("menori.shaders.utils")

---@class menori.Material
local Material = {
	clone = utils.copy,
}
Material.__index = Material
setmetatable(Material, UniformList)

Material.default_shader = ShaderUtils.shaders["default_mesh"]

---@param name string? Name of the material.
---@param shader love.Shader? [opt=Material.default_shader] shader [LOVE Shader](https://love2d.org/wiki/Shader)
function Material.new(name, shader)
	local self = setmetatable(UniformList.new(), Material)

	self.name = name
	self.shader = shader or Material.default_shader

	self.depth_test = true
	self.depth_func = "less"

	self.wireframe = false
	self.mesh_cull_mode = "back"

	self.alpha_mode = "OPAQUE"
	self.main_texture = nil

	return self
end

Material.default = Material.new("Default")
Material.default:set("baseColor", { 1, 1, 1, 1 })
return Material

---
-- Material name.
-- @field name

---
-- The shader object that is bound to the material. (default_shader by default)
-- @field shader

---
-- Depth test flag. (Enabled by default)
-- @field depth_test

---
-- Depth comparison func (mode) used for depth testing.
-- @field depth_func

---
-- Sets whether wireframe lines will be used when drawing.
-- @field wireframe

---
-- Sets whether back-facing triangles in a Mesh are culled.
-- @field mesh_cull_mode

---
-- The texture to be used in mesh:setTexture(). (uniform Image MainTex) in shader.
-- @field main_texture
