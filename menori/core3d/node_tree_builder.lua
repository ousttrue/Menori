--[[
-------------------------------------------------------------------------------
      Menori
      @author rozenmad
      2022
-------------------------------------------------------------------------------
]]

--[[--
Module for building scene nodes from a loaded gltf format.
]]
-- @module NodeTreeBuilder

local Material = require("menori.core3d.material")
local Mesh = require("menori.core3d.mesh")
local Node = require("menori.node")
local Aninmation = require("menori.core3d.animation")
local ShaderUtils = require("menori.shaders.utils")
local ml = require("menori.ml")
local mat4 = ml.mat4
local vec3 = ml.vec3
local quat = ml.quat

---@class menori.NodeTreeBuilder
---@field data menori.GltfData
---@field meshes menori.Mesh[][]
---@field materials menori.Material[]
---@field nodes menori.Node[]
---@field scenes menori.Node[]
---@field animations menori.GltfAnimation[]
local NodeTreeBuilder = {}
NodeTreeBuilder.__index = NodeTreeBuilder

---@param data menori.GltfData
---@return menori.NodeTreeBuilder
function NodeTreeBuilder.new(data)
  local self = setmetatable({
    data = data,
    meshes = {},
    materials = {},
    nodes = {},
    animations = {},
    scenes = {},
  }, NodeTreeBuilder)
  return self
end

function NodeTreeBuilder:create_nodes(i)
  local exist = self.nodes[i]
  if exist then
    return exist
  end
  local v = self.data.gltf.nodes[i]
  local t = vec3()
  local r = quat(0, 0, 0, 1)
  local s = vec3(1)
  if v.translation or v.rotation or v.scale then
    t:set(v.translation or { 0, 0, 0 })
    r:set(v.rotation or { 0, 0, 0, 1 })
    s:set(v.scale or { 1, 1, 1 })
  elseif v.matrix then
    mat4(v.matrix):decompose(t, r, s)
  end

  local node
  if v.mesh then
    local array_nodes = {}
    local meshes = self.meshes[v.mesh + 1]
    for j, m in ipairs(meshes) do
      local material
      if m.material_index then
        material = self.materials[m.material_index + 1]
      end
      local model_node = Node.new()
      model_node.mesh = m
      model_node.material = material:clone()
      if v.skin then
        model_node.material.shader = ShaderUtils.shaders["default_mesh_skinning"]
      else
        model_node.material.shader = ShaderUtils.shaders["default_mesh"]
      end
      array_nodes[j] = model_node
    end
    if #array_nodes > 1 then
      node = Node()
      for _, n in ipairs(array_nodes) do
        node:attach(n)
      end
    else
      node = array_nodes[1]
    end
  else
    node = Node.new()
  end

  node.extras = v.extras

  node:set_position(t)
  node:set_rotation(r)
  node:set_scale(s)
  node.name = v.name or node.name

  self.nodes[i] = node

  if v.children then
    for _, child_index in ipairs(v.children) do
      local child = self:create_nodes(child_index + 1)
      node:attach(child)
    end
  end

  return node
end

--- Creates a node tree.
function NodeTreeBuilder:create()
  self.materials = Material.load(self.data)
  self.meshes = Mesh.load(self.data)

  for node_index = 1, #self.data.gltf.nodes do
    local node = self:create_nodes(node_index)
    local skin_index = self.data.gltf.nodes[node_index].skin
    if skin_index then
      local skin = self.data.gltf.skins[skin_index + 1]
      node.joints = {}
      if skin.skeleton then
        node.skeleton_node = self:create_nodes(skin.skeleton + 1)
      end

      local matrices = self.data:get_buffer(skin.inverseBindMatrices):get_data_array()
      -- local matrices = skin.inverse_bind_matrices
      for i, joint in ipairs(skin.joints) do
        local joint_node = self:create_nodes(joint + 1)
        joint_node.inverse_bind_matrix = mat4(matrices[i])
        node.joints[i] = joint_node
      end
    end
  end

  for i, v in ipairs(self.data.gltf.scenes) do
    local scene_node = Node.new(v.name)
    for _, inode in ipairs(v.nodes) do
      scene_node:attach(self.nodes[inode + 1])
    end
    local function update_transform_callback(node)
      node:update_transform()
    end
    scene_node:traverse(update_transform_callback)
    self.scenes[i] = scene_node
  end

  self.animations = Aninmation.load(self.data, self.nodes)
end

return NodeTreeBuilder
