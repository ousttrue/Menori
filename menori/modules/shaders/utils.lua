local modules = (...):match "(.*%menori.modules.shaders.)"

---@param path string
---@param name string
---@return string
local function readfile(path, name)
  path = path:gsub("%.", "/")
  return love.filesystem.read(path .. name .. ".glsl")
end

---@type {[string]: string}
local chunks = {}
---@param path string
---@param name string
local function add_shader_chunk(path, name)
  chunks[name .. ".glsl"] = readfile(path, name)
end

if love._version_major > 11 then
  add_shader_chunk(modules .. "chunks.", "skinning_vertex_base")
  add_shader_chunk(modules .. "chunks.", "skinning_vertex")
else
  add_shader_chunk(modules .. "chunks.love11.", "skinning_vertex_base")
  add_shader_chunk(modules .. "chunks.love11.", "skinning_vertex")
end

add_shader_chunk(modules .. "chunks.", "normal")
add_shader_chunk(modules .. "chunks.", "billboard_base")
add_shader_chunk(modules .. "chunks.", "billboard")

---@type {[string]: string}
local cache = {}

---@param code string
---@return string
local function include_chunks(code)
  return code:gsub(
    "#include <(.-)>",
    ---@param name string
    ---@return string
    function(name)
      assert(chunks[name] ~= nil, name)
      return chunks[name]
    end
  )
end

---@param name string
---@param path string
---@param vert string
---@param frag string
---@param opt {defines: table?}?
local function load_shader_file(name, path, vert, frag, opt)
  local codevert = readfile(path, vert)
  local codefrag = readfile(path, frag)
  if opt and opt.defines then
    for k, v in pairs(opt.defines) do
      codevert = string.format("#define %s\n", v) .. codevert
      codefrag = string.format("#define %s\n", v) .. codefrag
    end
  end
  codevert = "#pragma language glsl3\n" .. codevert
  codefrag = "#pragma language glsl3\n" .. codefrag

  cache[name .. "_vert"] = include_chunks(codevert)
  cache[name .. "_frag"] = include_chunks(codefrag)
end

load_shader_file("default_mesh", modules, "default_mesh_vert", "default_mesh_frag")
load_shader_file(
  "default_mesh_skinning",
  modules,
  "default_mesh_vert",
  "default_mesh_frag",
  { defines = { "USE_SKINNING" } }
)

load_shader_file("deferred_mesh", modules, "default_mesh_vert", "deferred_mesh_frag")
load_shader_file(
  "deferred_mesh_skinning",
  modules,
  "default_mesh_vert",
  "deferred_mesh_frag",
  { defines = { "USE_SKINNING" } }
)

load_shader_file("instanced_mesh", modules, "instanced_mesh_vert", "deferred_mesh_frag")
load_shader_file(
  "instanced_mesh_billboard",
  modules,
  "instanced_mesh_vert",
  "deferred_mesh_frag",
  { defines = { "BILLBOARD_ROTATE" } }
)

load_shader_file("outline_mesh", modules, "outline_mesh_vert", "outline_mesh_frag")

---@type love.Shader[]
local shaders = {
  default_mesh = love.graphics.newShader(cache["default_mesh_vert"], cache["default_mesh_frag"]),
  default_mesh_skinning = love.graphics.newShader(
    cache["default_mesh_skinning_vert"],
    cache["default_mesh_skinning_frag"]
  ),
  deferred_mesh = love.graphics.newShader(cache["deferred_mesh_vert"], cache["deferred_mesh_frag"]),
  deferred_mesh_skinning = love.graphics.newShader(
    cache["deferred_mesh_skinning_vert"],
    cache["deferred_mesh_skinning_frag"]
  ),

  instanced_mesh = love.graphics.newShader(cache["instanced_mesh_vert"], cache["deferred_mesh_frag"]),
  instanced_mesh_billboard = love.graphics.newShader(
    cache["instanced_mesh_billboard_vert"],
    cache["deferred_mesh_frag"]
  ),

  outline_mesh = love.graphics.newShader(cache["outline_mesh_vert"], cache["outline_mesh_frag"]),
}

---@class ShaderUtils
local shaderutils = {
  cache = cache,
  ---@type fun(path: string, name: string)
  add_shader_chunk = add_shader_chunk,
  ---@type fun(name: string, path: string, vert: string, frag: string, opts: table?)
  load_shader_file = load_shader_file,
  shaders = shaders,
}

return shaderutils
