--[[
-------------------------------------------------------------------------------
      Menori
      LÖVE library for simple 3D and 2D rendering based on scene graph.
      @author rozenmad
      2024
-------------------------------------------------------------------------------
--]]
----
-- @module menori

--- Namespace for all modules in library.
-- @table menori
local menori = {
  PerspectiveCamera = require "menori.core3d.camera",
  Environment = require "menori.core3d.environment",
  UniformList = require "menori.core3d.uniform_list",
  glTFAnimations = require "menori.core3d.gltf_animations",
  glTFLoader = require "menori.core3d.gltf",
  Material = require "menori.core3d.material",
  BoxShape = require "menori.core3d.boxshape",
  Mesh = require "menori.core3d.mesh",
  ModelNode = require "menori.core3d.model_node",
  NodeTreeBuilder = require "menori.core3d.node_tree_builder",
  InstancedMesh = require "menori.core3d.instanced_mesh",
  Camera = require "menori.camera",
  Node = require "menori.node",
  Scene = require "menori.scene",
  SceneManager = require "menori.scenemanager",
  Sprite = require "menori.sprite",
  SpriteLoader = require "menori.spriteloader",

  ShaderUtils = require "menori.shaders.utils",

  utils = require "menori.libs.utils",
  class = require "menori.libs.class",
  ml = require "menori.ml",

  ---@deprecated
  GeometryBuffer = require "menori.deprecated.geometry_buffer",
}

return menori
