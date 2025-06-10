dofile("./lab.lua")

---@class BoundsLab
---@field public mn Lab lower bound
---@field public mx Lab upper bound
BoundsLab = {}
BoundsLab.__index = BoundsLab

setmetatable(BoundsLab, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Constructs a new axis aligned bounding box (AABB) for a 3D volume,
---represented by a minimum and maximum coordinate. Defaults to passing vectors
---by value.
---@param mn Lab lower bound
---@param mx Lab upper bound
---@return BoundsLab
---@nodiscard
function BoundsLab.new(mn, mx)
    return BoundsLab.newByVal(mn, mx)
end

---Constructs a new axis aligned bounding box (AABB) for a 3D volume,
---represented by a minimum and maximum coordinate. Vectors are assigned by
---reference.
---@param mn Lab lower bound
---@param mx Lab upper bound
---@return BoundsLab
---@nodiscard
function BoundsLab.newByRef(mn, mx)
    local inst <const> = setmetatable({}, BoundsLab)
    inst.mn = mn or Lab.new(-1.0, -111.0, -111.0, -0.01)
    inst.mx = mx or Lab.new(101.0, 111.0, 111.0, 1.01)
    return inst
end

---Constructs a new axis aligned bounding box (AABB) for a 3D volume,
---represented by a minimum and maximum coordinate. Vectors are copied by value.
---@param mn Lab lower bound
---@param mx Lab upper bound
---@return BoundsLab
---@nodiscard
function BoundsLab.newByVal(mn, mx)
    local inst <const> = setmetatable({}, BoundsLab)

    inst.mn = nil
    if mn then
        inst.mn = Lab.new(mn.l, mn.a, mn.b, mn.alpha)
    else
        inst.mn = Lab.new(-1.0, -111.0, -111.0, -0.01)
    end

    inst.mx = nil
    if mx then
        inst.mx = Lab.new(mx.l, mx.a, mx.b, mx.alpha)
    else
        inst.mx = Lab.new(101.0, 111.0, 111.0, 1.01)
    end

    return inst
end

function BoundsLab:__le(b)
    return BoundsLab.center(self) <= BoundsLab.center(b)
end

function BoundsLab:__lt(b)
    return BoundsLab.center(self) < BoundsLab.center(b)
end

function BoundsLab:__tostring()
    return BoundsLab.toJson(self)
end

---Finds the center of a bounding box. Returns a Lab.
---@param b BoundsLab bounds
---@return Lab
---@nodiscard
function BoundsLab.center(b)
    return Lab.mix(b.mn, b.mx, 0.5)
end

---Evaluates whether a point is within the bounds, lower bounds inclusive, upper
---bounds exclusive.
---@param b BoundsLab bounds
---@param pt Lab point
---@return boolean
---@nodiscard
function BoundsLab.containsInclExcl(b, pt)
    local mn <const> = b.mn
    local mx <const> = b.mx
    return (pt.l >= mn.l and pt.l < mx.l)
        and (pt.a >= mn.a and pt.a < mx.a)
        and (pt.b >= mn.b and pt.b < mx.b)
        and (pt.alpha >= mn.alpha and pt.alpha < mx.alpha)
end

---Evaluates whether a bounding box intersects a sphere.
---@param bounds BoundsLab bounds
---@param center Lab sphere center
---@param radius number sphere radius
---@return boolean
---@nodiscard
function BoundsLab.intersectsSphere(bounds, center, radius)
    return BoundsLab.intersectsSphereInternal(
        bounds, center, radius * radius)
end

---Evaluates whether a bounding box intersects a sphere. Internal helper
---function for octrees, as it assumes that the squared-radius has already been
---calculated.
---@param bounds BoundsLab bounds
---@param center Lab sphere center
---@param rsq number sphere radius, squared
---@return boolean
---@nodiscard
function BoundsLab.intersectsSphereInternal(bounds, center, rsq)
    local xd, yd, zd = 0.0, 0.0, 0.0

    if center.l < bounds.mn.l then
        zd = center.l - bounds.mn.l
    elseif center.l > bounds.mx.l then
        zd = center.l - bounds.mx.l
    end

    if center.a < bounds.mn.a then
        xd = center.a - bounds.mn.a
    elseif center.a > bounds.mx.a then
        xd = center.a - bounds.mx.a
    end

    if center.b < bounds.mn.b then
        yd = center.b - bounds.mn.b
    elseif center.b > bounds.mx.b then
        yd = center.b - bounds.mx.b
    end

    return (xd * xd + yd * yd + zd * zd) < rsq
end

---Splits a bounding box into octants according to three factors in the range
---[0.0, 1.0]. The factor on the x axis governs the vertical split. On the y
---axis, the horizontal split. On the z axis, the depth split.
---@param bounds BoundsLab bounds
---@param xFac number vertical factor
---@param yFac number horizontal vector
---@param zFac number depth factor
---@param bsw BoundsLab back south west octant
---@param bse BoundsLab back south east octant
---@param bnw BoundsLab back north west octant
---@param bne BoundsLab back north east octant
---@param fsw BoundsLab front south west octant
---@param fse BoundsLab front south east octant
---@param fnw BoundsLab front north west octant
---@param fne BoundsLab front north east octant
function BoundsLab.splitInternal(
    bounds, xFac, yFac, zFac,
    bsw, bse, bnw, bne, fsw, fse, fnw, fne)
    local bMn <const> = bounds.mn
    local bMx <const> = bounds.mx

    local l <const> = (1.0 - zFac) * bMn.l + zFac * bMx.l
    local a <const> = (1.0 - xFac) * bMn.a + xFac * bMx.a
    local b <const> = (1.0 - yFac) * bMn.b + yFac * bMx.b

    bsw.mn = Lab.new(bMn.l, bMn.a, bMn.b, bMn.alpha)
    bse.mn = Lab.new(bMn.l, a, bMn.b, bMn.alpha)
    bnw.mn = Lab.new(bMn.l, bMn.a, b, bMn.alpha)
    bne.mn = Lab.new(bMn.l, a, b, bMn.alpha)
    fsw.mn = Lab.new(l, bMn.a, bMn.b, bMn.alpha)
    fse.mn = Lab.new(l, a, bMn.b, bMn.alpha)
    fnw.mn = Lab.new(l, bMn.a, b, bMn.alpha)
    fne.mn = Lab.new(l, a, b, bMn.alpha)

    bsw.mx = Lab.new(l, a, b, bMx.alpha)
    bse.mx = Lab.new(l, bMx.a, b, bMx.alpha)
    bnw.mx = Lab.new(l, a, bMx.b, bMx.alpha)
    bne.mx = Lab.new(l, bMx.a, bMx.b, bMx.alpha)
    fsw.mx = Lab.new(bMx.l, a, b, bMx.alpha)
    fse.mx = Lab.new(bMx.l, bMx.a, b, bMx.alpha)
    fnw.mx = Lab.new(bMx.l, a, bMx.b, bMx.alpha)
    fne.mx = Lab.new(bMx.l, bMx.a, bMx.b, bMx.alpha)
end

---Returns a JSON string of the bounds.
---@param b BoundsLab bounds
---@return string
---@nodiscard
function BoundsLab.toJson(b)
    return string.format(
        "{\"mn\":%s,\"mx\":%s}",
        Lab.toJson(b.mn),
        Lab.toJson(b.mx))
end

---Returns a bounds with the dimensions of the CIE LAB or SR LAB 2 color spaces.
---Intended for use with an octree containing points of color.
---@return BoundsLab
---@nodiscard
function BoundsLab.srLab2()
    return BoundsLab.newByRef(
        Lab.new(-1.0, -111.0, -111.0, -0.01),
        Lab.new(101.0, 111.0, 111.0, 1.01))
end

return BoundsLab