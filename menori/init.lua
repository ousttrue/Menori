--[[
-------------------------------------------------------------------------------
      Menori
      LÖVE library for simple 3D and 2D rendering based on scene graph.
      @author rozenmad
      2023
-------------------------------------------------------------------------------
--]]

local modules = (...) and (...):gsub('%.init$', '') .. ".modules." or ""

--- Namespace for all modules in library.
local menori = {
      ---@type fun(...): PerspectiveCamera
      PerspectiveCamera = require(modules .. 'core3d.camera'),
      ---@type fun(...): Environment
      Environment       = require(modules .. 'core3d.environment'),
      ---@type fun(...): UniformList
      UniformList       = require(modules .. 'core3d.uniform_list'),

      glTFAnimations    = require(modules .. 'core3d.gltf_animations'),
      ---@class glTFLoader
      glTFLoader        = require(modules .. 'core3d.gltf'),
      Material          = require(modules .. 'core3d.material'),
      BoxShape          = require(modules .. 'core3d.boxshape'),
      Mesh              = require(modules .. 'core3d.mesh'),
      ModelNode         = require(modules .. 'core3d.model_node'),
      NodeTreeBuilder   = require(modules .. 'core3d.node_tree_builder'),
      GeometryBuffer    = require(modules .. 'core3d.geometry_buffer'),
      InstancedMesh     = require(modules .. 'core3d.instanced_mesh'),
      ---@type fun(...): Camera
      Camera            = require(modules .. 'camera'),
      ---@type fun(...): Node
      Node              = require(modules .. 'node'),
      ---@type fun(...): Scene
      Scene             = require(modules .. 'scene'),
      Sprite            = require(modules .. 'sprite'),
      SpriteLoader      = require(modules .. 'spriteloader'),

      ShaderUtils       = require(modules .. 'shaders.utils'),

      ---@type App
      app               = require(modules .. 'app'),
      utils             = require(modules .. 'libs.utils'),
      class             = require(modules .. 'libs.class'),
      ml                = require(modules .. 'ml'),

      ---@deprecated
      Application       = require(modules .. 'deprecated.application'),
      ---@deprecated
      ModelNodeTree     = require(modules .. 'deprecated.model_node_tree'),
}

return menori
