--[[
-------------------------------------------------------------------------------
	Menori
	@author rozenmad
	2021
-------------------------------------------------------------------------------
--]]

--[[--
Description.
]]
-- @module menori.SpriteLoader

local json = require 'libs.rxijson.json'

local modules     = (...):gsub('%.[^%.]+$', '') .. "."
local Sprite      = require(modules .. 'sprite')

local spriteloader = {}
local list = setmetatable({}, {__mode = 'v'})

local function load_aseprite_sprite_sheet(path, name)
	local filename = path .. name
	print(filename)
	local data = json.decode(love.filesystem.read(filename .. '.json'))
	local meta = data.meta

	local image = love.graphics.newImage(path .. meta.image)
	image:setFilter('nearest', 'nearest')

	local iw, ih = image:getDimensions()

	local frames
	if #data.frames <= 0 then -- if hash type
		frames = {}
		for _, v in pairs(data.frames) do
			frames[#frames + 1] = v
		end
	else
		frames = data.frames
	end

	local spritesheet = {}

	for _, slice in ipairs(meta.slices) do
		local quads = {}
		for i, key in ipairs(slice.keys) do
			local bounds = key.bounds

			local frame = frames[i].frame
			local ox = frame.x
			local oy = frame.y
			quads[i] = love.graphics.newQuad(ox+bounds.x, oy+bounds.y, bounds.w, bounds.h, iw, ih)
		end

		spritesheet[slice.name] = Sprite(quads, image, slice.pivot)
	end

	return spritesheet
end

--- Create a tileset from an image.
-- @param image [Image](https://love2d.org/wiki/Image)
-- @tparam number offsetx
-- @tparam number offsety
-- @tparam number w
-- @tparam number h
-- @treturn table List of [Quad](https://love2d.org/wiki/Quad) objects
function spriteloader.create_tileset_from_image(image, offsetx, offsety, w, h)
	local image_w, image_h = image:getDimensions()
	local quads = {}
	local iws = math.floor((image_w - offsetx) / w)
	local ihs = math.floor((image_h - offsety) / h)
	for j = 0, ihs - 1 do
		for i = 0, iws - 1 do
			local px = i * w
			local py = j * h
			quads[#quads + 1] = love.graphics.newQuad(px, py, w, h, image_w, image_h)
		end
	end
	return quads
end

--- Create sprite from image.
-- @param image [Image](https://love2d.org/wiki/Image)
-- @return New sprite
function spriteloader.from_image(image)
	local w, h = image:getDimensions()
	return Sprite({love.graphics.newQuad(0, 0, w, h, w, h)}, image)
end

--- Create sprite from tileset image.
-- @param image [Image](https://love2d.org/wiki/Image)
-- @tparam number offsetx
-- @tparam number offsety
-- @tparam number w
-- @tparam number h
-- @return Sprite object
function spriteloader.from_tileset_image(image, offsetx, offsety, w, h)
	return Sprite(spriteloader.create_tileset_from_image(image, offsetx, offsety, w, h), image)
end

--- Load sprite from Aseprite Sprite Sheet using sprite cache list.
-- @tparam string path
-- @tparam string name
-- @return Sprite object
function spriteloader.from_aseprite_sprite_sheet(path, name)
	if not list[name] then list[name] = load_aseprite_sprite_sheet(path, name) end
	return list[name]
end

--- Find Aseprite Sprite Sheet in cache list.
-- @tparam string name
-- @return Sprite object
function spriteloader.find_sprite_sheet(name)
	return list[name]
end

return
spriteloader