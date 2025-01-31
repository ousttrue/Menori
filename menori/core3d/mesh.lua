--[[
-------------------------------------------------------------------------------
      Menori
      @author rozenmad
      2022
-------------------------------------------------------------------------------
]]

--[[--
Class for initializing and storing mesh vertices and material.
]]
-- @classmod Mesh

local ffi = require("ffi")
local ml = require("menori.ml")
local vec3 = ml.vec3
local mat4 = ml.mat4
local bound3 = ml.bound3
local lg = love.graphics

---@class menori.Mesh
---@field lg_mesh love.Mesh
---@field material_index integer
local Mesh = {}
Mesh.__index = Mesh

---
-- Own copy of the Material that is bound to the model.
-- @field material

---
-- The menori.Mesh object that is bound to the model.
-- @field mesh

---
-- Model color. (Deprecated)
-- @field color

local default_template = { 1, 2, 3, 2, 4, 3 }

local vertexformat
if love._version_major > 11 then
  vertexformat = {
    { format = "floatvec3", name = "VertexPosition", location = 0 },
    { format = "floatvec2", name = "VertexTexCoord", location = 1 },
    { format = "floatvec3", name = "VertexNormal", location = 3 },
  }
else
  vertexformat = {
    { "VertexPosition", "float", 3 },
    { "VertexTexCoord", "float", 2 },
    { "VertexNormal", "float", 3 },
  }
end

Mesh.default_vertexformat = vertexformat

---@param attributes_array table<string, integer>
local function get_attributes(attributes_array)
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

---@return love.Mesh
local function create_mesh_from_primitive(primitive, texture)
  local count = primitive.count or #primitive.vertices
  assert(count > 0)

  local vertexformat = primitive.vertexformat or Mesh.default_vertexformat
  local mode = primitive.mode or "triangles"

  local lg_mesh = lg.newMesh(vertexformat, primitive.vertices, mode, "static")

  if primitive.indices then
    local idatatype
    if primitive.indices_tsize then
      idatatype = primitive.indices_tsize <= 2 and "uint16" or "uint32"
    end
    lg_mesh:setVertexMap(primitive.indices, idatatype)
  end
  if texture then
    lg_mesh:setTexture(texture)
  end
  return lg_mesh
end

local function calculate_bound(lg_mesh_obj)
  local t = {}

  local count = lg_mesh_obj:getVertexCount()
  if count then
    local format = lg_mesh_obj:getVertexFormat()
    local pindex = Mesh.get_attribute_index("VertexPosition", format)

    local x, y, z = lg_mesh_obj:getVertexAttribute(1, pindex)
    t.x1, t.x2 = x, x
    t.y1, t.y2 = y, y
    t.z1, t.z2 = z, z

    for i = 2, lg_mesh_obj:getVertexCount() do
      x, y, z = lg_mesh_obj:getVertexAttribute(i, pindex)
      if x < t.x1 then
        t.x1 = x
      elseif x > t.x2 then
        t.x2 = x
      end
      if y < t.y1 then
        t.y1 = y
      elseif y > t.y2 then
        t.y2 = y
      end
      if z < t.z1 then
        t.z1 = z
      elseif z > t.z2 then
        t.z2 = z
      end
    end
  end
  return bound3(vec3(t.x1, t.y1, t.z1), vec3(t.x2, t.y2, t.z2))
end

--- Generate indices for quadrilateral primitives.
-- @static
-- @tparam number count Count of vertices
-- @tparam table template Template list that is used to generate indices in a specific sequence
function Mesh.generate_indices(count, template)
  template = template or default_template
  local indices = {}
  for j = 0, count / 4 - 1 do
    local v = j * 6
    local i = j * 4
    indices[v + 1] = i + template[1]
    indices[v + 2] = i + template[2]
    indices[v + 3] = i + template[3]
    indices[v + 4] = i + template[4]
    indices[v + 5] = i + template[5]
    indices[v + 6] = i + template[6]
  end
  return indices
end

--- Get the attribute index from the vertex format.
-- @static
-- @tparam string attribute The attribute to be found.
-- @tparam table format Vertex format table.
function Mesh.get_attribute_index(attribute, format)
  for i, v in ipairs(format) do
    if v[1] == attribute or v.name == attribute then
      return i
    end
  end
end

--- Create a menori.Mesh from vertices.
-- @static
-- @tparam table vertices that contains vertex data. See [LOVE Mesh](https://love2d.org/wiki/love.graphics.newMesh)
-- @tparam[opt] table opt that containing {mode=, vertexformat=, indices=, texture=}
function Mesh.from_primitive(vertices, opt)
  return Mesh.new({
    mode = opt.mode,
    vertices = vertices,
    vertexformat = opt.vertexformat,
    indices = opt.indices,
    texture = opt.texture,
  })
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

local function getFFIPointer(data)
  if data.getFFIPointer then
    return data:getFFIPointer()
  else
    return data:getPointer()
  end
end

local function get_vertices_content(attribute_buffers, components_stride, length)
  local start_offset = 0
  local temp_data = love.data.newByteData(length)
  if ffi then
    local temp_data_pointer = ffi.cast("char*", getFFIPointer(temp_data))

    for _, buffer in ipairs(attribute_buffers) do
      local element_size = buffer.component_size * buffer.type_elements_count
      for i = 0, buffer.count - 1 do
        local p1 = buffer.offset + i * buffer.stride
        local data = ffi.cast("char*", buffer:getFFIPointer()) + p1

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

---@param data menori.GltfData
---@param mesh any
---@return menori.Mesh[]
local function init_mesh(data, mesh)
  local primitives = {}
  for j, primitive in ipairs(mesh.primitives) do
    local indices, indices_tsize
    if primitive.indices then
      indices, indices_tsize = data:get_indices_content(primitive.indices)
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

      local buffer = data:get_buffer(v)
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
  return primitives
end

--- The public constructor.
-- @tparam table primitives List of primitives
-- @tparam[opt] Image texture
---@return menori.Mesh
function Mesh.new(primitive, texture)
  local self = setmetatable({}, Mesh)
  local mesh = create_mesh_from_primitive(primitive, texture)
  self.vertex_attribute_index = Mesh.get_attribute_index("VertexPosition", mesh:getVertexFormat())
  self.lg_mesh = mesh
  self.material_index = primitive.material_index
  self.bound = calculate_bound(mesh)
  return self
end

---@param data menori.GltfData
---@return menori.Mesh[][]
function Mesh.load(data)
  local meshes = {}
  for i, v in ipairs(data.gltf.meshes) do
    meshes[i] = init_mesh(data, v)
  end

  for i, v in ipairs(meshes) do
    ---@type menori.Mesh[]
    local t = {}
    meshes[i] = t
    for j, primitive in ipairs(v) do
      t[j] = Mesh.new(primitive)
    end
  end

  return meshes
end

--- Draw a Mesh object on the screen.
-- @tparam menori.Material material The Material to be used when drawing the mesh.
function Mesh:draw(material)
  material:send_to(material.shader)

  if material.wireframe ~= lg.isWireframe() then
    lg.setWireframe(material.wireframe)
  end
  if material.depth_test then
    if material.depth_func ~= lg.getDepthMode() then
      lg.setDepthMode(material.depth_func, true)
    end
  else
    lg.setDepthMode()
  end
  if material.mesh_cull_mode ~= lg.getMeshCullMode() then
    lg.setMeshCullMode(material.mesh_cull_mode)
  end

  local mesh = self.lg_mesh
  mesh:setTexture(material.main_texture)
  lg.draw(mesh)
end

function Mesh:get_bound()
  return self.bound
end

function Mesh:get_vertex_count()
  return self.lg_mesh:getVertexCount()
end

function Mesh:get_vertex_attribute(name, index, out)
  local mesh = self.lg_mesh
  local attribute_index = Mesh.get_attribute_index(name, mesh:getVertexFormat())

  out = out or {}
  table.insert(out, {
    mesh:getVertexAttribute(index, attribute_index),
  })
  return out
end

function Mesh:get_triangles_transform(matrix)
  local triangles = {}
  local mesh = self.lg_mesh
  local attribute_index = Mesh.get_attribute_index("VertexPosition", mesh:getVertexFormat())
  local map = mesh:getVertexMap()
  if map then
    for i = 1, #map, 3 do
      local v1 = vec3(mesh:getVertexAttribute(map[i + 0], attribute_index))
      local v2 = vec3(mesh:getVertexAttribute(map[i + 1], attribute_index))
      local v3 = vec3(mesh:getVertexAttribute(map[i + 2], attribute_index))
      matrix:multiply_vec3(v1, v1)
      matrix:multiply_vec3(v2, v2)
      matrix:multiply_vec3(v3, v3)
      table.insert(triangles, {
        { v1:unpack() },
        { v2:unpack() },
        { v3:unpack() },
      })
    end
  end
  return triangles
end

--- Create a cached array of triangles from the mesh vertices and return it.
-- @treturn table Triangles { {{x, y, z}, {x, y, z}, {x, y, z}}, ...}
function Mesh:get_triangles()
  return self:get_triangles_transform(mat4())
end

--- Get an array of all mesh vertices.
-- @tparam[opt=1] int iprimitive The index of the primitive.
-- @treturn table The table in the form of {vertex, ...} where each vertex is a table in the form of {attributecomponent, ...}.
function Mesh:get_vertices(start, count)
  local mesh = self.lg_mesh
  start = start or 1
  count = count or mesh:getVertexCount()

  local vertices = {}
  for i = start, start + count - 1 do
    table.insert(vertices, { mesh:getVertex(i) })
  end
  return vertices
end

function Mesh:get_vertices_transform(matrix, start, count)
  local mesh = self.lg_mesh
  start = start or 1
  count = count or mesh:getVertexCount()

  local vertices = {}
  for i = start, start + count - 1 do
    local v = vec3(mesh:getVertex(i))
    matrix:multiply_vec3(v, v)
    table.insert(vertices, { v:unpack() })
  end
  return vertices
end

function Mesh:get_vertex_map()
  return self.lg_mesh:getVertexMap()
end

--- Get an array of all mesh vertices.
-- @tparam table vertices The table in the form of {vertex, ...} where each vertex is a table in the form of {attributecomponent, ...}.
-- @tparam number startvertex The vertex from which the insertion will start.
function Mesh:set_vertices(vertices, startvertex)
  self.lg_mesh:setVertices(vertices, startvertex)
end

--- Apply the transformation matrix to the mesh vertices.
-- @tparam ml.mat4 matrix
function Mesh:apply_matrix(matrix)
  local temp_v3 = vec3(0, 0, 0)

  local mesh = self.lg_mesh
  local format = mesh:getVertexFormat()
  local pindex = Mesh.get_attribute_index("VertexPosition", format)

  for j = 1, mesh:getVertexCount() do
    local x, y, z = mesh:getVertexAttribute(j, pindex)
    temp_v3:set(x, y, z)
    matrix:multiply_vec3(temp_v3, temp_v3)

    mesh:setVertexAttribute(j, pindex, temp_v3.x, temp_v3.y, temp_v3.z)
  end
end

--- Calculate AABB by applying the current transformations.
---@param world_matrix menori.mat4
-- @tparam[opt=1] number index The index of the primitive in the mesh.
-- @treturn menori.ml.bound3 object
function Mesh:calculate_aabb(world_matrix)
  local bound = self.bound
  local min = bound.min
  local max = bound.max
  -- self:recursive_update_transform()
  local m = world_matrix
  local t = {
    m:multiply_vec3(vec3(min.x, min.y, min.z)),
    m:multiply_vec3(vec3(max.x, min.y, min.z)),
    m:multiply_vec3(vec3(min.x, min.y, max.z)),

    m:multiply_vec3(vec3(min.x, max.y, min.z)),
    m:multiply_vec3(vec3(max.x, max.y, min.z)),
    m:multiply_vec3(vec3(min.x, max.y, max.z)),

    m:multiply_vec3(vec3(max.x, min.y, max.z)),
    m:multiply_vec3(vec3(max.x, max.y, max.z)),
  }

  local aabb = bound3(vec3(math.huge), vec3(-math.huge))
  for i = 1, #t do
    local v = t[i]
    if aabb.min.x > v.x then
      aabb.min.x = v.x
    elseif aabb.max.x < v.x then
      aabb.max.x = v.x
    end
    if aabb.min.y > v.y then
      aabb.min.y = v.y
    elseif aabb.max.y < v.y then
      aabb.max.y = v.y
    end
    if aabb.min.z > v.z then
      aabb.min.z = v.z
    elseif aabb.max.z < v.z then
      aabb.max.z = v.z
    end
  end

  return aabb
end

--- Draw a ModelNode object on the screen.
-- This function will be called implicitly in the hierarchy when a node is drawn with scene:render_nodes()
---@param world_matrix menori.mat4
---@param material menori.Material
---@param environment menori.Environment object that is used when drawing the model
---@param joints menori.Node[]?
function Mesh:render(world_matrix, material, environment, joints)
  local shader = material.shader
  environment:apply_shader(shader)
  shader:send("m_model", "column", world_matrix.data)

  if joints then
    -- if self.skeleton_node then
    --       shader:send('m_skeleton', self.skeleton_node.world_matrix.data)
    -- end

    local size = math.max(math.ceil(math.sqrt(#joints * 4) / 4) * 4, 4)
    data = love.data.newByteData(size * size * 4 * 4)

    local matrix_bytesize = 16 * 4
    for i = 1, #joints do
      local node = joints[i]

      if ffi then
        local ptr = ffi.cast("char*", data:getFFIPointer()) + (i - 1) * matrix_bytesize
        ffi.copy(ptr, node.joint_matrix.e + 1, matrix_bytesize)
      else
        data:setFloat((i - 1) * matrix_bytesize, node.joint_matrix.e)
      end
    end

    local joints_texture_data = love.image.newImageData(size, size, "rgba32f", data)
    joints_texture = love.graphics.newImage(joints_texture_data)

    shader:send("joints_texture", joints_texture)
  end

  -- local c = self.color
  -- love.graphics.setColor(c.x, c.y, c.z, c.w)
  self:draw(material)
end

return Mesh
