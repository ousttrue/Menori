-- Basic lighting Menori Example
--[[
-------------------------------------------------------------------------------
	Menori
	@author rozenmad
	2023
-------------------------------------------------------------------------------
]]

local menori = require("menori")

local ml = menori.ml
local vec3 = ml.vec3
local quat = ml.quat
local ml_utils = ml.utils

---@class PointLight: menori.UniformList
---@field position [number, number, number]
local PointLight = {}
PointLight.__index = PointLight
setmetatable(PointLight, menori.UniformList)

---@return PointLight
function PointLight.new(x, y, z, r, g, b)
  local self = setmetatable(menori.UniformList.new(), PointLight)
  self:set("position", { x, y, z })
  self:set("constant", 1.0)
  self:set("linear", 0.3)
  self:set("quadratic", 0.032)
  self:set("ambient", { r, g, b })
  self:set("diffuse", { r, g, b })
  self:set("specular", { r, g, b })
  return self
end

---@class BasicLightingScene: menori.Scene
local BasicLightingScene = {}
BasicLightingScene.__index = BasicLightingScene
setmetatable(BasicLightingScene, menori.Scene)

---@return BasicLightingScene
function BasicLightingScene.new()
  local self = setmetatable(menori.Scene.new("Basic Lighting"), BasicLightingScene)

  local w, h = love.graphics.getDimensions()
  self.camera = menori.PerspectiveCamera.new(60, w / h, 0.5, 1024)
  self.environment = menori.Environment.new(self.camera)

  -- adding light sources
  self.environment:add_light("point_lights", PointLight.new(0, 0.5, 2, 0.8, 0.3, 0.1))
  self.environment:add_light("point_lights", PointLight.new(2, 1, -1, 0.1, 0.3, 0.8))

  self.root_node = menori.Node.new()
  self.aabb_root = self.root_node:attach(menori.Node.new())

  -- loading the fragment shader code for lighting
  local lighting_frag =
    menori.utils.shader_preprocess(love.filesystem.read("examples/basic_lighting/basic_lighting_frag.glsl"))
  local lighting_shader = love.graphics.newShader(menori.ShaderUtils.cache["default_mesh_vert"], lighting_frag)

  local gltf, buffers = menori.glTFLoader.parse("examples/assets/pokemon_firered_-_players_room.glb")
  local builder = menori.NodeTreeBuilder.new(menori.GltfData.new(gltf, buffers))
  builder:create()

  local scene = builder.scenes[1]
  -- function(scene, builder)
  -- Callback for each scene in the gltf.
  -- Create AABB for each node and add it to the aabb_root node.
  scene:traverse(function(node)
    if node.meshes then
      node.material.shader = lighting_shader

      --local bound = node:get_aabb()
      --local size = bound:size()
      --local boxshape = menori.BoxShape(size.x, size.y, size.z)
      --local material = menori.Material()
      --material.wireframe = true
      --material.mesh_cull_mode = 'none'
      --material.alpha_mode = 'BLEND'
      --material:set('baseColor', {1.0, 1.0, 0.0, 0.12})
      --local t = menori.ModelNode(boxshape, material)
      --t:set_position(bound:center())
      --self.aabb_root:attach(t)
    end
  end)
  -- end)
  self.root_node:attach(scene)

  self.x_angle = 0
  self.y_angle = -30
  self.view_scale = 10

  return self
end

function BasicLightingScene:render()
  love.graphics.clear(0.3, 0.25, 0.2)

  -- Recursively draw all the nodes that were attached to the root node.
  -- Sorting nodes by transparency.
  self:render_nodes(self.root_node, self.environment, {
    node_sort_comp = menori.Scene.alpha_mode_comp,
  })
end

function BasicLightingScene:update_camera()
  local q = quat.from_euler_angles(0, math.rad(self.x_angle), math.rad(self.y_angle)) * vec3.unit_z * self.view_scale
  local v = vec3(0, 0.5, 0)
  self.camera.center = v
  self.camera.eye = q + v
  self.camera:update_view_matrix()

  self.environment:set_vector("view_position", self.camera.eye)
end

-- camera control
---@param x number
---@param y number
---@param dx number
---@param dy number
---@param istouch boolean
function BasicLightingScene:on_mousemoved(x, y, dx, dy, istouch)
  if love.mouse.isDown(2) then
    self.y_angle = self.y_angle - dy * 0.2
    self.x_angle = self.x_angle - dx * 0.2
    self.y_angle = ml_utils.clamp(self.y_angle, -45, 45)
  end
end

---@param x number
---@param y number
function BasicLightingScene:wheelmoved(x, y)
  self.view_scale = self.view_scale - y * 0.2
end

function BasicLightingScene:update()
  self:update_camera()
  self:update_nodes(self.root_node, self.environment)
end

return BasicLightingScene
