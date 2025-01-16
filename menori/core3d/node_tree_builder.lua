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

--- Creates a node tree.
function NodeTreeBuilder:create()
  self.materials = Material.load(self.data)
  self.meshes = Mesh.load(self.data)
  self.nodes = Node.load(self.data)

  for node_index, node in ipairs(self.nodes) do
    local gltf_node = self.data.gltf.nodes[node_index]

    -- children build hierarchy
    if gltf_node.children then
      for _, child_index in ipairs(gltf_node.children) do
        local child = self.nodes[child_index + 1]
        node:attach(child)
      end
    end

    -- mesh attach mesh to node
    if gltf_node.mesh then
      local meshes = self.meshes[gltf_node.mesh + 1]
      node.meshes = {}
      for j, m in ipairs(meshes) do
        local material
        if m.material_index then
          material = self.materials[m.material_index + 1]
        end
        table.insert(node.meshes, m)
        node.material = material:clone()
        if gltf_node.skin then
          node.material.shader = ShaderUtils.shaders["default_mesh_skinning"]
        else
          node.material.shader = ShaderUtils.shaders["default_mesh"]
        end
      end
    end

    -- skin bone weight skinning
    if gltf_node.skin then
      local skin = self.data.gltf.skins[gltf_node.skin + 1]
      node.joints = {}
      if skin.skeleton then
        node.skeleton_node = self.nodes[skin.skeleton + 1]
      end
      local matrices = self.data:get_buffer(skin.inverseBindMatrices):get_data_array()
      -- local matrices = skin.inverse_bind_matrices
      for i, joint in ipairs(skin.joints) do
        local joint_node = self.nodes[joint + 1]
        joint_node.inverse_bind_matrix = mat4(matrices[i])
        node.joints[i] = joint_node
      end
    end
  end

  -- scene
  for _, v in ipairs(self.data.gltf.scenes) do
    local scene_node = Node.new(v.name)
    for _, inode in ipairs(v.nodes) do
      scene_node:attach(self.nodes[inode + 1])
    end
    local function update_transform_callback(node)
      node:update_transform()
    end
    scene_node:traverse(update_transform_callback)
    table.insert(self.scenes, scene_node)
  end

  self.animations = Aninmation.load(self.data, self.nodes)
end

return NodeTreeBuilder
