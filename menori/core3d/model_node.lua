--[[
-------------------------------------------------------------------------------
	Menori
	@author rozenmad
	2022
-------------------------------------------------------------------------------
]]

--[[--
Class for drawing Mesh objects. (Inherited from menori.Node class)
]]
-- @classmod ModelNode
-- @see Node

local Node = require("menori.node")
local ml = require("menori.ml")
local Material = require("menori.core3d.material")
local ffi = require("menori.libs.ffi")

local vec3 = ml.vec3
local bound3 = ml.bound3

---@class menori.ModelNode
local ModelNode = {}
ModelNode.__index = ModelNode
setmetatable(ModelNode, Node)

local matrix_bytesize = 16 * 4
local data
local joints_texture

--- The public constructor.
-- @tparam menori.Mesh mesh object
-- @tparam[opt=Material.default] menori.Material material object. (A new copy will be created for the material)
---@return menori.ModelNode
function ModelNode.new(mesh, material)
    local self = setmetatable(Node.new(), ModelNode)
    material = material or Material.default
    self.material = material:clone()
    self.mesh = mesh
    self.color = ml.vec4(1)
    return self
end

--- Clone an object.
-- @treturn menori.ModelNode object
function ModelNode:clone()
    local t = ModelNode(self.mesh, self.material)
    ModelNode.super.clone(self, t)
    return t
end

--- Calculate AABB by applying the current transformations.
-- @tparam[opt=1] number index The index of the primitive in the mesh.
-- @treturn menori.ml.bound3 object
function ModelNode:calculate_aabb()
    local bound = self.mesh.bound
    local min = bound.min
    local max = bound.max
    self:recursive_update_transform()
    local m = self.world_matrix
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

function ModelNode:set_color(r, g, b, a)
    self.color:set(r, g, b, a)
end

--- Draw a ModelNode object on the screen.
-- This function will be called implicitly in the hierarchy when a node is drawn with scene:render_nodes()
-- @tparam menori.Scene scene object that is used when drawing the model
-- @tparam menori.Environment environment object that is used when drawing the model
function ModelNode:render(scene, environment)
    local shader = self.material.shader
    environment:apply_shader(shader)
    shader:send("m_model", "column", self.world_matrix.data)

    if self.joints then
        -- if self.skeleton_node then
        --       shader:send('m_skeleton', self.skeleton_node.world_matrix.data)
        -- end

        local size = math.max(math.ceil(math.sqrt(#self.joints * 4) / 4) * 4, 4)
        data = love.data.newByteData(size * size * 4 * 4)

        for i = 1, #self.joints do
            local node = self.joints[i]

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

    local c = self.color
    love.graphics.setColor(c.x, c.y, c.z, c.w)
    self.mesh:draw(self.material)
end

return ModelNode

---
-- Own copy of the Material that is bound to the model.
-- @field material

---
-- The menori.Mesh object that is bound to the model.
-- @field mesh

---
-- Model color. (Deprecated)
-- @field color
