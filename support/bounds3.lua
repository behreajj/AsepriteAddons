---@class Bounds3
---@field public mn {l: number, a: number, b: number, alpha: number} lower bound
---@field public mx {l: number, a: number, b: number, alpha: number} upper bound
Bounds3 = {}
Bounds3.__index = Bounds3

setmetatable(Bounds3, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Constructs a new axis aligned bounding box (AABB) for a 3D volume,
---represented by a minimum and maximum coordinate. Defaults to passing vectors
---by value.
---@param mn {l: number, a: number, b: number, alpha: number} lower bound
---@param mx {l: number, a: number, b: number, alpha: number} upper bound
---@return Bounds3
---@nodiscard
function Bounds3.new(mn, mx)
    return Bounds3.newByVal(mn, mx)
end

---Constructs a new axis aligned bounding box (AABB) for a 3D volume,
---represented by a minimum and maximum coordinate. Vectors are assigned by
---reference.
---@param mn {l: number, a: number, b: number, alpha: number} lower bound
---@param mx {l: number, a: number, b: number, alpha: number} upper bound
---@return Bounds3
---@nodiscard
function Bounds3.newByRef(mn, mx)
    local inst <const> = setmetatable({}, Bounds3)
    inst.mn = mn or { l = 0.0, a = -111.0, b = -111.0, alpha = 0.0 }
    inst.mx = mx or { l = 100.0, a = 111.0, b = 111.0, alpha = 1.0 }
    return inst
end

---Constructs a new axis aligned bounding box (AABB) for a 3D volume,
---represented by a minimum and maximum coordinate. Vectors are copied by value.
---@param mn {l: number, a: number, b: number, alpha: number} lower bound
---@param mx {l: number, a: number, b: number, alpha: number} upper bound
---@return Bounds3
---@nodiscard
function Bounds3.newByVal(mn, mx)
    local inst <const> = setmetatable({}, Bounds3)

    inst.mn = nil
    if mn then
        inst.mn = { l = mn.l, a = mn.a, b = mn.b, alpha = mn.alpha }
    else
        inst.mn = { l = 0.0, a = -111.0, b = -111.0, alpha = 0.0 }
    end

    inst.mx = nil
    if mx then
        inst.mx = { l = mx.l, a = mx.a, b = mx.b, alpha = mx.alpha }
    else
        inst.mx = { l = 100.0, a = 111.0, b = 111.0, alpha = 1.0 }
    end

    return inst
end

function Bounds3:__le(b)
    return Bounds3.center(self) <= Bounds3.center(b)
end

function Bounds3:__lt(b)
    return Bounds3.center(self) < Bounds3.center(b)
end

function Bounds3:__tostring()
    return Bounds3.toJson(self)
end

---Finds the center of a bounding box. Returns a Vec3.
---@param b Bounds3 bounds
---@return Vec3
---@nodiscard
function Bounds3.center(b)
    return Vec3.mixNum(b.mn, b.mx, 0.5)
end

---Evaluates whether a point is within the bounds, lower bounds inclusive, upper
---bounds exclusive.
---@param b Bounds3 bounds
---@param pt {l: number, a: number, b: number, alpha: number} point
---@return boolean
---@nodiscard
function Bounds3.containsInclExcl(b, pt)
    local mn <const> = b.mn
    local mx <const> = b.mx
    return (pt.l >= mn.l and pt.l < mx.l)
        and (pt.a >= mn.a and pt.a < mx.a)
        and (pt.b >= mn.b and pt.b < mx.b)
        and (pt.alpha >= mn.alpha and pt.alpha < mx.alpha)
end

---Evaluates whether a bounding box intersects a sphere.
---@param a Bounds3 bounds
---@param center {l: number, a: number, b: number, alpha: number} sphere center
---@param radius number sphere radius
---@return boolean
---@nodiscard
function Bounds3.intersectsSphere(a, center, radius)
    return Bounds3.intersectsSphereInternal(
        a, center, radius * radius, 0.0)
end

---Evaluates whether a bounding box intersects a sphere. Internal helper
---function for octrees, as it assumes that the squared-radius has already been
---calculated.
---@param v Bounds3 bounds
---@param center {l: number, a: number, b: number, alpha: number} sphere center
---@param rsq number sphere radius, squared
---@param alphaScale number alpha scalar
---@return boolean
---@nodiscard
function Bounds3.intersectsSphereInternal(v, center, rsq, alphaScale)
    local ld, ad, bd, td = 0.0, 0.0, 0.0, 0.0

    if center.l < v.mn.l then
        ld = center.l - v.mn.l
    elseif center.l > v.mx.l then
        ld = center.l - v.mx.l
    end

    if center.a < v.mn.a then
        ad = center.a - v.mn.a
    elseif center.a > v.mx.a then
        ad = center.a - v.mx.a
    end

    if center.b < v.mn.b then
        bd = center.b - v.mn.b
    elseif center.b > v.mx.b then
        bd = center.b - v.mx.b
    end

    if center.alpha < v.mn.alpha then
        td = center.alpha - v.mn.alpha
    elseif center.alpha > v.mx.alpha then
        td = center.alpha - v.mx.alpha
    end

    return (ld * ld + ad * ad + bd * bd + alphaScale * td * td) < rsq
end

---Splits a bounding box into octants according to three factors in the range
---[0.0, 1.0]. The factor on the x axis governs the vertical split. On the y
---axis, the horizontal split. On the z axis, the depth split.
---@param v Bounds3 bounds
---@param lFac number vertical factor
---@param aFac number horizontal vector
---@param bFac number depth factor
---@param bsw Bounds3 back south west octant
---@param bse Bounds3 back south east octant
---@param bnw Bounds3 back north west octant
---@param bne Bounds3 back north east octant
---@param fsw Bounds3 front south west octant
---@param fse Bounds3 front south east octant
---@param fnw Bounds3 front north west octant
---@param fne Bounds3 front north east octant
function Bounds3.splitInternal(
    v, lFac, aFac, bFac,
    bsw, bse, bnw, bne, fsw, fse, fnw, fne)
    local vMn <const> = v.mn
    local vMx <const> = v.mx

    local l <const> = (1.0 - lFac) * vMn.l + lFac * vMx.l
    local a <const> = (1.0 - aFac) * vMn.a + aFac * vMx.a
    local b <const> = (1.0 - bFac) * vMn.b + bFac * vMx.b

    bsw.mn = { l = vMn.l, a = vMn.a, b = vMn.b, alpha = vMn.alpha }
    bse.mn = { l = l, a = vMn.a, b = vMn.b, alpha = vMn.alpha }
    bnw.mn = { l = vMn.l, a = a, b = vMn.b, alpha = vMn.alpha }
    bne.mn = { l = l, a = a, b = vMn.b, alpha = vMn.alpha }
    fsw.mn = { l = vMn.l, a = vMn.a, b = b, alpha = vMn.alpha }
    fse.mn = { l = l, a = vMn.a, b = b, alpha = vMn.alpha }
    fnw.mn = { l = vMn.l, a = a, b = b, alpha = vMn.alpha }
    fne.mn = { l = l, a = a, b = b, alpha = vMn.alpha }

    bsw.mx = { l = l, a = a, b = b, alpha = vMx.alpha }
    bse.mx = { l = vMx.l, a = a, b = b, alpha = vMx.alpha }
    bnw.mx = { l = l, a = vMx.a, b = b, alpha = vMx.alpha }
    bne.mx = { l = vMx.l, a = vMx.a, b = b, alpha = vMx.alpha }
    fsw.mx = { l = l, a = a, b = vMx.b, alpha = vMx.alpha }
    fse.mx = { l = vMx.l, a = a, b = vMx.b, alpha = vMx.alpha }
    fnw.mx = { l = l, a = vMx.a, b = vMx.b, alpha = vMx.alpha }
    fne.mx = { l = vMx.l, a = vMx.a, b = vMx.b, alpha = vMx.alpha }
end

---Returns a JSON string of the bounds.
---@param b Bounds3 bounds
---@return string
---@nodiscard
function Bounds3.toJson(b)
    return string.format(
        "{\"mn\":{\"l\":%.4f,\"a\":%.4f,\"b\":%.4f,\"alpha\":%.4f}" ..
        ",\"mx\":{\"l\":%.4f,\"a\":%.4f,\"b\":%.4f,\"alpha\":%.4f}",
        b.mn.l, b.mn.a, b.mn.b, b.mn.alpha,
        b.mx.l, b.mx.a, b.mx.b, b.mx.alpha)
end

---Returns a bounds with the dimensions of the SR LAB 2 color space.
---Intended for use with an octree containing points of color.
---@return Bounds3
---@nodiscard
function Bounds3.srLab2()
    return Bounds3.newByRef(
        { l = -0.01, a = -111.0, b = -111.0, alpha = -0.01 },
        { l = 100.1, a = 111.0, b = 111.0, alpha = 1.01 })
end

return Bounds3