--[[
-------------------------------------------------------------------------------
      Menori
      @author rozenmad
      2022
-------------------------------------------------------------------------------
]]

--[[--
Base class of scenes.
It contains methods for recursively drawing and updating nodes.
You need to inherit from the Scene class to create your own scene object.
]]
--- @classmod Scene

local node_stack_t = {}

local temp_renderstates = { clear = false }

local function layer_comp(a, b)
	return a.layer < b.layer
end

local priorities = { OPAQUE = 0, MASK = 1, BLEND = 2 }
local function alpha_mode_comp(a, b)
	return priorities[a.material.alpha_mode] < priorities[b.material.alpha_mode]
end

local function default_filter(node, scene, environment)
	node:render(scene, environment)
end

---@class menori.Scene
---@field list_drawable_nodes table
---@field transparent_flag boolean
local Scene = {
	alpha_mode_comp = alpha_mode_comp,
	layer_comp = layer_comp,
}
Scene.__index = Scene

---@return menori.Scene
function Scene.new()
	local self = setmetatable({}, Scene)
	self.list_drawable_nodes = {}
	self.transparent_flag = false
	return self
end

--- Node render function.
-- @tparam menori.Node node
-- @tparam menori.Environment environment
-- @tparam[opt] table renderstates
-- @tparam[opt] function filter The callback function.
-- @usage renderstates = { canvas, ..., clear = true, colors = {color, ...} }
-- @usage function default_filter(node, scene, environment) node:render(scene, environment) end
function Scene:render_nodes(node, environment, renderstates, filter)
	assert(node, "in function 'Scene:render_nodes' node does not exist.")

	love.graphics.push("all")

	environment._shader_object_cache = nil
	renderstates = renderstates or temp_renderstates
	filter = filter or default_filter

	table.insert(node_stack_t, node)
	while #node_stack_t > 0 do
		local n = table.remove(node_stack_t)
		if n.render_flag then
			local need_transform = n._transform_flag
			if need_transform then
				n:update_transform()
			end

			if n.render then
				table.insert(self.list_drawable_nodes, n)
			end

			if need_transform then
				for _, v in ipairs(n.children) do
					v._transform_flag = true
					table.insert(node_stack_t, v)
				end
			else
				for _, v in ipairs(n.children) do
					table.insert(node_stack_t, v)
				end
			end
		end
	end

	table.sort(self.list_drawable_nodes, renderstates.node_sort_comp or layer_comp)

	local camera = environment.camera
	if camera._camera_2d_mode then
		camera:_apply_transform()
	end

	local canvases = #renderstates > 0

	if canvases then
		love.graphics.setCanvas(renderstates)
	end

	if renderstates.clear then
		if renderstates.colors then
			love.graphics.clear(unpack(renderstates.colors))
		else
			love.graphics.clear()
		end
	end

	for _, v in ipairs(self.list_drawable_nodes) do
		filter(v, self, environment)
	end
	love.graphics.pop()

	local count = #self.list_drawable_nodes
	self.list_drawable_nodes = {}

	return count
end

--- Node update function.
--@tparam Node node
--@tparam Environment environment
function Scene:update_nodes(node, environment)
	assert(node, "in function 'Scene:update_nodes' node does not exist.")

	table.insert(node_stack_t, node)
	while #node_stack_t > 0 do
		local n = table.remove(node_stack_t)
		if n.update_flag then
			if n.update then
				n:update(self, environment)
			end

			local i = 1
			local children = n.children
			while i <= #children do
				local child = children[i]
				if child.detach_flag then
					table.remove(children, i)
				else
					table.insert(node_stack_t, child)
					i = i + 1
				end
			end
		end
	end
end

function Scene:render() end

function Scene:update() end

function Scene:on_enter() end

function Scene:on_leave() end

return Scene
