---@alias FilterType "nearest"|"linear"|"linear"
---@alias WrapType "clamp"|"mirroredrepeat"|"repeat"|"repeat"
---@class menori.Texture
---@field magFilter FilterType
---@field minFilter FilterType
---@field wrapS WrapType
---@field wrapT WrapType

local Texture = {}
Texture.__index = Texture

---@param value integer
---@return FilterType
local function parse_filter(value)
    if value == 9728 then
        return "nearest"
    elseif value == 9729 then
        return "linear"
    else
        return "linear"
    end
end

---@return WrapType
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

---@param data menori.GltfData
---@return menori.Texture[]
function Texture.load(data)
    local samplers = {}
    if data.gltf.samplers then
        for _, v in ipairs(data.gltf.samplers) do
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
    if data.gltf.textures then
        for _, texture in ipairs(data.gltf.textures) do
            local sampler = samplers[texture.sampler + 1]
            local image = images[texture.source + 1]

            if not image then
                image = data:load_image(texture)
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

    return textures
end

return Texture
