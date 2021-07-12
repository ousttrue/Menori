--[[
-------------------------------------------------------------------------------
	Menori
	@author rozenmad
	2021
-------------------------------------------------------------------------------
	this module based on CPML - Cirno's Perfect Math Library
--]]

local modules = (...):gsub('%.[^%.]+$', '') .. "."
local vec3 = require(modules .. "vec3")
local mat4 = require(modules .. "mat4")

local DOT_THRESHOLD = 0.9995
local DBL_EPSILON = 2.2204460492503131e-16
local sqrt = math.sqrt
local acos = math.acos
local cos  = math.cos
local sin  = math.sin
local min  = math.min
local max  = math.max

local quat = {}
local quat_mt = {}
quat_mt.__index = quat_mt

local function new(x, y, z, w)
	return setmetatable({
		x = x or 0,
		y = y or 0,
		z = z or 0,
		w = w or 1,
	}, quat_mt)
end

local temp_q = new()
local temp_v = vec3()

quat.unit = new(0, 0, 0, 1)
quat.zero = new(0, 0, 0, 0)

function quat_mt:clone()
    	return new(self.x, self.y, self.z, self.w)
end

function quat_mt:set(x, y, z, w)
	if type(x) == 'table' then
		x, y, z, w = x.x, x.y, x.z, x.w
	end
	self.x = x
	self.y = y
	self.z = z
	self.w = w
	return self
end

function quat_mt:add(other)
	self.x = self.x + other.x
	self.y = self.y + other.y
	self.z = self.z + other.z
	self.w = self.w + other.w
	return self
end

function quat_mt:sub(other)
	self.x = self.x - other.x
	self.y = self.y - other.y
	self.z = self.z - other.z
	self.w = self.w - other.w
	return self
end

function quat_mt:mul(other)
	temp_q.x = self.x * other.w + self.w * other.x + self.y * other.z - self.z * other.y
	temp_q.y = self.y * other.w + self.w * other.y + self.z * other.x - self.x * other.z
	temp_q.z = self.z * other.w + self.w * other.z + self.x * other.y - self.y * other.x
	temp_q.w = self.w * other.w - self.x * other.x - self.y * other.y - self.z * other.z
	self.x = temp_q.x
	self.y = temp_q.y
	self.z = temp_q.z
	self.w = temp_q.w
	return self
end

-- http://www.euclideanspace.com/maths/geometry/rotations/conversions/matrixToQuaternion/index.htm
function quat_mt:set_from_matrix_rotation(m)
	local e = m.e
	local m11, m12, m13 = e[1], e[5], e[ 9]
	local m21, m22, m23 = e[2], e[6], e[10]
	local m31, m32, m33 = e[3], e[7], e[11]

	local tr = m11 + m22 + m33

	if
	tr > 0 then
		local s = 0.5 / math.sqrt(tr + 1)

		self.w = 0.25 / s
		self.x = (m32 - m23) * s
		self.y = (m13 - m31) * s
		self.z = (m21 - m12) * s
	elseif
	m11 > m22 and m11 > m33 then
		local s = 2 * math.sqrt(1 + m11 - m22 - m33)

		self.w = (m32 - m23) / s
		self.x = 0.25 * s
		self.y = (m12 + m21) / s
		self.z = (m13 + m31) / s

	elseif
	m22 > m33 then
		local s = 2 * math.sqrt(1 + m22 - m11 - m33)

		self.w = (m13 - m31) / s
		self.x = (m12 + m21) / s
		self.y = 0.25 * s
		self.z = (m23 + m32) / s
	else
		local s = 2 * math.sqrt(1 + m33 - m11 - m22)

		self.w = (m21 - m12) / s
		self.x = (m13 + m31) / s
		self.y = (m23 + m32) / s
		self.z = 0.25 * s
	end
	return self
end

function quat_mt:multiply_vec3(v3)
	temp_v.x = self.x
	temp_v.y = self.y
	temp_v.z = self.z
	local v1 = vec3.cross(temp_v, v3)
	local v2 = vec3.cross(temp_v, v1)
	return v3 + ((v1 * self.w) + v2) * 2
end

function quat_mt:scale(s)
	self.x = self.x * s
	self.y = self.y * s
	self.z = self.z * s
	self.w = self.w * s
	return self
end

function quat_mt:pow(s)
	if self.w < 0 then
		self:scale(-1)
	end
	local dot = self.w

	dot = min(max(dot, -1), 1)

	local theta = acos(dot) * s
	local c = new(self.x, self.y, self.z, 0):normalize() * sin(theta)
	c.w = cos(theta)
	return c
end

function quat_mt:conjugate()
	self.x = -self.x
	self.y = -self.y
	self.z = -self.z
	return self
end

function quat_mt:inverse()
	temp_q.x = -self.x
	temp_q.y = -self.y
	temp_q.z = -self.z
	temp_q.w =  self.w
	return temp_q:clone():normalize()
end

function quat_mt:normalize()
	if self:is_zero() then
		return new(0, 0, 0, 0)
	end
	return self:scale(1 / self:length())
end

function quat_mt:reciprocal()
	if self:is_zero() then
		error("Cannot reciprocate a zero quaternion")
		return false
	end

	temp_q.x = -self.x
	temp_q.y = -self.y
	temp_q.z = -self.z
	temp_q.w =  self.w

	temp_q:scale(1 / self:length2())
	self.x = temp_q.x
	self.y = temp_q.y
	self.z = temp_q.z
	self.w = temp_q.w
	return self
end

function quat_mt:length()
	return sqrt(self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w)
end
function quat_mt:length2()
	return self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w
end

function quat_mt:unpack(a)
	return a.x, a.y, a.z, a.w
end

function quat_mt:is_zero()
	return
		self.x == 0 and
		self.y == 0 and
		self.z == 0 and
		self.w == 0
end

function quat_mt:is_real()
	return
		self.x == 0 and
		self.y == 0 and
		self.z == 0
end

function quat_mt:is_imaginary()
	return self.w == 0
end

function quat_mt:to_angle_axis_unpack(identity_axis)
	local a = self
	if a.w > 1 or a.w < -1 then
		a = self:clone():normalize()
	end

	if a.x*a.x + a.y*a.y + a.z*a.z < DBL_EPSILON*DBL_EPSILON then
		if identity_axis then
			return 0, identity_axis:unpack()
		else
			return 0, 0, 0, 1
		end
	end

	local x, y, z
	local angle = 2 * acos(a.w)
	local s = sqrt(1 - a.w * a.w)

	if s < DBL_EPSILON then
		x = a.x
		y = a.y
		z = a.z
	else
		x = a.x / s
		y = a.y / s
		z = a.z / s
	end

	return angle, x, y, z
end

function quat_mt:to_angle_axis(identityAxis)
	local angle, x, y, z = self:to_angle_axis_unpack(identityAxis)
	return angle, vec3(x, y, z)
end

local function clamp( value, _min, _max )
	return math.max( _min, math.min( _max, value ) )
end

function quat_mt:to_euler(order)
	order = order or 'XYZ'
      local m = mat4():rotate(self)
	local e = m.e
	local m11, m12, m13 = e[1], e[5], e[ 9]
	local m21, m22, m23 = e[2], e[6], e[10]
	local m31, m32, m33 = e[3], e[7], e[11]

	local x, y, z
	if
	order == 'XYZ' then
		y = math.asin( clamp( m13, -1, 1 ) )

		if math.abs( m13 ) < 0.9999999 then
			x = math.atan2( - m23, m33 )
			z = math.atan2( - m12, m11 )
		else
			x = math.atan2( m32, m22 )
			z = 0
		end
	elseif
	order == 'YXZ' then
		x = math.asin(-clamp( m23, - 1, 1 ) )

		if math.abs( m23 ) < 0.9999999 then
			y = math.atan2( m13, m33 )
			z = math.atan2( m21, m22 )
		else
			y = math.atan2( - m31, m11 )
			z = 0
		end
	elseif
	order == 'ZXY' then
		x = math.asin( clamp( m32, - 1, 1 ) )

		if math.abs( m32 ) < 0.9999999 then
			y = math.atan2( - m31, m33 )
			z = math.atan2( - m12, m22 )
		else
			y = 0
			z = math.atan2( m21, m11 )
		end
	elseif
	order == 'ZYX' then
		y = math.asin(-clamp( m31, - 1, 1 ) )

		if math.abs( m31 ) < 0.9999999 then
			x = math.atan2( m32, m33 )
			z = math.atan2( m21, m11 )
		else
			x = 0
			z = math.atan2( - m12, m22 )
		end
	elseif
	order == 'YZX' then
		z = math.asin( clamp( m21, - 1, 1 ) )

		if math.abs( m21 ) < 0.9999999 then
			x = math.atan2( - m23, m22 )
			y = math.atan2( - m31, m11 )
		else
			x = 0
			y = math.atan2( m13, m33 )
		end
	elseif
	order == 'XZY' then
		z = math.asin(-clamp( m12, - 1, 1 ) )

		if math.abs( m12 ) < 0.9999999 then
			x = math.atan2( m32, m22 )
			y = math.atan2( m13, m11 )
		else
			x = math.atan2( - m23, m33 )
			y = 0
		end
	end
	return x, y, z
end

function quat_mt.__tostring(a)
	return string.format("(%+0.3f,%+0.3f,%+0.3f,%+0.3f)", a.x, a.y, a.z, a.w)
end

function quat_mt.__unm(a)
	return a:clone():scale(-1)
end

function quat_mt.__eq(a, b)
	if not quat.is_quat(a) or not quat.is_quat(b) then
		return false
	end
	return a.x == b.x and a.y == b.y and a.z == b.z and a.w == b.w
end

function quat_mt.__add(a, b)
	assert(quat.is_quat(a), "__add: Wrong type for a argument. (<quat> expected)")
	assert(quat.is_quat(b), "__add: Wrong type for b argument. (<quat> expected)")
	return a:add(b)
end

function quat_mt.__sub(a, b)
	assert(quat.is_quat(a), "__sub: Wrong type for a argument. (<quat> expected)")
	assert(quat.is_quat(b), "__sub: Wrong type for b argument. (<quat> expected)")
	return a:sub(b)
end

function quat_mt.__mul(a, b)
	assert(quat.is_quat(a), "__mul: Wrong type for a argument. (<quat> expected)")
	assert(quat.is_quat(b) or vec3.is_vec3(b) or type(b) == "number", "__mul: Wrong type for b argument. (<quat> or <vec3> or <number> expected)")

	if quat.is_quat(b) then
		return a:clone():mul(b)
	end

	if type(b) == "number" then
		return a:clone():scale(b)
	end

	return a:multiply_vec3(b)
end

function quat_mt.__pow(a, n)
	assert(quat.is_quat(a), "__pow: Wrong type for a argument. (<quat> expected)")
	assert(type(n) == "number", "__pow: Wrong type for b argument. (<number> expected)")
	return a:clone():pow(n)
end

-- quat --

function quat.from_euler_angles(y, p, r)
	local cy = cos(y * 0.5)
	local sy = sin(y * 0.5)
	local cp = cos(p * 0.5)
	local sp = sin(p * 0.5)
	local cr = cos(r * 0.5)
	local sr = sin(r * 0.5)

	local q = new()
	q.w = cr * cp * cy + sr * sp * sy
	q.x = sr * cp * cy - cr * sp * sy
	q.y = cr * sp * cy + sr * cp * sy
	q.z = cr * cp * sy - sr * sp * cy
	return q
end

function quat.from_angle_axis(angle, axis, a3, a4)
	if axis and a3 and a4 then
		local x, y, z = axis, a3, a4
		local s = sin(angle * 0.5)
		local c = cos(angle * 0.5)
		return new(x * s, y * s, z * s, c)
	else
		return quat.from_angle_axis(angle, axis.x, axis.y, axis.z)
	end
end

function quat.from_direction(normal, up)
	local u = up or vec3.unit_z
	local n = normal:clone():normalize()
	local a = vec3.cross(u, n)
	local d = vec3.dot(u, n)
	return new(a.x, a.y, a.z, d + 1)
end

function quat.dot(a, b)
	return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w
end

function quat.lerp(a, b, s)
	return (a + (b - a) * s):clone():normalize()
end

function quat.slerp(a, b, s)
	local dot = quat.dot(a, b)

	if dot < 0 then
		a   = -a
		dot = -dot
	end

	if dot > DOT_THRESHOLD then
		return quat.lerp(a, b, s)
	end

	dot = min(max(dot, -1), 1)

	local theta = acos(dot) * s
	local c = (b - a * dot):normalize()
	return a * cos(theta) + c * sin(theta)
end

function quat.is_quat(a)
	return
		type(a)   == "table"  and
		type(a.x) == "number" and
		type(a.y) == "number" and
		type(a.z) == "number" and
		type(a.w) == "number"
end

return setmetatable(quat, { __call = function(_, x, y, z, w)
	if type(x) == 'table' then
		local xx, yy, zz, ww = x.x or x[1], x.y or x[2], x.z or x[3], x.w or x[4]
		return new(xx, yy, zz, ww)
	end
	return new(x, y, z, w)
end })