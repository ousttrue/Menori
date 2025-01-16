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
local Texture = require("menori.core3d.texture")

---@class menori.Material: menori.UniformList
---@field name string Material name.
---@field shader love.Shader The shader object that is bound to the material. (default_shader by default)
-- @field depth_test boolean Depth test flag. (Enabled by default)
-- @field depth_func string Depth comparison func (mode) used for depth testing.
-- @field wireframe boolean Sets whether wireframe lines will be used when drawing.
-- @field mesh_cull_mode string Sets whether back-facing triangles in a Mesh are culled.
-- @field main_texture love.Texture The texture to be used in mesh:setTexture(). (uniform Image MainTex) in shader.
local Material = {
  clone = utils.copy,
}
Material.__index = Material
setmetatable(Material, UniformList)

Material.default_shader = ShaderUtils.shaders["default_mesh"]

---@param name string? Name of the material.
---@param shader love.Shader? [opt=Material.default_shader] shader [LOVE Shader](https://love2d.org/wiki/Shader)
---@return menori.Material
function Material.new(name, shader)
  local self = setmetatable(UniformList.new(), Material)
  ---@cast self menori.Material

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

---@param textures menori.Texture[]
---@param t gltf.TextureInfo
---@return table?
local function get_texture(textures, t)
  if t then
    local texture = textures[t.index + 1]
    local ret = {
      texture = texture,
      source = texture.image.source,
    }
    for k, v in pairs(t) do
      if k ~= "index" then
        ret[k] = v
      end
    end
    return ret
  end
end

local function create_material(textures, material)
  local uniforms = {}

  local main_texture
  local pbr = material.pbrMetallicRoughness
  uniforms.baseColor = (pbr and pbr.baseColorFactor) or { 1, 1, 1, 1 }
  if pbr then
    local _pbrBaseColorTexture = pbr.baseColorTexture
    local _pbrMetallicRoughnessTexture = pbr.metallicRoughnessTexture

    main_texture = get_texture(textures, _pbrBaseColorTexture)
    local metallicRoughnessTexture = get_texture(textures, _pbrMetallicRoughnessTexture)

    if main_texture then
      uniforms.mainTexCoord = main_texture.tcoord
    end
    if metallicRoughnessTexture then
      uniforms.metallicRoughnessTexture = metallicRoughnessTexture.source
      uniforms.metallicRoughnessTextureCoord = metallicRoughnessTexture.tcoord
    end

    uniforms.metalness = pbr.metallicFactor
    uniforms.roughness = pbr.roughnessFactor
  end

  if material.normalTexture then
    local normalTexture = get_texture(textures, material.normalTexture)
    uniforms.normalTexture = normalTexture.source
    uniforms.normalTextureCoord = normalTexture.tcoord
    uniforms.normalTextureScale = normalTexture.scale
  end

  if material.occlusionTexture then
    local occlusionTexture = get_texture(textures, material.occlusionTexture)
    uniforms.occlusionTexture = occlusionTexture.source
    uniforms.occlusionTextureCoord = occlusionTexture.tcoord
    uniforms.occlusionTextureStrength = occlusionTexture.strength
  end

  if material.emissiveTexture then
    local emissiveTexture = get_texture(textures, material.emissiveTexture)
    uniforms.emissiveTexture = emissiveTexture.source
    uniforms.emissiveTextureCoord = emissiveTexture.tcoord
  end
  uniforms.emissiveFactor = material.emissiveFactor or { 0, 0, 0 }
  uniforms.opaque = material.alphaMode == "OPAQUE" or not material.alphaMode
  if material.alphaMode == "MASK" then
    uniforms.alphaCutoff = material.alphaCutoff or 0.5
  else
    uniforms.alphaCutoff = 0.0
  end

  return {
    name = material.name,
    main_texture = main_texture,
    uniforms = uniforms,
    double_sided = material.doubleSided,
    alpha_mode = material.alphaMode or "OPAQUE",
  }
end

---@param data menori.GltfData
---@return menori.Material[]
function Material.load(data)
  local textures = Texture.load(data)
  local materials = {}
  if data.gltf.materials then
    for i, v in ipairs(data.gltf.materials) do
      materials[i] = create_material(textures, v)
    end
  end

  for i, v in ipairs(materials) do
    local material = Material.new(v.name)
    material.mesh_cull_mode = v.double_sided and "none" or "back"
    material.alpha_mode = v.alpha_mode
    material.alpha_cutoff = v.alpha_cutoff
    if v.main_texture then
      material.main_texture = v.main_texture.source
    end
    for name, uniform in pairs(v.uniforms) do
      material:set(name, uniform)
    end
    materials[i] = material
  end

  return materials
end

Material.default = Material.new("Default")
Material.default:set("baseColor", { 1, 1, 1, 1 })
return Material
