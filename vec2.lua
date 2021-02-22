Vec2 = {}
Vec2.__index = Vec2

function Vec2:new(x,y)
    local inst = {}
    setmetatable(inst,Vec2)
    inst.x = x or 0.0
    inst.y = y or inst.x
    return inst
end

function Vec2:__tostring()
    return string.format(
        "{ x: %.4f, y: %.4f }",
        self.x,
        self.y)
end

function Vec2:abs(a)
    return Vec2:new(
        math.abs(a.x),
        math.abs(a.y))
end

function Vec2:add(a, b)
    return Vec2:new(
        a.x + b.x,
        a.y + b.y)
end

function Vec2:ceil(a)
    return Vec2:new(
        math.ceil(a.x),
        math.ceil(a.y))
end

function Vec2:compDiv(a, b)
    local cx = 0.0
    local cy = 0.0
    if b.x ~= 0.0 then cx = a.x / b.x end
    if b.y ~= 0.0 then cy = a.y / b.y end
    return Vec2:new(cx, cy)
end

function Vec2:compMul(a, b)
    return Vec2:new(a.x * b.x, a.y * b.y)
end

function Vec2:cross(a, b)
    return a.x * b.y - a.y * b.x
end

function Vec2:dot(a, b)
    return a.x * b.x + a.y * b.y
end

function Vec2:fract(a)
    return Vec2:new(
        a.x - math.tointeger(a.x),
        a.y - math.tointeger(a.y))
end

function Vec2:fromPolar(heading, radius)
    local r = radius or 1.0
    return Vec2:new(
        r * math.cos(heading),
        r * math.sin(heading))
end

function Vec2:headingSigned(a)
    return math.atan(a.y, a.x)
end

function Vec2:headingUnsigned(a)
    return math.atan(a.y, a.x) % 6.283185307179586
end

function Vec2:mag(a)
    return math.sqrt(a.x * a.x + a.y * a.y)
end

function Vec2:magSq(a)
    return a.x * a.x + a.y * a.y
end

function Vec2:normalize(a)
    local mSq = a.x * a.x + a.y * a.y
    if mSq > 0.0 then
        local mInv = 1.0 / math.sqrt(mSq)
        return Vec2:new(
            a.x * mInv,
            a.y * mInv)
    end
    return Vec2:new(0.0, 0.0)
end

function Vec2:perpendicularCW(a)
    return Vec2:new(a.y, -a.x)
end

function Vec2:perpendicularCCW(a)
    return Vec2:new(-a.y, a.x)
end

function Vec2:quantize(a, levels)
    if levels and levels > 1 then
        local delta = 1.0 / levels
        return Vec2:new(
            delta * math.floor(0.5 + a.x * levels),
            delta * math.floor(0.5 + a.y * levels))
    end
    return Vec2:new(a.x, a.y)
end

function Vec2:rescale(a, b)
    local mSq = a.x * a.x + a.y * a.y
    if mSq > 0.0 then
        local bmInv = b / math.sqrt(mSq)
        return Vec2:new(
            a.x * bmInv,
            a.y * bmInv)
    end
    return Vec2:new(0.0, 0.0)
end

function Vec2:rotateZ(a, radians)
    return Vec2:rotateZInternal(a,
        math.cos(radians), math.sin(radians))
end

function Vec2:rotateZInternal(a, cosa, sina)
    return Vec2:new(
        cosa * a.x - sina * a.y,
        cosa * a.y + sina * a.x)
end

function Vec2:scale(a, b)
    return Vec2:new(a.x * b, a.y * b)
end

function Vec2:sub(a, b)
    return Vec2:new(
        a.x - b.x,
        a.y - b.y)
end

function Vec2:toPolar(a)
    return {
        heading = Vec2:heading(a),
        radius = Vec2:mag(a) }
end

function Vec2:trunc(a)
    return Vec2:new(
        math.tointeger(a.x),
        math.tointeger(a.y))
end

-- create and use an Vec2
n = Vec2:new(3.12,4.45)
m = Vec2:new(1.4567, 2.34568)
print(Vec2:quantize(m, 8))