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

local modules = (...):match "(.*%menori.modules.)"

---@class Node
local Node = require(modules .. ".node")
---@class ModelNode
local ModelNode = require(modules .. "core3d.model_node")
---@class Mesh
local Mesh = require(modules .. "core3d.mesh")
---@class Material
local Material = require(modules .. "core3d.material")
---@class ShaderUtils
local ShaderUtils = require(modules .. "shaders.utils")
local ml = require(modules .. "ml")
---@class mat4
local mat4 = ml.mat4
---@class vec3
local vec3 = ml.vec3
---@class quat
local quat = ml.quat
---@class NodeTreeBuilder
local NodeTreeBuilder = {}

---@class BuilderData
---@field meshes LoaderMesh[]
---@field materials LoaderMaterial[]
---@field nodes Node[]

---@param builder BuilderData
---@param nodes GltfNode[]
---@param i integer
---@return Node
local function create_nodes(builder, nodes, i)
  local exist = builder.nodes[i]
  if exist then
    return exist
  end
  local v = nodes[i]
  local node
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

  if v.mesh then
    local array_nodes = {}
    local meshes = builder.meshes[v.mesh + 1]
    for j, m in ipairs(meshes) do
      local material
      if m.material_index then
        material = builder.materials[m.material_index + 1]
      end
      local model_node = ModelNode(m, material)
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
    node = Node()
  end

  node.extras = v.extras

  node:set_position(t)
  node:set_rotation(r)
  node:set_scale(s)
  node.name = v.name or node.name

  builder.nodes[i] = node

  if v.children then
    for _, child_index in ipairs(v.children) do
      local child = create_nodes(builder, nodes, child_index + 1)
      node:attach(child)
    end
  end

  return node
end

local function update_transform_callback(node)
  node:update_transform()
end

--- Creates a node tree.
---@param loader LoaderData Data obtained with glTFLoader.load
---@param callback fun(node: Node, builder: NodeTreeBuilder)? Callback Called for each built scene with params (scene, builder).
---@return Node[] An array of scenes, where each scene is a menori.Node object
function NodeTreeBuilder.create(loader, callback)
  local builder = {
    meshes = {},
    materials = {},
    nodes = {},
  }

  for i, v in ipairs(loader.meshes) do
    local t = {}
    builder.meshes[i] = t
    for j, primitive in ipairs(v.primitives) do
      t[j] = Mesh(primitive)
    end
  end

  for i, v in ipairs(loader.materials) do
    local material = Material(v.name)
    material.mesh_cull_mode = v.double_sided and "none" or "back"
    material.alpha_mode = v.alpha_mode
    material.alpha_cutoff = v.alpha_cutoff
    if v.main_texture then
      material.main_texture = v.main_texture.source
    end
    for name, uniform in pairs(v.uniforms) do
      material:set(name, uniform)
    end
    builder.materials[i] = material
  end

  for node_index = 1, #loader.nodes do
    local node = create_nodes(builder, loader.nodes, node_index)
    local skin_index = loader.nodes[node_index].skin
    if skin_index then
      local skin = loader.skins[skin_index + 1]
      node.joints = {}
      if skin.skeleton then
        node.skeleton_node = create_nodes(builder, loader.nodes, skin.skeleton + 1)
      end

      local matrices = skin.inverse_bind_matrices
      for i, joint in ipairs(skin.joints) do
        local joint_node = create_nodes(builder, loader.nodes, joint + 1)
        joint_node.inverse_bind_matrix = mat4(matrices[i])
        node.joints[i] = joint_node
      end
    end
  end

  builder.animations = {}
  for i, v in ipairs(loader.animations) do
    local animation = { name = v.name, channels = {} }
    for j, channel in ipairs(v.channels) do
      animation.channels[j] = {
        target_node = builder.nodes[channel.target_node + 1],
        target_path = channel.target_path,
        sampler = channel.sampler,
      }
    end
    table.insert(builder.animations, animation)
  end

  ---@type Node[]
  local scenes = {}
  for i, v in ipairs(loader.scenes) do
    local scene_node = Node(v.name)
    for _, inode in ipairs(v.nodes) do
      scene_node:attach(builder.nodes[inode + 1])
    end
    scene_node:traverse(update_transform_callback)
    if callback then
      callback(scene_node, builder)
    end
    scenes[i] = scene_node
  end

  return scenes
end

return NodeTreeBuilder
