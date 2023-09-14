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

local modules = (...):match "(.*%menori.modules.)"

local utils = require(modules .. "libs.utils")
local UniformList = require(modules .. "core3d.uniform_list")

local ShaderUtils = require(modules .. "shaders.utils")

---@class Material: UniformList
---@operator call: Material
---@field super UniformList
---@field name string Material name.
---@field default_shader love.Shader
---@field shader love.Shader The shader object that is bound to the material. (default_shader by default)
---@field depth_test boolean Depth test flag. (Enabled by default)
---@field depth_func love.CompareMode Depth comparison func (mode) used for depth testing.
---@field wireframe boolean Sets whether wireframe lines will be used when drawing.
---@field mesh_cull_mode love.CullMode Sets whether back-facing triangles in a Mesh are culled.
---@field main_texture love.Texture? The texture to be used in mesh:setTexture(). (uniform Image MainTex) in shader.
local Material = UniformList:extend("Material", {
  clone = utils.copy,
})

if love._version_major > 11 then
  Material.default_shader = ShaderUtils.shaders["default_mesh"]
else
  Material.default_shader = ShaderUtils.shaders["default_mesh"]
end

----
-- The public constructor.
---@param name string Name of the material.
-- @param[opt=Material.default_shader] shader [LOVE Shader](https://love2d.org/wiki/Shader)
function Material:init(name, shader)
  Material.super.init(self)

  self.name = name
  self.shader = shader or Material.default_shader

  self.depth_test = true
  self.depth_func = "less"

  self.wireframe = false
  self.mesh_cull_mode = "back"

  self.alpha_mode = "OPAQUE"
  self.main_texture = nil
end

Material.default = Material "Default"
Material.default:set("baseColor", { 1, 1, 1, 1 })
return Material
