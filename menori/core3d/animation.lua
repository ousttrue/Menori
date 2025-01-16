---@class menori.Animation
local Animation = {}
Animation.__index = Animation

---@param data menori.GltfData
---@param animation any
---@return table
local function read_animation(data, animation)
    local samplers = {}
    for _, v in ipairs(animation.samplers) do
        local time_buffer = data:get_buffer(v.input)
        local data_buffer = data:get_buffer(v.output)
        table.insert(samplers, {
            time_array = time_buffer:get_data_array(),
            data_array = data_buffer:get_data_array(),
            interpolation = v.interpolation,
        })
    end

    local channels = {}
    for _, v in ipairs(animation.channels) do
        table.insert(channels, {
            sampler = samplers[v.sampler + 1],
            target_node = v.target.node,
            target_path = v.target.path,
        })
    end

    return channels
end

---@param data menori.GltfData
---@return menori.Animation[]
function Animation.load(data, nodes)
    local animations = {}
    if data.gltf.animations then
        for i, animation in ipairs(data.gltf.animations) do
            animations[i] = {
                channels = read_animation(data, animation),
                name = animation.name,
            }
        end
    end
    for i, v in ipairs(animations) do
        local animation = { name = v.name, channels = {} }
        for j, channel in ipairs(v.channels) do
            animation.channels[j] = {
                target_node = nodes[channel.target_node + 1],
                target_path = channel.target_path,
                sampler = channel.sampler,
            }
        end
        animations[i] = animation
    end
    return animations
end

return Animation
