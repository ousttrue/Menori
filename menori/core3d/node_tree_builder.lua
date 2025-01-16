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

local Node = require("menori.node")
local ModelNode = require("menori.core3d.model_node")
local Mesh = require("menori.core3d.mesh")
local Material = require("menori.core3d.material")
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
      local model_node = ModelNode.new(m, material)
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

---@param attributes_array table<string, integer>
function NodeTreeBuilder:get_attributes(attributes_array)
  local attributes = {}
  for name, attribute_index in pairs(attributes_array) do
    local buffer = self:get_buffer(attribute_index)
    local element_size = buffer.component_size * buffer.type_elements_count

    local len = element_size * buffer.count
    local bytedata = love.data.newByteData(len)
    local unpack_type = get_unpack_type(buffer.component_type)

    for i = 0, buffer.count - 1 do
      local p1 = buffer.offset + i * buffer.stride
      local p2 = i * element_size

      for k = 0, buffer.type_elements_count - 1 do
        local idx = k * buffer.component_size
        local attr = love.data.unpack(unpack_type, buffer.data, p1 + idx + 1)
        love.data.pack(bytedata, p2 + idx, unpack_type, attr)
      end
    end
    attributes[name] = bytedata
  end

  return attributes
end

---@param animation any
---@return table
function NodeTreeBuilder:read_animation(animation)
  local samplers = {}
  for _, v in ipairs(animation.samplers) do
    local time_buffer = self.data:get_buffer(v.input)
    local data_buffer = self.data:get_buffer(v.output)
    table.insert(samplers, {
      time_array = time_buffer:get_data_array(),
      data_array = data_buffer:get_data_array(),
      interpolation = v.interpolation,
    })
  end

  local channels = {}
  for i, v in ipairs(animation.channels) do
    table.insert(channels, {
      sampler = samplers[v.sampler + 1],
      target_node = v.target.node,
      target_path = v.target.path,
    })
  end

  return channels
end

--- Creates a node tree.
function NodeTreeBuilder:create()
  self.materials = Material.load(self.data)
  self.meshes = Mesh.load(self.data)

  ---@type menori.gltf.Skin
  local skins = {}
  if self.data.gltf.skins then
    for _, v in ipairs(self.data.gltf.skins) do
      local buffer = self.data:get_buffer(v.inverseBindMatrices)
      table.insert(skins, {
        inverse_bind_matrices = buffer:get_data_array(),
        joints = v.joints,
        skeleton = v.skeleton,
      })
    end
  end

  for node_index = 1, #self.data.gltf.nodes do
    local node = self:create_nodes(node_index)
    local skin = self.data.gltf.nodes[node_index].skin
    if skin then
      skin = skins[skin + 1]
      node.joints = {}
      if skin.skeleton then
        node.skeleton_node = self:create_nodes(skin.skeleton + 1)
      end

      local matrices = skin.inverse_bind_matrices
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
    -- if callback then
    -- 	callback(scene_node, builder)
    -- end
    self.scenes[i] = scene_node
  end

  local animations = {}
  if self.data.gltf.animations then
    for i, animation in ipairs(self.data.gltf.animations) do
      animations[i] = {
        channels = self:read_animation(animation),
        name = animation.name,
      }
    end
  end
  for _, v in ipairs(animations) do
    local animation = { name = v.name, channels = {} }
    for j, channel in ipairs(v.channels) do
      animation.channels[j] = {
        target_node = self.nodes[channel.target_node + 1],
        target_path = channel.target_path,
        sampler = channel.sampler,
      }
    end
    table.insert(self.animations, animation)
  end
end

return NodeTreeBuilder
