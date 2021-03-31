dofile("./vec2.lua")
dofile("./knot2.lua")

Curve2 = {}
Curve2.__index = Curve2

setmetatable(Curve2, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

---Constructs a new vector from two numbers.
---@param cl boolean closed loop
---@param knots number knots
---@param name string name
---@return table
function Curve2.new(cl, knots, name)
    local inst = setmetatable({}, Curve2)
    inst.closedLoop = cl or false
    inst.knots = knots or {}
    inst.name = name or "Curve2"
    return inst
end

function Curve2:__len()
    return #self.knots
end

function Curve2:__tostring()
    return Curve2.toJson(self)
end

---Rotates this curve around the z axis by
---an angle in radians.
---@param radians number angle
---@return table
function Curve2:rotateZ(radians)
    return self:rotateZInternal(
        math.cos(radians),
        math.sin(radians))
end

---Rotates this curve around the z axis by
---the cosine and sine of an angle.
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return table
function Curve2:rotateZInternal(cosa, sina)
    local knsLen = #self.knots
    for i = 1, knsLen, 1 do
        self.knots[i]:rotateZInternal(cosa, sina)
    end
    return self
end

---Scales this curve.
---Defaults to scale by a vector.
---@param v table scalar
---@return table
function Curve2:scale(v)
    return self:scaleByVec2(v)
end

---Scales this curve by a number.
---@param n table uniform scalar
---@return table
function Curve2:scaleByNumber(n)
    if n ~= 0.0 then
        local knsLen = #self.knots
        for i = 1, knsLen, 1 do
            self.knots[i]:scaleByNumber(n)
        end
    end
    return self
end

---Scales this curve by a vector.
---@param v table nonuniform scalar
---@return table
function Curve2:scaleByVec2(v)
    if Vec2.all(v) then
        local knsLen = #self.knots
        for i = 1, knsLen, 1 do
            self.knots[i]:scaleByVec2(v)
        end
    end
    return self
end

---Translates this curve by a vector.
---@param v table vector
---@return table
function Curve2:translate(v)
    local knsLen = #self.knots
    for i = 1, knsLen, 1 do
        self.knots[i]:translate(v)
    end
    return self
end

---Evaluates a curve by a step in [0.0, 1.0].
---Returns a vector representing a point on the curve.
---@param curve table curve
---@param step number step
---@return table
function Curve2.eval(curve, step)
    local t = step or 0.5
    local knots = curve.knots
    local knotLength = #knots
    local tScaled = 0.0
    local i = 0
    local a = nil
    local b = nil

    if curve.closedLoop then

        tScaled = (t % 1.0) * knotLength
        i = math.tointeger(tScaled)
        a = knots[1 + (i % knotLength)]
        b = knots[1 + ((i + 1) % knotLength)]

    else

        if t <= 0.0 or knotLength == 1 then
            return Curve2.evalFirst(curve)
        end

        if t >= 1.0 then
            return Curve2.evalLast(curve)
        end

        tScaled = t * (knotLength - 1)
        i = math.tointeger(tScaled)
        a = knots[1 + i]
        b = knots[2 + i]

    end

    -- Eval tangent as well, return table?
    -- Or rename to evalPoint and make separate
    -- function for tangent?
    local tsni = tScaled - i
    return Knot2.bezierPoint(a, b, tsni)
end

---Evaluates a curve at its first knot,
---returning a copy of the first knot coord.
---@param curve table the curve
---@return table
function Curve2.evalFirst(curve)
    local kFirst = curve.knots[1]
    return Vec2.new(kFirst.co.x, kFirst.co.y)
end

---Evaluates a curve at its last knot,
---returning a copy of the last knot coord.
---@param curve table the curve
---@return table
function Curve2.evalLast(curve)
    local kLast = curve.knots[#curve.knots]
    return Vec2.new(kLast.co.x, kLast.co.y)
end

---Creats a curve that approximates Bernoulli's
---lemniscate, i.e., an infinity loop.
---@return table
function Curve2.infinity()
    return Curve2.new(true, {
        Knot2.new(
            Vec2.new(0.5, 0.0),
            Vec2.new(0.5, 0.1309615),
            Vec2.new(0.5, -0.1309615)),
        Knot2.new(
            Vec2.new(0.235709, 0.166627),
            Vec2.new(0.0505335, 0.114256),
            Vec2.new(0.361728, 0.2022675)),
        Knot2.new(
            Vec2.new(-0.235709, -0.166627),
            Vec2.new(-0.361728, -0.2022675),
            Vec2.new(-0.0505335, -0.114256)),
        Knot2.new(
            Vec2.new(-0.5, 0.0),
            Vec2.new(-0.5, 0.1309615),
            Vec2.new(-0.5, -0.1309615)),
        Knot2.new(
            Vec2.new(-0.235709, 0.166627),
            Vec2.new(-0.0505335, 0.114256),
            Vec2.new(-0.361728, 0.2022675)),
        Knot2.new(
            Vec2.new(0.235709, -0.166627),
            Vec2.new(0.361728, -0.2022675),
            Vec2.new(0.0505335, -0.114256))
    }, "Infinity")
end

---Creates a rectangle with rounded corners.
---Rounding may be either positive or negative.
---@param lbx number lower bound x
---@param lby number lower bound y
---@param ubx number upper bound x
---@param uby number upper bound y
---@param tl number rounding top left corner
---@param tr number rounding top right corner
---@param br number rounding bottom right corner
---@param bl number rounding bottom left corner
function Curve2.rect(
    lbx, lby, ubx, uby,
    tl, tr, br, bl)

    -- Validate corners.
    local lft = math.min(lbx, ubx)
    local rgt = math.max(lbx, ubx)
    local btm = math.min(lby, uby)
    local top = math.max(lby, uby)

    -- Validate corner insetting.
    local limit = 0.5 * math.min(rgt - lft, top - btm)
    local vtl = 0.000001
    if tl then
        vtl = math.min(limit, math.max(0.000001, math.abs(tl)))
    end

    -- If only one corner arg is provided, then
    -- set them all to that corner.
    local vtr = vtl
    local vbr = vtl
    local vbl = vtl
    if tr and br and bl then
        vtr = math.min(limit, math.max(0.000001, math.abs(tr)))
        vbr = math.min(limit, math.max(0.000001, math.abs(br)))
        vbl = math.min(limit, math.max(0.000001, math.abs(bl)))
    end

    -- Calculate insets.
    local btmIns0 = btm + vbr
    local topIns0 = top - vtr
    local rgtIns0 = rgt - vtr
    local lftIns0 = lft + vtl
    local topIns1 = top - vtl
    local btmIns1 = btm + vbl
    local lftIns1 = lft + vbl
    local rgtIns1 = rgt - vbr

    local t = 0.3333333333333333
    local u = 0.6666666666666667

    -- Bottom edge.
    local k7 = Knot2.new(
        Vec2.new(lftIns1, btm),
        Vec2.new(u * lftIns1 + t * rgtIns1, btm),
        Vec2.new(0.0, 0.0))
    local k0 = Knot2.new(
        Vec2.new(rgtIns1, btm),
        Vec2.new(0.0, 0.0),
        Vec2.new(u * rgtIns1 + t * lftIns1, btm))

    -- Right edge.
    local k1 = Knot2.new(
        Vec2.new(rgt, btmIns0),
        Vec2.new(rgt, u * btmIns0 + t * topIns0),
        Vec2.new(0.0, 0.0))
    local k2 = Knot2.new(
        Vec2.new(rgt, topIns0),
        Vec2.new(0.0, 0.0),
        Vec2.new(rgt, u * topIns0 + t * btmIns0))

    -- Top edge.
    local k3 = Knot2.new(
        Vec2.new(rgtIns0, top),
        Vec2.new(u * rgtIns0 + t * lftIns0, top),
        Vec2.new(0.0, 0.0))
    local k4 = Knot2.new(
        Vec2.new(lftIns0, top),
        Vec2.new(0.0, 0.0),
        Vec2.new(u * lftIns0 + t * rgtIns0, top))

    -- Left edge.
    local k5 = Knot2.new(
        Vec2.new(lft, topIns1),
        Vec2.new(lft, u * topIns1 + t * btmIns1),
        Vec2.new(0.0, 0.0))
    local k6 = Knot2.new(
        Vec2.new(lft, btmIns1),
        Vec2.new(0.0, 0.0),
        Vec2.new(lft, u * btmIns1 + t * topIns1))

    local rgt23 = u * rgt
    local btm23 = u * btm
    local top23 = u * top
    local lft23 = u * lft

    local rgt13 = t * rgt
    local btm13 = t * btm
    local top13 = t * top
    local lft13 = t * lft

    -- Bottom Right corner.
    local k0fh = k0.fh
    local k1rh = k1.rh
    if br > 0.0 then
        k0fh.x = t * rgtIns1 + rgt23
        k0fh.y = btm
        k1rh.x = rgt
        k1rh.y = t * btmIns0 + btm23
    else
        k0fh.x = rgtIns1
        k0fh.y = btm13 + u * btmIns0
        k1rh.x = rgt13 + u * rgtIns1
        k1rh.y = btmIns0
    end

    -- Top Right corner.
    local k2fh = k2.fh
    local k3rh = k3.rh
    if tr > 0.0 then
        k2fh.x = rgt
        k2fh.y = t * topIns0 + top23
        k3rh.x = t * rgtIns0 + rgt23
        k3rh.y = top
    else
        k2fh.x = rgt13 + u * rgtIns0
        k2fh.y = topIns0
        k3rh.x = rgtIns0
        k3rh.y = top13 + u * topIns0
    end

    -- Top Left corner.
    local k4fh = k4.fh
    local k5rh = k5.rh
    if tl > 0.0 then
        k4fh.x = t * lftIns0 + lft23
        k4fh.y = top
        k5rh.x = lft
        k5rh.y = t * topIns1 + top23
    else
        k4fh.x = lftIns0
        k4fh.y = top13 + u * topIns1
        k5rh.x = lft13 + u * lftIns0
        k5rh.y = topIns1
    end

    -- Bottom Left corner.
    local k6fh = k6.fh
    local k7rh = k7.rh
    if bl > 0.0 then
        k6fh.x = lft
        k6fh.y = t * btmIns1 + btm23
        k7rh.x = t * lftIns1 + lft23
        k7rh.y = btm
    else
        k6fh.x = lft13 + u * lftIns1
        k6fh.y = btmIns1
        k7rh.x = lftIns1
        k7rh.y = btm13 + u * btmIns1
    end

    return Curve2.new(true, {
        k0, k1, k2, k3, k4, k5, k6, k7
        }, "Rectangle")
end

---Returns a JSON string of a curve.
---@param c table curve
---@return string
function Curve2.toJson(c)
    local str = "{\"name\":\""
    str = str .. c.name
    str = str .. "\",\"closedLoop\":"
    if c.closedLoop then
        str = str .. "true"
    else
        str = str .. "false"
    end
    str = str .. ",\"knots\":["

    local kns = c.knots
    local knsLen = #kns
    for i = 1, knsLen, 1 do
        str = str .. Knot2.toJson(kns[i])
        if i < knsLen then str = str .. "," end
    end

    str = str .. "]}"
    return str
end

return Curve2