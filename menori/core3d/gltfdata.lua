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
                    local value = love.data.unpack("f", self.data, pos + j * 4)
                    table.insert(vector, value)
                end
                table.insert(array, vector)
            else
                local value = love.data.unpack("f", self.data, pos)
                table.insert(array, value)
            end
        end
    end

    return array
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

return GltfData
