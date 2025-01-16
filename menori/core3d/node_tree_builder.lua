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

---@param value integer
---@return "nearest"|"linear"|"linear"
local function parse_filter(value)
    if value == 9728 then
        return "nearest"
    elseif value == 9729 then
        return "linear"
    else
        return "linear"
    end
end

local function parse_wrap(value)
    if value == 33071 then
        return "clamp"
    elseif value == 33648 then
        return "mirroredrepeat"
    elseif value == 10497 then
        return "repeat"
    else
        return "repeat"
    end
end

---@param texture gltf.Texture
---@return table
function NodeTreeBuilder:load_image(texture)
    local source = texture.source + 1
    local MSFT_texture_dds = texture.extensions and texture.extensions.MSFT_texture_dds
    if MSFT_texture_dds then
        source = MSFT_texture_dds.source + 1
    end

    local image = self.data.gltf.images[source]
    local image_raw_data
    if image.uri then
        local base64data = image.uri:match("^data:image/.*;base64,(.+)")
        if base64data then
            image_raw_data = love.data.decode("data", "base64", base64data)
        else
            local image_filename = path .. image.uri
            image_raw_data = love.filesystem.newFileData(io_read(image_filename), image_filename)
        end
    else
        local buffer_view = self.data.gltf.bufferViews[image.bufferView + 1]

        local data = self.data.buffers[buffer_view.buffer + 1]

        local offset = buffer_view.byteOffset or 0
        local length = buffer_view.byteLength

        image_raw_data = love.data.newDataView(data, offset, length)
    end

    local image_data
    if not MSFT_texture_dds then
        image_data = love.image.newImageData(image_raw_data)
    else
        image_data = love.image.newCompressedData(image_raw_data)
    end

    local image_source
    if love._version_major > 11 then
        image_source = love.graphics.newTexture(image_data, {
            debugname = image.name,
            linear = true,
            mipmaps = true,
        })
    else
        image_source = love.graphics.newImage(image_data)
    end
    image_data:release()
    return {
        source = image_source,
    }
end

local component_types = {
    [5120] = "int8",
    [5121] = "uint8",
    [5122] = "int16",
    [5123] = "unorm16",
    [5125] = "uint32",
    [5126] = "float",
}

local function get_texture(textures, t)
    if t then
        local texture = textures[t.index + 1]
        local ret = {
            texture = texture,
            source = texture.image.source,
        }
        for k, v in pairs(t) do
            if k ~= "index" then
                ret[k] = v
            end
        end
        return ret
    end
end

local function create_material(textures, material)
    local uniforms = {}

    local main_texture
    local pbr = material.pbrMetallicRoughness
    uniforms.baseColor = (pbr and pbr.baseColorFactor) or { 1, 1, 1, 1 }
    if pbr then
        local _pbrBaseColorTexture = pbr.baseColorTexture
        local _pbrMetallicRoughnessTexture = pbr.metallicRoughnessTexture

        main_texture = get_texture(textures, _pbrBaseColorTexture)
        local metallicRoughnessTexture = get_texture(textures, _pbrMetallicRoughnessTexture)

        if main_texture then
            uniforms.mainTexCoord = main_texture.tcoord
        end
        if metallicRoughnessTexture then
            uniforms.metallicRoughnessTexture = metallicRoughnessTexture.source
            uniforms.metallicRoughnessTextureCoord = metallicRoughnessTexture.tcoord
        end

        uniforms.metalness = pbr.metallicFactor
        uniforms.roughness = pbr.roughnessFactor
    end

    if material.normalTexture then
        local normalTexture = get_texture(textures, material.normalTexture)
        uniforms.normalTexture = normalTexture.source
        uniforms.normalTextureCoord = normalTexture.tcoord
        uniforms.normalTextureScale = normalTexture.scale
    end

    if material.occlusionTexture then
        local occlusionTexture = get_texture(textures, material.occlusionTexture)
        uniforms.occlusionTexture = occlusionTexture.source
        uniforms.occlusionTextureCoord = occlusionTexture.tcoord
        uniforms.occlusionTextureStrength = occlusionTexture.strength
    end

    if material.emissiveTexture then
        local emissiveTexture = get_texture(textures, material.emissiveTexture)
        uniforms.emissiveTexture = emissiveTexture.source
        uniforms.emissiveTextureCoord = emissiveTexture.tcoord
    end
    uniforms.emissiveFactor = material.emissiveFactor or { 0, 0, 0 }
    uniforms.opaque = material.alphaMode == "OPAQUE" or not material.alphaMode
    if material.alphaMode == "MASK" then
        uniforms.alphaCutoff = material.alphaCutoff or 0.5
    else
        uniforms.alphaCutoff = 0.0
    end

    return {
        name = material.name,
        main_texture = main_texture,
        uniforms = uniforms,
        double_sided = material.doubleSided,
        alpha_mode = material.alphaMode or "OPAQUE",
    }
end

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

local ffi_indices_types = {
    [5121] = "unsigned char*",
    [5123] = "unsigned short*",
    [5125] = "unsigned int*",
}

local function get_unpack_type(component_type)
    if component_type == 5120 then
        return "b"
    elseif component_type == 5121 then
        return "B"
    elseif component_type == 5122 then
        return "h"
    elseif component_type == 5123 then
        return "H"
    elseif component_type == 5125 then
        return "I4"
    elseif component_type == 5126 then
        return "f"
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

---@param v integer
---@return love.Data|number[]
function NodeTreeBuilder:get_indices_content(v)
    local buffer = self.data:get_buffer(v)
    local element_size = buffer.component_size * buffer.type_elements_count

    local min = buffer.min and buffer.min[1] or 0
    local max = buffer.max and buffer.max[1] or 0

    local uint8 = element_size < 2

    local temp_data
    if ffi and not uint8 then
        temp_data = love.data.newByteData(buffer.count * element_size)
        local temp_data_pointer = ffi.cast("char*", getFFIPointer(temp_data))
        local data = ffi.cast("char*", getFFIPointer(buffer.data)) + buffer.offset

        for i = 0, buffer.count - 1 do
            ffi.copy(temp_data_pointer + i * element_size, data + i * buffer.stride, element_size)
            local value = ffi.cast(ffi_indices_types[buffer.component_type], temp_data_pointer + i * element_size)[0]
            if value > max then
                max = value
            end
            if value < min then
                min = value
            end
        end

        for i = 0, buffer.count - 1 do
            local ptr = ffi.cast(ffi_indices_types[buffer.component_type], temp_data_pointer + i * element_size)
            ptr[0] = ptr[0] - min
        end
    else
        temp_data = {}
        local data_string = buffer.data:getString()
        local unpack_type = get_unpack_type(buffer.component_type)

        for i = 0, buffer.count - 1 do
            local pos = buffer.offset + i * element_size + 1
            local value = love.data.unpack(unpack_type, data_string, pos)
            temp_data[i + 1] = value + 1
            if value > max then
                max = value
            end
            if value < min then
                min = value
            end
        end

        for i = 0, buffer.count - 1 do
            temp_data[i + 1] = temp_data[i + 1] - min
        end
    end
    return temp_data, element_size, min, max
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
            indices, indices_tsize = self:get_indices_content(primitive.indices)
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
    local samplers = {}
    if self.data.gltf.samplers then
        for _, v in ipairs(self.data.gltf.samplers) do
            table.insert(samplers, {
                magFilter = parse_filter(v.magFilter),
                minFilter = parse_filter(v.minFilter),
                wrapS = parse_wrap(v.wrapS),
                wrapT = parse_wrap(v.wrapT),
            })
        end
    end

    local images = {}
    local textures = {}
    if self.data.gltf.textures then
        for _, texture in ipairs(self.data.gltf.textures) do
            local sampler = samplers[texture.sampler + 1]
            local image = images[texture.source + 1]

            if not image then
                image = self:load_image(texture)
                images[texture.source + 1] = image
            end

            table.insert(textures, {
                image = image,
                sampler = sampler,
            })

            if sampler then
                image.source:setFilter(sampler.magFilter, sampler.minFilter)
                image.source:setWrap(sampler.wrapS, sampler.wrapT)
            end
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

    local materials = {}
    if self.data.gltf.materials then
        for i, v in ipairs(self.data.gltf.materials) do
            materials[i] = create_material(textures, v)
        end
    end

    local meshes = {}
    for i, v in ipairs(self.data.gltf.meshes) do
        meshes[i] = self:init_mesh(v)
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

    for i, v in ipairs(meshes) do
        ---@type menori.Mesh[]
        local t = {}
        self.meshes[i] = t
        for j, primitive in ipairs(v.primitives) do
            t[j] = Mesh.new(primitive)
        end
    end

    for i, v in ipairs(materials) do
        local material = Material.new(v.name)
        material.mesh_cull_mode = v.double_sided and "none" or "back"
        material.alpha_mode = v.alpha_mode
        material.alpha_cutoff = v.alpha_cutoff
        if v.main_texture then
            material.main_texture = v.main_texture.source
        end
        for name, uniform in pairs(v.uniforms) do
            material:set(name, uniform)
        end
        self.materials[i] = material
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
end

return NodeTreeBuilder
