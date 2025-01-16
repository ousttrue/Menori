--[[
-------------------------------------------------------------------------------
      Menori
      @author rozenmad
      2022
-------------------------------------------------------------------------------
]]

--[[--
Node is the base class of all display objects.
Node object can be assigned as a child of another node, resulting in a tree arrangement.
You need to inherit from the Node class to create your own display object.
]]
--- @classmod Node

local ml = require("menori.ml")
local mat4 = ml.mat4
local vec3 = ml.vec3
local quat = ml.quat
local bound3 = ml.bound3

---@class menori.Node
---@name string Name of node.
---@field children menori.Node[] Children of this node
---@field parent menori.Node? Parent of this node.
---@field detach_flag boolean Flag that is used to detach this node from its parent during the next scene update.
---@field update_flag boolean Flag that sets whether the node is updated during the scene update pass.
---@field render_flag boolean Flag that sets whether the node is rendered during the scene render pass.
---@field calculate_local_transform_flag boolean Flag that sets whether the node transformations will be updated.
---@field local_matrix menori.mat4 Local transformation matrix
---@field world_matrix menori.mat4 World transformation matrix based on world (parent) factors.
---@field joint_matrix menori.mat4
---@field position menori.vec3  Local position.
---@field rotation menori.quat Local rotation.
---@field scale menori.vec3 Local scale.
---@field extras table?
---@field meshes menori.Mesh[]?
---@field material menori.Material?
local Node = {}
Node.__index = Node
Node.layer = 0

--- The public constructor.
---@param name string? name Node name.
---@return menori.Node
function Node.new(name)
  local self = setmetatable({
    name = name or "node",
    children = {},
  }, Node)

  self.detach_flag = false
  self.update_flag = true
  self.render_flag = true
  self.calculate_local_transform_flag = true

  self.local_matrix = mat4()
  self.world_matrix = mat4()
  self.joint_matrix = mat4()

  self._transform_flag = true

  self.position = vec3(0)
  self.rotation = quat()
  self.scale = vec3(1)

  return self
end

---@param v gltf.Node
---@return menori.Node
function Node.from_gltf_node(v)
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

  local node = Node.new(v.name)
  node.extras = v.extras
  node:set_position(t)
  node:set_rotation(r)
  node:set_scale(s)
  return node
end

---comment
---@param data menori.GltfData
---@return menori.Node[]
function Node.load(data)
  local nodes = {}
  for _, gltf_node in ipairs(data.gltf.nodes) do
    local node = Node.from_gltf_node(gltf_node)
    table.insert(nodes, node)
  end
  return nodes
end

--- Set Node local position.
-- @tparam number x
-- position x or vec3
-- @tparam number y position y
-- @tparam number z position z
function Node:set_position(x, y, z)
  self._transform_flag = true
  self.position:set(x, y, z)
end

--- Set Node local rotation.
-- @tparam ml.quat q Rotation quaternion.
function Node:set_rotation(q)
  self._transform_flag = true
  self.rotation = q
end

--- Set Node local scale.
-- @tparam number sx
-- scale sx or vec3
-- @tparam number sy scale y
-- @tparam number sz scale z
function Node:set_scale(sx, sy, sz)
  self._transform_flag = true
  self.scale:set(sx, sy, sz)
end

--- Get world space position of the Node.
-- @tparam[opt] vec3 retvalue
-- @treturn vec3 object
function Node:get_world_position(retvalue)
  self:recursive_update_transform()
  local p = retvalue or vec3()
  self.world_matrix:decompose(p, nil, nil)
  return p
end

--- Get world space rotation of the Node.
-- @tparam[opt] quat retvalue
-- @treturn quat object
function Node:get_world_rotation(retvalue)
  self:recursive_update_transform()
  local q = retvalue or quat()
  self.world_matrix:decompose(nil, q, nil)
  return q
end

--- The world space scale of the Node.
-- @tparam[opt] vec3 retvalue
-- @return vec3 object
function Node:get_world_scale(retvalue)
  self:recursive_update_transform()
  local s = retvalue or vec3()
  self.world_matrix:decompose(nil, nil, s)
  return s
end

--- The red axis of the transform in world space.
-- @tparam[opt] vec3 retvalue
-- @return vec3 object
function Node:right(retvalue)
  self:recursive_update_transform()
  return (retvalue or vec3()):set(self.world_matrix[1], self.world_matrix[5], self.world_matrix[9])
end

--- The green axis of the transform in world space.
-- @tparam[opt] vec3 retvalue
-- @return vec3 object
function Node:up(retvalue)
  self:recursive_update_transform()
  return (retvalue or vec3()):set(self.world_matrix[2], self.world_matrix[6], self.world_matrix[10])
end

--- The blue axis of the transform in world space.
-- @tparam[opt] vec3 retvalue
-- @treturn vec3 object
function Node:forward(retvalue)
  self:recursive_update_transform()
  return (retvalue or vec3()):set(self.world_matrix[3], self.world_matrix[7], self.world_matrix[11])
end

function Node:_recursive_get_aabb(t)
  if self.mehshes then
    for _, mesh in ipairs(self.meshes) do
      local a = t
      local b = mesh:calculate_aabb()

      if a.min.x > b.min.x then
        a.min.x = b.min.x
      end
      if a.min.y > b.min.y then
        a.min.y = b.min.y
      end
      if a.min.z > b.min.z then
        a.min.z = b.min.z
      end

      if a.max.x < b.max.x then
        a.max.x = b.max.x
      end
      if a.max.y < b.max.y then
        a.max.y = b.max.y
      end
      if a.max.z < b.max.z then
        a.max.z = b.max.z
      end
    end
  end

  for _, v in ipairs(self.children) do
    v:_recursive_get_aabb(t)
  end
  return t
end

--- Calculate the largest AABB in down the hierarchy of nodes.
-- @treturn bound3 object
function Node:get_aabb()
  return self:_recursive_get_aabb(bound3(vec3(math.huge), vec3(-math.huge)))
end

local _transform_force = false

local function _recursive_update_transform(node)
  if node.parent then
    node.parent:recursive_update_transform(node.parent)
  end
  if _transform_force or node._transform_flag then
    node:update_transform()
    _transform_force = true
  end
end

--- Update all transform up the hierarchy to the root node.
-- @tparam[opt] bool force Forced update transformations of all nodes up to the root node.
function Node:recursive_update_transform(force)
  _transform_force = force
  return _recursive_update_transform(self)
end

--- Update transform only for this node.
function Node:update_transform(parent_world_matrix)
  local local_matrix = self.local_matrix
  local world_matrix = self.world_matrix

  if self.calculate_local_transform_flag then
    local_matrix:compose(self.position, self.rotation, self.scale)
    self._transform_flag = false
  end

  local parent = self.parent
  if parent then
    world_matrix:copy(parent_world_matrix or parent.world_matrix)
    world_matrix:multiply(local_matrix)
  else
    world_matrix:copy(local_matrix)
  end

  if self.inverse_bind_matrix then
    self.joint_matrix:copy(world_matrix)
    self.joint_matrix:multiply(self.inverse_bind_matrix)
  end
end

--- Get child Node by index.
-- @tparam number index
-- @treturn menori.Node object
function Node:get_child_by_index(index)
  assert(index <= #self.children and index > 0, "child index out of range")
  return self.children[index]
end

--- Remove all children from this node.
function Node:remove_children()
  for i = #self.children, 1, -1 do
    self.children[i].parent = nil
    self.children[i] = nil
  end
end

--- Attach child node to this node.
-- @tparam menori.Node object
-- @treturn menori.Node object
function Node:attach(...)
  for i, node in ipairs({ ... }) do
    self.children[#self.children + 1] = node
    node:update_transform()
    node.parent = self
  end
  return ...
end

--- Detach child node.
-- @tparam menori.Node child
function Node:detach(child)
  for i, v in ipairs(self.children) do
    if v == child then
      table.remove(self.children, i)
    end
  end
end

function _find(children, t, i)
  for _, v in ipairs(children) do
    if v.name == t[i] then
      if t[i + 1] then
        return _find(v.children, t, i + 1)
      else
        return v
      end
    end
  end
end

--- Find a child node by name.
-- @tparam string name If name contains a '/' character it will access
-- the Node in the hierarchy like a path name.
-- @treturn menori.Node The found child or nil
function Node:find(name)
  local t = {}
  for v in name:gmatch("([^/]+)") do
    table.insert(t, v)
  end
  return _find(self.children, t, 1)
end

--- Recursively traverse all nodes.
-- @tparam function callback Function that is called for every child node with params (child, index)
function Node:traverse(callback, _index)
  callback(self, _index or 1)
  local children = self.children
  for i = #children, 1, -1 do
    if children[i]:traverse(callback, i) then
      return
    end
  end
end

--- Detach this node from the parent node.
function Node:detach_from_parent()
  local parent = self.parent
  if parent then
    local children = parent.children
    for i = 1, #children do
      if children[i] == self then
        table.remove(children, i)
        break
      end
    end
    self.parent = nil
  end
end

--- Get the topmost Node in the hierarchy.
-- @tparam[opt] menori.Node upto the Node where the hierarchy recursion will stop if it exist
function Node:get_root_node(upto)
  if self.parent and self.parent ~= upto then
    return self.parent:get_root_node(upto)
  end
  return self
end

--- The number of children attached to this node.
function Node:children_count()
  return #self.children
end

--- Recursively print all the children attached to this node.
function Node:debug_print(node, tabs)
  node = node or self
  tabs = tabs or ""
  print(string.format("%s -> Node: %s | Children: %i", tabs .. node.name, node, #node.children))
  tabs = tabs .. "  "
  for _, v in ipairs(node.children) do
    self:debug_print(v, tabs)
  end
end

return Node
