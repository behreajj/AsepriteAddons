dofile("./vec2.lua")
dofile("./vec3.lua")
dofile("./vec4.lua")
dofile("./mat3.lua")
dofile("./mesh2.lua")
dofile("./quaternion.lua")

Utilities = {}
Utilities.__index = Utilities

setmetatable(Utilities, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

-- Characters occupy an 8x8 grid.
Utilities.GLYPH_LUT = {
    [' '] = 0,
    ['!'] = 1736164113350932496,
    ['"'] = 2893606741050654720,
    ['#'] = 11395512391958528,
    ['$'] = 1169898204994762768,
    ['%'] = 8981488584378098978,
    ['&'] = 4053310240682034232,
    ['\''] = 1731642852816977920,
    ['('] = 2323928052423213088,
    [')'] = 288795533752009220,
    ['*'] = 4596200532606976,
    ['+'] = 4521724658843648,
    [','] = 1574920,
    ['-'] = 532575944704,
    ['.'] = 1579008,
    ['/'] = 289365106780807200,
    
    ['0'] = 1739555093715621888,
    ['1'] = 583224982331988992,
    ['2'] = 4324586061027097600,
    ['3'] = 4036355804662872064,
    ['4'] = 2604246324710999040,
    ['5'] = 4332498283667929088,
    ['6'] = 2026655257813325824,
    ['7'] = 4324585974724038656,
    ['8'] = 1739555042176014336,
    ['9'] = 1739555058816911360,
    [':'] = 26491359860736,
    [';'] = 26491359860744,
    ['<'] = 580999811718711296,
    ['='] = 136341522219008,
    ['>'] = 1155177711124615168,
    ['?'] = 4054440365960200208,
    
    ['@'] = 4342201927465582652,
    ['A'] = 1164255564608586752,
    ['B'] = 8666126866299779072,
    ['C'] = 4341540685485194240,
    ['D'] = 8666126642961479680,
    ['E'] = 4332498266959657984,
    ['F'] = 4332498266959650816,
    ['G'] = 4053310360940460032,
    ['H'] = 4919131993507382272,
    ['I'] = 4039746526926354432,
    ['J'] = 4325716272676876288,
    ['K'] = 4920270967496262656,
    ['L'] = 2314885530818460672,
    ['M'] = -9023337257158671872,
    ['N'] = 4783476233180692992,
    ['O'] = 4342105843085491200,
    
    ['P'] = 8666126866232393728,
    ['Q'] = 4342105843086015496,
    ['R'] = 8666126866501354496,
    ['S'] = 4341540650114906112,
    ['T'] = 8939662921505443840,
    ['U'] = 4919131752989211648,
    ['V'] = 4919131752987365376,
    ['W'] = -7885078839348148224,
    ['X'] = 4919100742855574528,
    ['Y'] = 4919131631854292992,
    ['Z'] = 9097838629918768640,
    ['['] = 8088535575457448048,
    ['\\'] = 2314867869508699140,
    [']'] = 1009371474131288590,
    ['^'] = 1164255270465961984,
    ['_'] = 126,
    
    ['`'] = 2314867869373956096,
    ['a'] = 26405931072512,
    ['b'] = 2314885633965045760,
    ['c'] = 26543437125632,
    ['d'] = 289360794970496000,
    ['e'] = 26543839517696,
    ['f'] = 869212561056206848,
    ['g'] = 1883670230183986232,
    ['h'] = 2314885633965040640,
    ['i'] = 4503806055299072,
    ['j'] = 576469582890936336,
    ['k'] = 2314885565447153664,
    ['l'] = 1157442765409224704,
    ['m'] = 57493678606848,
    ['n'] = 61727876326400,
    ['o'] = 26543504234496,
    
    ['p'] = 1739555179547598848,
    ['q'] = 1883670229782905404,
    ['r'] = 26543436865536,
    ['s'] = 26526120949760,
    ['t'] = 4569639314000896,
    ['u'] = 39737643768832,
    ['v'] = 48550984028160,
    ['w'] = 161158221949952,
    ['x'] = 44152534870016,
    ['y'] = 10172836669032464,
    ['z'] = 30941079675960,
    ['{'] = 1738424915953983512,
    ['|'] = 1157442765409226768,
    ['}'] = 6922050254083723360,
    ['~'] = 3624271800126406656
}

Utilities.LTS_LUT = {
    0, 13, 22, 28, 34, 38, 42, 46, 50, 53, 56, 59, 61, 64, 66, 69,
    71, 73, 75, 77, 79, 81, 83, 85, 86, 88, 90, 92, 93, 95, 96, 98,
    99, 101, 102, 104, 105, 106, 108, 109, 110, 112, 113, 114, 115, 117, 118, 119,
    120, 121, 122, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136,
    137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 148, 149, 150, 151,
    152, 153, 154, 155, 155, 156, 157, 158, 159, 159, 160, 161, 162, 163, 163, 164,
    165, 166, 167, 167, 168, 169, 170, 170, 171, 172, 173, 173, 174, 175, 175, 176,
    177, 178, 178, 179, 180, 180, 181, 182, 182, 183, 184, 185, 185, 186, 187, 187,
    188, 189, 189, 190, 190, 191, 192, 192, 193, 194, 194, 195, 196, 196, 197, 197,
    198, 199, 199, 200, 200, 201, 202, 202, 203, 203, 204, 205, 205, 206, 206, 207,
    208, 208, 209, 209, 210, 210, 211, 212, 212, 213, 213, 214, 214, 215, 215, 216,
    216, 217, 218, 218, 219, 219, 220, 220, 221, 221, 222, 222, 223, 223, 224, 224,
    225, 226, 226, 227, 227, 228, 228, 229, 229, 230, 230, 231, 231, 232, 232, 233,
    233, 234, 234, 235, 235, 236, 236, 237, 237, 238, 238, 238, 239, 239, 240, 240,
    241, 241, 242, 242, 243, 243, 244, 244, 245, 245, 246, 246, 246, 247, 247, 248,
    248, 249, 249, 250, 250, 251, 251, 251, 252, 252, 253, 253, 254, 254, 255, 255 }

Utilities.STL_LUT = {
    0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3,
    4, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 6, 6, 7, 7, 7,
    8, 8, 8, 8, 9, 9, 9, 10, 10, 10, 11, 11, 12, 12, 12, 13,
    13, 13, 14, 14, 15, 15, 16, 16, 17, 17, 17, 18, 18, 19, 19, 20,
    20, 21, 22, 22, 23, 23, 24, 24, 25, 25, 26, 27, 27, 28, 29, 29,
    30, 30, 31, 32, 32, 33, 34, 35, 35, 36, 37, 37, 38, 39, 40, 41,
    41, 42, 43, 44, 45, 45, 46, 47, 48, 49, 50, 51, 51, 52, 53, 54,
    55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70,
    71, 72, 73, 74, 76, 77, 78, 79, 80, 81, 82, 84, 85, 86, 87, 88,
    90, 91, 92, 93, 95, 96, 97, 99, 100, 101, 103, 104, 105, 107, 108, 109,
    111, 112, 114, 115, 116, 118, 119, 121, 122, 124, 125, 127, 128, 130, 131, 133,
    134, 136, 138, 139, 141, 142, 144, 146, 147, 149, 151, 152, 154, 156, 157, 159,
    161, 163, 164, 166, 168, 170, 171, 173, 175, 177, 179, 181, 183, 184, 186, 188,
    190, 192, 194, 196, 198, 200, 202, 204, 206, 208, 210, 212, 214, 216, 218, 220,
    222, 224, 226, 229, 231, 233, 235, 237, 239, 242, 244, 246, 248, 250, 253, 255 }

---Houses utility methods not included in Lua.
---@return table
function Utilities.new()
    local inst = setmetatable({}, Utilities)
    return inst
end

---Forces an overflow wrap to make 64 bit
---integers behave like 32 bit integers.
---@param x number the integer
---@return number
function Utilities.int32Overflow(x)
    -- https://stackoverflow.com/questions/
    -- 300840/force-php-integer-overflow
    local y = x & 0xffffffff
    if y & 0x80000000 then
        return -((~y & 0xffffffff) + 1)
    else
        return y
    end
end

---Unclamped linear interpolation from an origin angle
---to a destination by a factor, t, in [0.0, 1.0].
---The range defaults to 360.0 for degrees, but can be
---math.pi * 2.0 for radians.
---Uses the counter-clockwise angular direction.
---@param origin number origin angle
---@param dest number destination angle
---@param t number factor
---@param range number range
---@return number
function Utilities.lerpAngleCcw(origin, dest, t, range)
    local valRange = range or 360.0
    local o = origin % valRange
    local d = dest % valRange
    local diff = d - o
    local u = 1.0 - t

    if diff == 0.0 then
        return o
    elseif o > d then
        return (u * o + t * (d + valRange)) % valRange
    else
        return u * o + t * d
    end
end

---Unclamped linear interpolation from an origin angle
---to a destination by a factor, t, in [0.0, 1.0].
---The range defaults to 360.0 for degrees, but can be
---math.pi * 2.0 for radians.
---Uses the clockwise angular direction.
---@param origin number origin angle
---@param dest number destination angle
---@param t number factor
---@param range number range
---@return number
function Utilities.lerpAngleCw(origin, dest, t, range)
    local valRange = range or 360.0
    local o = origin % valRange
    local d = dest % valRange
    local diff = d - o
    local u = 1.0 - t

    if diff == 0.0 then
        return d
    elseif o < d then
        return (u * (o + valRange) + t * d) % valRange
    else
        return u * o + t * d
    end
end

---Unclamped linear interpolation from an origin angle
---to a destination by a factor, t, in [0.0, 1.0].
---The range defaults to 360.0 for degrees, but can be
---math.pi * 2.0 for radians.
---Uses the furthest angular direction.
---@param origin number origin angle
---@param dest number destination angle
---@param t number factor
---@param range number range
---@return number
function Utilities.lerpAngleFar(origin, dest, t, range)
    local valRange = range or 360.0
    local halfRange = valRange * 0.5
    local o = origin % valRange
    local d = dest % valRange
    local diff = d - o
    local u = 1.0 - t

    if diff == 0.0 or (o < d and diff < halfRange) then
        return (u * (o + valRange) + t * d) % valRange
    elseif o > d and diff > -halfRange then
        return (u * o + t * (d + valRange)) % valRange
    else
        return u * o + t * d
    end
end

---Unclamped linear interpolation from an origin angle
---to a destination by a factor, t, in [0.0, 1.0].
---The range defaults to 360.0 for degrees, but can be
---math.pi * 2.0 for radians.
---Uses the nearest angular direction.
---@param origin number origin angle
---@param dest number destination angle
---@param t number factor
---@param range number range
---@return number
function Utilities.lerpAngleNear(origin, dest, t, range)
    local valRange = range or 360.0
    local halfRange = valRange * 0.5
    local o = origin % valRange
    local d = dest % valRange
    local diff = d - o
    local u = 1.0 - t

    if diff == 0.0 then
        return o
    elseif o < d and diff > halfRange then
        return (u * (o + valRange) + t * d) % valRange
    elseif o > d and diff < -halfRange then
        return (u * o + t * (d + valRange)) % valRange
    else
        return u * o + t * d
    end
end

---Multiplies a matrix with a 2D curve.
---Changes the curve in place.
---@param a table matrix
---@param b table curve
---@return table
function Utilities.mulMat3Curve2(a, b)
    local kns = b.knots
    local knsLen = #kns
    for i = 1, knsLen, 1 do
        -- Knot is changed in place.
        Utilities.mulMat3Knot2(a, kns[i])
    end
    return b
end

---Multiplies a matrix with a 2D knot.
---Changes the knot in place.
---@param a table matrix
---@param b table knot
---@return table
function Utilities.mulMat3Knot2(a, b)
    b.co = Utilities.mulMat3Point2(a, b.co)
    b.fh = Utilities.mulMat3Point2(a, b.fh)
    b.rh = Utilities.mulMat3Point2(a, b.rh)
    return b
end

---Multiplies a matrix with a 2D mesh.
---Changes the mesh in place.
---@param a table matrix
---@param b table mesh
---@return table
function Utilities.mulMat3Mesh2(a, b)
    local vs = b.vs
    local vsLen = #vs
    for i = 1, vsLen, 1 do
        vs[i] = Utilities.mulMat3Point2(a, vs[i])
    end
    return b
end

---Multiplies a Mat3 with a Vec2.
---The vector is treated as a point.
---@param a table matrix
---@param b table vector
---@return table
function Utilities.mulMat3Point2(a, b)
    local w = a.m20 * b.x + a.m21 * b.y + a.m22
    if w ~= 0.0 then
        local wInv = 1.0 / w
        return Vec2.new(
            (a.m00 * b.x + a.m01 * b.y + a.m02) * wInv,
            (a.m10 * b.x + a.m11 * b.y + a.m12) * wInv)
    else
        return Vec2.new(0.0, 0.0)
    end
end

---Multiplies a matrix with a 3D curve.
---Changes the curve in place.
---@param a table matrix
---@param b table curve
---@return table
function Utilities.mulMat4Curve3(a, b)
    local kns = b.knots
    local knsLen = #kns
    for i = 1, knsLen, 1 do
        -- Knot is changed in place.
        Utilities.mulMat4Knot3(a, kns[i])
    end
    return b
end

---Multiplies a matrix with a 3D knot.
---Changes the knot in place.
---@param a table matrix
---@param b table knot
---@return table
function Utilities.mulMat4Knot3(a, b)
    b.co = Utilities.mulMat4Point3(a, b.co)
    b.fh = Utilities.mulMat4Point3(a, b.fh)
    b.rh = Utilities.mulMat4Point3(a, b.rh)
    return b
end

---Multiplies a Mat4 with a Vec3.
---The vector is treated as a point.
---@param a table matrix
---@param b table vector
---@return table
function Utilities.mulMat4Point3(a, b)
    local w = a.m30 * b.x + a.m31 * b.y + a.m33
    if w ~= 0.0 then
        local wInv = 1.0 / w
        return Vec3.new(
            (a.m00 * b.x + a.m01 * b.y + a.m03) * wInv,
            (a.m10 * b.x + a.m11 * b.y + a.m13) * wInv,
            (a.m20 * b.x + a.m21 * b.y + a.m23) * wInv)
    else
        return Vec3.new(0.0, 0.0, 0.0)
    end
end

---Multiplies a Mat3 with a Vec3.
---@param a table matrix
---@param b table vector
---@return table
function Utilities.mulMat3Vec3(a, b)
    return Vec3.new(
        a.m00 * b.x + a.m01 * b.y + a.m02 * b.z,
        a.m10 * b.x + a.m11 * b.y + a.m12 * b.z,
        a.m20 * b.x + a.m21 * b.y + a.m22 * b.z)
end

---Multiplies a Mat4 with a Vec4.
---@param a table matrix
---@param b table vector
---@return table
function Utilities.mulMat4Vec4(a, b)
    return Vec4.new(
        a.m00 * b.x + a.m01 * b.y
      + a.m02 * b.z + a.m03 * b.w,
        a.m10 * b.x + a.m11 * b.y
      + a.m12 * b.z + a.m13 * b.w,
        a.m20 * b.x + a.m21 * b.y
      + a.m22 * b.z + a.m23 * b.w,
        a.m30 * b.x + a.m31 * b.y
      + a.m32 * b.z + a.m33 * b.w)
end

---Multiplies a Quaternion and a Vec3.
---The Vec3 is treated as a point, not as
---a pure quaternion.
---@param a table quaternion
---@param b table vector
---@return table
function Utilities.mulQuatVec3(a, b)
    local ai = a.imag
    local qw = a.real
    local qx = ai.x
    local qy = ai.y
    local qz = ai.z

    local iw = -qx * b.x - qy * b.y - qz * b.z
    local ix =  qw * b.x + qy * b.z - qz * b.y
    local iy =  qw * b.y + qz * b.x - qx * b.z
    local iz =  qw * b.z + qx * b.y - qy * b.x

    return Vec3.new(
        ix * qw + iz * qy - iw * qx - iy * qz,
        iy * qw + ix * qz - iw * qy - iz * qx,
        iz * qw + iy * qx - iw * qz - ix * qy)
end

---Promotes a Knot2 to a Knot3.
---All z components default to 0.0
---@param a table knot
---@return table
function Utilities.promoteKnot2ToKnot3(a)
    return Knot3.new(
        Utilities.promoteVec2ToVec3(a.co, 0.0),
        Utilities.promoteVec2ToVec3(a.fh, 0.0),
        Utilities.promoteVec2ToVec3(a.rh, 0.0))
end

---Promotes a Vec2 to a Vec3.
---The z component defaults to 0.0.
---@param a table vector
---@param z number z component
---@return table
function Utilities.promoteVec2ToVec3(a, z)
    local vz = z or 0.0
    return Vec3.new(a.x, a.y, vz)
end

---Promotes a Vec2 to a Vec4.
---The z component defaults to 0.0.
---The w component defaults to 0.0.
---@param a table vector
---@param z number z component
---@param w number w component
---@return table
function Utilities.promoteVec2ToVec4(a, z, w)
    local vz = z or 0.0
    local vw = w or 0.0
    return Vec4.new(a.x, a.y, vz, vw)
end

---Promotes a Vec3 to a Vec4.
---The w component defaults to 0.0.
---@param a table vector
---@param w number w component
---@return table
function Utilities.promoteVec3ToVec4(a, w)
    local vw = w or 0.0
    return Vec4.new(a.x, a.y, a.z, vw)
end

---Quantizes a number.
---Defaults to signed quantization.
---@param a number value
---@param levels number levels
---@return number
function Utilities.quantize(a, levels)
    return Utilities.quantizeSigned(a, levels)
end

---Quantizes a signed number according
---to a number of levels. The quantization
---is centered about the range.
---@param a number value
---@param levels number levels
---@return number
function Utilities.quantizeSigned(a, levels)
    if levels ~= 0.0 then
        return math.floor(0.5 + a * levels) / levels
    else
        return a
    end
end

---Quantizes an unsigned number according
---to a number of levels. The quantization
---is based on the left edge.
---@param a number value
---@param levels number levels
---@return number
function Utilities.quantizeUnsigned(a, levels)
    if levels ~= 0.0 then
        return math.max(0.0,
            (math.ceil(a * levels) - 1.0)
            / (levels - 1.0))
    else
        return a
    end
end

return Utilities