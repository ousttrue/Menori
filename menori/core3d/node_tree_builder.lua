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
local ffi = require("menori.libs.ffi")
local ShaderUtils = require("menori.shaders.utils")
local ml = require("menori.ml")
local mat4 = ml.mat4
local vec3 = ml.vec3
local quat = ml.quat
local Texture = require("menori.core3d.texture")

local function getFFIPointer(data)
  if data.getFFIPointer then
    return data:getFFIPointer()
  else
    return data:getPointer()
  end
end

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

local component_types = {
  [5120] = "int8",
  [5121] = "uint8",
  [5122] = "int16",
  [5123] = "unorm16",
  [5125] = "uint32",
  [5126] = "float",
}

local location_map = {
  VertexPosition = 0,
  VertexTexCoord = 1,
  VertexColor = 2,
  VertexNormal = 3,
  VertexWeights = 4,
  VertexJoints = 5,
  VertexTangent = 6,
}

local add_vertex_format
if love._version_major > 11 then
  local types = {
    ["SCALAR"] = "",
    ["VEC2"] = "vec2",
    ["VEC3"] = "vec3",
    ["VEC4"] = "vec4",
    ["MAT2"] = "mat2x2",
    ["MAT3"] = "mat3x3",
    ["MAT4"] = "mat4x4",
  }
  function add_vertex_format(vertexformat, attribute_name, buffer)
    local format = component_types[buffer.component_type] .. types[buffer.type]
    local location = location_map[attribute_name]
    assert(type(location) == "number")
    table.insert(vertexformat, {
      name = attribute_name,
      format = format,
      location = location,
    })
  end
else
  local types = {
    "byte",
    "unorm16",
    "",
    "float",
  }

  function add_vertex_format(vertexformat, attribute_name, buffer)
    table.insert(vertexformat, {
      attribute_name,
      types[buffer.component_size],
      buffer.type_elements_count,
    })
  end
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

local attribute_aliases = {
  ["POSITION"] = "VertexPosition",
  ["TEXCOORD"] = "VertexTexCoord",
  ["JOINTS"] = "VertexJoints",
  ["NORMAL"] = "VertexNormal",
  ["COLOR"] = "VertexColor",
  ["WEIGHTS"] = "VertexWeights",
  ["TANGENT"] = "VertexTangent",
}

local function get_vertices_content(attribute_buffers, components_stride, length)
  local start_offset = 0
  local temp_data = love.data.newByteData(length)
  if ffi then
    local temp_data_pointer = ffi.cast("char*", getFFIPointer(temp_data))

    for _, buffer in ipairs(attribute_buffers) do
      local element_size = buffer.component_size * buffer.type_elements_count
      for i = 0, buffer.count - 1 do
        local p1 = buffer.offset + i * buffer.stride
        local data = ffi.cast("char*", getFFIPointer(buffer.data)) + p1

        local p2 = start_offset + i * components_stride

        ffi.copy(temp_data_pointer + p2, data, element_size)
      end
      start_offset = start_offset + element_size
    end
  else
    for _, buffer in ipairs(attribute_buffers) do
      local unpack_type = get_unpack_type(buffer.component_type)

      local element_size = buffer.component_size * buffer.type_elements_count

      for i = 0, buffer.count - 1 do
        local p1 = buffer.offset + i * buffer.stride
        local p2 = start_offset + i * components_stride

        for k = 0, buffer.type_elements_count - 1 do
          local idx = k * buffer.component_size
          local attr = love.data.unpack(unpack_type, buffer.data, p1 + idx + 1)
          love.data.pack(temp_data, p2 + idx, unpack_type, attr)
        end
      end
      start_offset = start_offset + element_size
    end
  end

  return temp_data
end

local function get_primitive_modes_constants(mode)
  if mode == 0 then
    return "points"
  elseif mode == 1 then
  elseif mode == 2 then
  elseif mode == 3 then
  elseif mode == 5 then
    return "strip"
  elseif mode == 6 then
    return "fan"
  end
  return "triangles"
end

---@param mesh any
---@return table
function NodeTreeBuilder:init_mesh(mesh)
  local primitives = {}
  for j, primitive in ipairs(mesh.primitives) do
    local indices, indices_tsize
    if primitive.indices then
      indices, indices_tsize = self.data:get_indices_content(primitive.indices)
    end

    local length = 0
    local components_stride = 0
    local attribute_buffers = {}
    local count = 0
    local vertexformat = {}

    for k, v in pairs(primitive.attributes) do
      local attribute, value = k:match("(%w+)(.*)")
      local attribute_name
      if value == "_0" then
        attribute_name = attribute_aliases[attribute]
      elseif attribute_aliases[attribute] then
        attribute_name = attribute_aliases[attribute] .. value
      else
        attribute_name = k
      end

      local buffer = self.data:get_buffer(v)
      attribute_buffers[#attribute_buffers + 1] = buffer
      if count <= 0 then
        count = buffer.count
      end

      local element_size = buffer.component_size * buffer.type_elements_count

      length = length + buffer.count * element_size
      components_stride = components_stride + element_size

      add_vertex_format(vertexformat, attribute_name, buffer)
    end

    local vertices = get_vertices_content(attribute_buffers, components_stride, length)

    local targets = {}
    if primitive.targets then
      for _, attributes in ipairs(primitive.targets) do
        table.insert(targets, self:get_attributes(attributes))
      end
    end

    primitives[j] = {
      mode = get_primitive_modes_constants(primitive.mode),
      vertexformat = vertexformat,
      vertices = vertices,
      indices = indices,
      targets = targets,
      indices_tsize = indices_tsize,
      material_index = primitive.material,
      count = count,
    }
  end
  return {
    primitives = primitives,
    name = mesh.name,
  }
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
---@return table An array of scenes, where each scene is a menori.Node object
---@return table
function NodeTreeBuilder:create()
  self.materials = Material.load(self.data)

  local meshes = {}
  for i, v in ipairs(self.data.gltf.meshes) do
    meshes[i] = self:init_mesh(v)
  end

  for i, v in ipairs(meshes) do
    ---@type menori.Mesh[]
    local t = {}
    self.meshes[i] = t
    for j, primitive in ipairs(v.primitives) do
      t[j] = Mesh.new(primitive)
    end
  end

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
