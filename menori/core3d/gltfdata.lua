local ffi = require("ffi")

---@class Accessor
---@field data love.Data
---@field offset integer
---@field length integer
---@field stride integer
---@field component_size integer
---@field component_type integer
---@field type string
---@field type_elements_count integer
---@field count integer
---@field min any
---@field max any
local Accessor = {}
Accessor.__index = Accessor

local function getFFIPointer(data)
    if data.getFFIPointer then
        return data:getFFIPointer()
    else
        return data:getPointer()
    end
end

---@return number[]
function Accessor:get_data_array()
    local array = {}
    if ffi then
        for i = 0, self.count - 1 do
            local data_offset = ffi.cast("char*", getFFIPointer(self.data)) + self.offset + i * self.stride
            local ptr = ffi.cast("float*", data_offset)
            if self.type_elements_count > 1 then
                local vector = {}
                for j = 1, self.type_elements_count do
                    local value = ptr[j - 1]
                    table.insert(vector, value)
                end
                table.insert(array, vector)
            else
                table.insert(array, ptr[0])
            end
        end
    else
        for i = 0, self.count - 1 do
            local pos = (self.offset + i * self.stride) + 1
            if self.type_elements_count > 1 then
                local vector = {}
                for j = 0, self.type_elements_count - 1 do
                    local value = love.data.unpack("f", self, pos + j * 4)
                    table.insert(vector, value)
                end
                table.insert(array, vector)
            else
                local value = love.data.unpack("f", self, pos)
                table.insert(array, value)
            end
        end
    end

    return array
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

---@class menori.GltfData
---@field gltf gltf.Root
---@field buffers love.Data[]
local GltfData = {}
GltfData.__index = GltfData

---@param gltf gltf.Root
---@param buffers table[]
---@return menori.GltfData
function GltfData.new(gltf, buffers)
    local self = setmetatable({
        gltf = gltf,
        buffers = buffers,
    }, GltfData)
    return self
end

local component_type_constants = {
    [5120] = 1,
    [5121] = 1,
    [5122] = 2,
    [5123] = 2,
    [5125] = 4,
    [5126] = 4,
}

local type_constants = {
    ["SCALAR"] = 1,
    ["VEC2"] = 2,
    ["VEC3"] = 3,
    ["VEC4"] = 4,
    ["MAT2"] = 4,
    ["MAT3"] = 9,
    ["MAT4"] = 16,
}

---@param accessor_index integer
---@return Accessor
function GltfData:get_buffer(accessor_index)
    local accessor = self.gltf.accessors[accessor_index + 1]
    local buffer_view = self.gltf.bufferViews[accessor.bufferView + 1]
    local offset = buffer_view.byteOffset or 0
    local length = buffer_view.byteLength
    local component_size = component_type_constants[accessor.componentType]
    local type_elements_count = type_constants[accessor.type]
    return setmetatable({
        data = self.buffers[buffer_view.buffer + 1],
        offset = offset + (accessor.byteOffset or 0),
        length = length,
        stride = buffer_view.byteStride or (component_size * type_elements_count),
        component_size = component_size,
        component_type = accessor.componentType,
        type = accessor.type,
        type_elements_count = type_elements_count,
        count = accessor.count,
        min = accessor.min,
        max = accessor.max,
    }, Accessor)
end

---@param v integer
---@return love.Data|number[]
function GltfData:get_indices_content(v)
    local buffer = self:get_buffer(v)
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

---@param texture gltf.Texture
---@return table
function GltfData:load_image(texture)
    local source = texture.source + 1
    local MSFT_texture_dds = texture.extensions and texture.extensions.MSFT_texture_dds
    if MSFT_texture_dds then
        source = MSFT_texture_dds.source + 1
    end

    local image = self.gltf.images[source]
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
        local buffer_view = self.gltf.bufferViews[image.bufferView + 1]

        local data = self.buffers[buffer_view.buffer + 1]

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

return GltfData
