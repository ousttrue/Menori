local features = love.graphics.getSupported()

---@type table<string, string>
local chunks = {}

---@param dir string
---@param name string
local function add_shader_chunk(dir, name)
	chunks[name] = love.filesystem.read(dir .. "/" .. name)
end

add_shader_chunk("menori/shaders/chunks", "skinning_vertex_base.glsl")
add_shader_chunk("menori/shaders/chunks", "skinning_vertex.glsl")
add_shader_chunk("menori/shaders/chunks", "normal.glsl")
add_shader_chunk("menori/shaders/chunks", "billboard_base.glsl")
add_shader_chunk("menori/shaders/chunks", "billboard.glsl")
add_shader_chunk("menori/shaders/chunks", "inverse.glsl")
add_shader_chunk("menori/shaders/chunks", "transpose.glsl")

local cache = {}

local function include_chunks(code)
	local lines = {}
	for line in string.gmatch(code .. "\n", "(.-)\n") do
		local temp = line:gsub("^[ \t]*#menori_include <(.-)>", function(name)
			assert(chunks[name] ~= nil, name)
			return chunks[name]
		end)
		table.insert(lines, temp)
	end
	return table.concat(lines, "\n")
end

---@param name string
---@param shaderpath string
---@param opt table?
local function load_shader_file(name, shaderpath, opt)
	local code = love.filesystem.read(shaderpath)
	assert(code)

	if opt and opt.definitions then
		local t = {}
		for _, v in ipairs(opt.definitions) do
			table.insert(t, string.format("#define %s\n", v))
		end
		if #t > 0 then
			local s = table.concat(t) .. "\n"
			code = s .. code
		end
	end

	if features["glsl3"] then
		code = "#pragma language glsl3\n" .. code
	end

	cache[name] = include_chunks(code)
end

local USE_SKINNING = {
	definitions = { "USE_SKINNING" },
}
local BILLBOARD_ROTATE = {
	definitions = { "BILLBOARD_ROTATE" },
}

load_shader_file("default_mesh_vert", "menori/shaders/default_mesh_vert.glsl")
load_shader_file("default_mesh_frag", "menori/shaders/default_mesh_frag.glsl")

load_shader_file("default_mesh_skinning_vert", "menori/shaders/default_mesh_vert.glsl", USE_SKINNING)
load_shader_file("default_mesh_skinning_frag", "menori/shaders/default_mesh_frag.glsl", USE_SKINNING)

load_shader_file("deferred_mesh_frag", "menori/shaders/deferred_mesh_frag.glsl")

load_shader_file("deferred_mesh_skinning_vert", "menori/shaders/default_mesh_vert.glsl", USE_SKINNING)
load_shader_file("deferred_mesh_skinning_frag", "menori/shaders/default_mesh_frag.glsl", USE_SKINNING)

load_shader_file("instanced_mesh_vert", "menori/shaders/instanced_mesh_vert.glsl")

load_shader_file("instanced_mesh_billboard_vert", "menori/shaders/instanced_mesh_vert.glsl", BILLBOARD_ROTATE)
load_shader_file("instanced_mesh_billboard_frag", "menori/shaders/default_mesh_frag.glsl", BILLBOARD_ROTATE)

load_shader_file("outline_mesh_vert", "menori/shaders/outline_mesh_vert.glsl")
load_shader_file("outline_mesh_frag", "menori/shaders/outline_mesh_frag.glsl")

local shaders = {
	default_mesh = love.graphics.newShader(cache["default_mesh_vert"], cache["default_mesh_frag"]),
	default_mesh_skinning = love.graphics.newShader(
		cache["default_mesh_skinning_vert"],
		cache["default_mesh_skinning_frag"]
	),
	deferred_mesh = love.graphics.newShader(cache["default_mesh_vert"], cache["deferred_mesh_frag"]),
	deferred_mesh_skinning = love.graphics.newShader(
		cache["deferred_mesh_skinning_vert"],
		cache["deferred_mesh_skinning_frag"]
	),

	instanced_mesh = love.graphics.newShader(cache["instanced_mesh_vert"], cache["default_mesh_frag"]),
	instanced_mesh_billboard = love.graphics.newShader(
		cache["instanced_mesh_billboard_vert"],
		cache["default_mesh_frag"]
	),

	outline_mesh = love.graphics.newShader(cache["outline_mesh_vert"], cache["outline_mesh_frag"]),
}

return {
	cache = cache,
	shaders = shaders,
}
