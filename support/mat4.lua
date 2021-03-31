Mat4 = {}
Mat4.__index = Mat4

setmetatable(Mat4, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

---Constructs a row major 4x4 matrix from numbers.
---@param m00 number row 0, col 0 right x
---@param m01 number row 0, col 1 forward x
---@param m02 number row 0, col 2 up x
---@param m03 number row 0, col 3 translation x
---@param m10 number row 1, col 0 right y
---@param m11 number row 1, col 1 forward y
---@param m12 number row 1, col 2 up y
---@param m13 number row 1, col 3 translation y
---@param m20 number row 2, col 0 right z
---@param m21 number row 2, col 1 forward z
---@param m22 number row 2, col 2 up z
---@param m23 number row 2, col 3 translation z
---@param m30 number row 3, col 0 right w
---@param m31 number row 3, col 1 forward w
---@param m32 number row 3, col 2 up w
---@param m33 number row 3, col 3 translation w
---@return table
function Mat4.new(
    m00, m01, m02, m03,
    m10, m11, m12, m13,
    m20, m21, m22, m23,
    m30, m31, m32, m33)
    local inst = setmetatable({}, Mat4)

    inst.m00 = m00 or 1.0
    inst.m01 = m01 or 0.0
    inst.m02 = m02 or 0.0
    inst.m03 = m03 or 0.0

    inst.m10 = m10 or 0.0
    inst.m11 = m11 or 1.0
    inst.m12 = m12 or 0.0
    inst.m13 = m13 or 0.0

    inst.m20 = m20 or 0.0
    inst.m21 = m21 or 0.0
    inst.m22 = m22 or 1.0
    inst.m23 = m23 or 0.0

    inst.m30 = m30 or 0.0
    inst.m31 = m31 or 0.0
    inst.m32 = m32 or 0.0
    inst.m33 = m33 or 1.0

    return inst
end

function Mat4:__add(b)
    return Mat4.add(self, b)
end

function Mat4:__div(b)
    return Mat4.div(self, b)
end

function Mat4:__len()
    return 16
end

function Mat4:__mul(b)
    return Mat4.mul(self, b)
end

function Mat4:__sub(b)
    return Mat4.sub(self, b)
end

function Mat4:__tostring()
    return Mat4.toJson(self)
end

function Mat4:__unm()
    return Mat4.negate(self)
end

---Finds the sum of two matrices.
---@param a table left operand
---@param b table right operand
---@return table
function Mat4.add(a, b)
    return Mat4.new(
        a.m00 + b.m00, a.m01 + b.m01, a.m02 + b.m02, a.m03 + b.m03,
        a.m10 + b.m10, a.m11 + b.m11, a.m12 + b.m12, a.m13 + b.m13,
        a.m20 + b.m20, a.m21 + b.m21, a.m22 + b.m22, a.m23 + b.m23,
        a.m30 + b.m30, a.m31 + b.m31, a.m32 + b.m32, a.m33 + b.m33)
end

---Creates an orbiting camera matrix.
---The camera looks from its location
---at its focal target with reference
---to the world up axis (0.0, 1.0, 1.0)
---or (0.0, 1.0, 0.0). Handedness is a
---string, either "RIGHT" or "LEFT".
---@param xLoc number location x
---@param yLoc number location y
---@param zLoc number location z
---@param xFocus number focus x
---@param yFocus number focus y
---@param zFocus number focus z
---@param xRef number reference x
---@param yRef number reference y
---@param zRef number reference z
---@param handedness string handedness
---@return table
function Mat4.camera(
    xLoc, yLoc, zLoc,
    xFocus, yFocus, zFocus,
    xRef, yRef, zRef,
    handedness)

    -- Optional args for handedness.
    -- Default to right-handed.
    local hval = "RIGHT"
    if handedness and handedness == "LEFT" then
        hval = handedness
    end

    -- Optional args for reference up.
    -- Default to z-up.
    local xrv = xRef or 0.0
    local yrv = yRef or 0.0
    local zrv = zRef or 1.0

    -- Optional args for focus.
    -- Default to origin.
    local xfv = xFocus or 0.0
    local yfv = yFocus or 0.0
    local zfv = zFocus or 0.0

    -- Find k by subtractinglocation from focus.
    local kx = xLoc - xfv
    local ky = yLoc - yfv
    local kz = zLoc - zfv

    -- Normalize k.
    local kmsq = kx * kx + ky * ky + kz * kz
    if kmsq ~= 0.0 then
        local kminv = 1.0 / math.sqrt(kmsq)
        kx = kx * kminv
        ky = ky * kminv
        kz = kz * kminv
    end

    -- Check for parallel forward and up.
    local dotp = kx * xrv + ky * yrv + kz * zrv
    local tol = 0.999999
    if dotp < -tol or dotp > tol then
        return Mat4.fromTranslation(xLoc, yLoc, zLoc)
    end

    local ix = 1.0
    local iy = 0.0
    local iz = 0.0

    local jx = 0.0
    local jy = 1.0
    local jz = 0.0

    if hval == "LEFT" then

        -- Cross k with ref to get i.
        ix = ky * zrv - kz * yrv
        iy = kz * xrv - kx * zrv
        iz = kx * yrv - ky * xrv

        -- Normalize i.
        local imsq = ix * ix + iy * iy + iz * iz
        if imsq ~= 0.0 then
            local iminv = 1.0 / math.sqrt(imsq)
            ix = ix * iminv
            iy = iy * iminv
            iz = iz * iminv
        end

        -- Cross i with k to get j.
        jx = iy * kz - iz * ky
        jy = iz * kx - ix * kz
        jz = ix * ky - iy * kx

        -- Normalize j.
        local jmsq = jx * jx + jy * jy + jz * jz
        if jmsq ~= 0.0 then
            local jminv = 1.0 / math.sqrt(jmsq)
            jx = jx * jminv
            jy = jy * jminv
            jz = jz * jminv
        end

    else

        -- Cross ref with k to get i.
        ix = yrv * kz - zrv * ky
        iy = zrv * kx - xrv * kz
        iz = xrv * ky - yrv * kx

        -- Normalize i.
        local imsq = ix * ix + iy * iy + iz * iz
        if imsq ~= 0.0 then
            local iminv = 1.0 / math.sqrt(imsq)
            ix = ix * iminv
            iy = iy * iminv
            iz = iz * iminv
        end

        -- Cross k with i to get j.
        jx = ky * iz - kz * iy
        jy = kz * ix - kx * iz
        jz = kx * iy - ky * ix

        -- Normalize j.
        local jmsq = jx * jx + jy * jy + jz * jz
        if jmsq ~= 0.0 then
            local jminv = 1.0 / math.sqrt(jmsq)
            jx = jx * jminv
            jy = jy * jminv
            jz = jz * jminv
        end

    end

    return Mat4.new(
        ix, iy, iz, -xLoc * ix - yLoc * iy - zLoc * iz,
        jx, jy, jz, -xLoc * jx - yLoc * jy - zLoc * jz,
        kx, ky, kz, -xLoc * kx - yLoc * ky - zLoc * kz,
        0.0, 0.0, 0.0, 1.0)
end

---Creates a dimetric camera at a location.
---@param xLoc number location x
---@param yLoc number location y
---@param zLoc number location z
---@param handedness string handedness
---@return table
function Mat4.cameraDimetric(xLoc, yLoc, zLoc, handedness)
    local hval = "RIGHT"
    if handedness and handedness == "LEFT" then
        hval = handedness
    end

    if hval == "LEFT" then
        return Mat4.new(
            0.70710677, 0.0, 0.70710677,
            -xLoc * 0.70710677 - zLoc * 0.70710677,
            -0.38960868, 0.8345119, 0.38960868,
            xLoc * 0.38960868 - yLoc * 0.8345119 - zLoc * 0.38960868,
            0.590089, 0.55098987, -0.590089,
            -xLoc * 0.590089 - yLoc * 0.55098987 + zLoc * 0.590089,
            0.0, 0.0, 0.0, 1.0)
    else
        return Mat4.new(
            0.70710677, 0.70710677, 0.0,
            -xLoc * 0.70710677 - yLoc * 0.70710677,
            -0.38960868, 0.38960868, 0.8345119,
            xLoc * 0.38960868 - yLoc * 0.38960868 - zLoc * 0.8345119,
            0.590089, -0.590089, 0.55098987,
            -xLoc * 0.590089 + yLoc * 0.590089 - zLoc * 0.55098987,
            0.0, 0.0, 0.0, 1.0)
    end
end

---Multiplies the left operand and the inverse of the right.
---@param a table left operand
---@param b table right operand
---@return table
function Mat4.div(a, b)
    return Mat4.mul(a, Mat4.inverse(b))
end

---Finds the matrix determinant.
---@param a table matrix
---@return number
function Mat4.determinant(a)
    return a.m00 * (a.m11 * a.m22 * a.m33 +
                    a.m12 * a.m23 * a.m31 +
                    a.m13 * a.m21 * a.m32 -
                    a.m13 * a.m22 * a.m31 -
                    a.m11 * a.m23 * a.m32 -
                    a.m12 * a.m21 * a.m33) -
           a.m01 * (a.m10 * a.m22 * a.m33 +
                    a.m12 * a.m23 * a.m30 +
                    a.m13 * a.m20 * a.m32 -
                    a.m13 * a.m22 * a.m30 -
                    a.m10 * a.m23 * a.m32 -
                    a.m12 * a.m20 * a.m33) +
           a.m02 * (a.m10 * a.m21 * a.m33 +
                    a.m11 * a.m23 * a.m30 +
                    a.m13 * a.m20 * a.m31 -
                    a.m13 * a.m21 * a.m30 -
                    a.m10 * a.m23 * a.m31 -
                    a.m11 * a.m20 * a.m33) -
           a.m03 * (a.m10 * a.m21 * a.m32 +
                    a.m11 * a.m22 * a.m30 +
                    a.m12 * a.m20 * a.m31 -
                    a.m12 * a.m21 * a.m30 -
                    a.m10 * a.m22 * a.m31 -
                    a.m11 * a.m20 * a.m32)
end

---Constructs a rotation matrix from an angle in radians
---around an arbitrary axis. Checks the magnitude of
---the axis and normalizes it. Returns the identity
---if the axis magnitude is zero.
---@param radians number angle
---@param ax number axis x
---@param ay number axis y
---@param az number axis z
---@return table
function Mat4.fromRotation(radians, ax, ay, az)
    local xv = ax or 0.0
    local yv = ay or 0.0
    local zv = az or 0.0
    local mSq = xv * xv + yv * yv + zv * zv
    if mSq ~= 0.0 then
        local mInv = 1.0 / math.sqrt(mSq)
        return Mat4.fromRotInternal(
            math.cos(radians),
            math.sin(radians),
            xv * mInv, yv * mInv, zv * mInv)
    else
        return Mat4.identity()
    end
end

---Constructs a rotation matrix from an angle in radians
---around the x axis.
---@param radians number angle
---@return table
function Mat4.fromRotX(radians)
    return Mat4.fromRotXInternal(
        math.cos(radians),
        math.sin(radians))
end

---Constructs a rotation matrix from an angle in radians
---around the y axis.
---@param radians number angle
---@return table
function Mat4.fromRotY(radians)
    return Mat4.fromRotYInternal(
        math.cos(radians),
        math.sin(radians))
end

---Constructs a rotation matrix from an angle in radians
---around the z axis.
---@param radians number angle
---@return table
function Mat4.fromRotZ(radians)
    return Mat4.fromRotZInternal(
        math.cos(radians),
        math.sin(radians))
end

---Constructs a rotation matrix from the cosine and sine
---of an angle around an arbitrary axis.
---Does not check if axis is well-formed.
---A well-formed axis should have unit length.
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@param ax number axis x
---@param ay number axis y
---@param az number axis z
---@return table
function Mat4.fromRotInternal(
    cosa, sina,
    ax, ay, az)

    local d = 1.0 - cosa
    local x = ax * d
    local y = ay * d
    local z = az * d

    local axay = x * ay
    local axaz = x * az
    local ayaz = y * az

    return Mat4.new(
        cosa + x * ax, axay - sina * az, axaz + sina * ay, 0.0,
        axay + sina * az, cosa + y * ay, ayaz - sina * ax, 0.0,
        axaz - sina * ay, ayaz + sina * ax, cosa + z * az, 0.0,
        0.0, 0.0, 0.0, 1.0)
end

---Constructs a rotation matrix from the cosine and sine
---of an angle around the x axis.
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return table
function Mat4.fromRotXInternal(cosa, sina)
    return Mat4.new(
        1.0,  0.0,   0.0, 0.0,
        0.0, cosa, -sina, 0.0,
        0.0, sina,  cosa, 0.0,
        0.0,  0.0,   0.0, 1.0)
end

---Constructs a rotation matrix from the cosine and sine
---of an angle around the y axis.
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return table
function Mat4.fromRotYInternal(cosa, sina)
    return Mat4.new(
         cosa, 0.0, sina, 0.0,
          0.0, 1.0,  0.0, 0.0,
        -sina, 0.0, cosa, 0.0,
          0.0, 0.0,  0.0, 1.0)
end

---Constructs a rotation matrix from the cosine and sine
---of an angle around the z axis.
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return table
function Mat4.fromRotZInternal(cosa, sina)
    return Mat4.new(
        cosa, -sina, 0.0, 0.0,
        sina,  cosa, 0.0, 0.0,
         0.0,   0.0, 1.0, 0.0,
         0.0,   0.0, 0.0, 1.0)
end

---Constructs a matrix from a nonuniform scale.
---@param width number width
---@param depth number depth
---@return table
function Mat4.fromScale(width, depth, height)
    local w = 1.0
    if width and width ~= 0.0 then
        w = width
    end

    local d = w
    if depth and depth ~= 0.0 then
        d = depth
    end

    local h = w
    if height and height ~= 0.0 then
        h = height
    end

    return Mat4.new(
          w, 0.0, 0.0, 0.0,
        0.0,   d, 0.0, 0.0,
        0.0, 0.0,   h, 0.0,
        0.0, 0.0, 0.0, 1.0)
end

---Constructs a matrix from a translation.
---@param x number x
---@param y number y
---@param z number z
---@return table
function Mat4.fromTranslation(x, y, z)
    local zv = z or 0.0
    return Mat4.new(
        1.0, 0.0, 0.0,   x,
        0.0, 1.0, 0.0,   y,
        0.0, 0.0, 1.0,  zv,
        0.0, 0.0, 0.0, 1.0)
end

---Finds the matrix inverse.
---Returns the identity if not possible.
---@param a table matrix
---@return table
function Mat4.inverse(a)
    local b00 = a.m00 * a.m11 - a.m01 * a.m10
    local b01 = a.m00 * a.m12 - a.m02 * a.m10
    local b02 = a.m00 * a.m13 - a.m03 * a.m10
    local b03 = a.m01 * a.m12 - a.m02 * a.m11
    local b04 = a.m01 * a.m13 - a.m03 * a.m11
    local b05 = a.m02 * a.m13 - a.m03 * a.m12
    local b06 = a.m20 * a.m31 - a.m21 * a.m30
    local b07 = a.m20 * a.m32 - a.m22 * a.m30
    local b08 = a.m20 * a.m33 - a.m23 * a.m30
    local b09 = a.m21 * a.m32 - a.m22 * a.m31
    local b10 = a.m21 * a.m33 - a.m23 * a.m31
    local b11 = a.m22 * a.m33 - a.m23 * a.m32

    local det = b00 * b11 - b01 * b10 +
                b02 * b09 + b03 * b08 -
                b04 * b07 + b05 * b06
    if det ~= 0.0 then
        local detInv = 1.0 / det
        return Mat4.new(
            (a.m11 * b11 - a.m12 * b10 + a.m13 * b09) * detInv,
            (a.m02 * b10 - a.m01 * b11 - a.m03 * b09) * detInv,
            (a.m31 * b05 - a.m32 * b04 + a.m33 * b03) * detInv,
            (a.m22 * b04 - a.m21 * b05 - a.m23 * b03) * detInv,
            (a.m12 * b08 - a.m10 * b11 - a.m13 * b07) * detInv,
            (a.m00 * b11 - a.m02 * b08 + a.m03 * b07) * detInv,
            (a.m32 * b02 - a.m30 * b05 - a.m33 * b01) * detInv,
            (a.m20 * b05 - a.m22 * b02 + a.m23 * b01) * detInv,
            (a.m10 * b10 - a.m11 * b08 + a.m13 * b06) * detInv,
            (a.m01 * b08 - a.m00 * b10 - a.m03 * b06) * detInv,
            (a.m30 * b04 - a.m31 * b02 + a.m33 * b00) * detInv,
            (a.m21 * b02 - a.m20 * b04 - a.m23 * b00) * detInv,
            (a.m11 * b07 - a.m10 * b09 - a.m12 * b06) * detInv,
            (a.m00 * b09 - a.m01 * b07 + a.m02 * b06) * detInv,
            (a.m31 * b01 - a.m30 * b03 - a.m32 * b00) * detInv,
            (a.m20 * b03 - a.m21 * b01 + a.m22 * b00) * detInv)
    else
        return Mat4.identity()
    end
end

---Finds the product of two matrices.
---@param a table left operand
---@param b table right operand
---@return table
function Mat4.mul(a, b)
    return Mat4.new(
        a.m00 * b.m00 + a.m01 * b.m10 + a.m02 * b.m20 + a.m03 * b.m30,
        a.m00 * b.m01 + a.m01 * b.m11 + a.m02 * b.m21 + a.m03 * b.m31,
        a.m00 * b.m02 + a.m01 * b.m12 + a.m02 * b.m22 + a.m03 * b.m32,
        a.m00 * b.m03 + a.m01 * b.m13 + a.m02 * b.m23 + a.m03 * b.m33,
        a.m10 * b.m00 + a.m11 * b.m10 + a.m12 * b.m20 + a.m13 * b.m30,
        a.m10 * b.m01 + a.m11 * b.m11 + a.m12 * b.m21 + a.m13 * b.m31,
        a.m10 * b.m02 + a.m11 * b.m12 + a.m12 * b.m22 + a.m13 * b.m32,
        a.m10 * b.m03 + a.m11 * b.m13 + a.m12 * b.m23 + a.m13 * b.m33,
        a.m20 * b.m00 + a.m21 * b.m10 + a.m22 * b.m20 + a.m23 * b.m30,
        a.m20 * b.m01 + a.m21 * b.m11 + a.m22 * b.m21 + a.m23 * b.m31,
        a.m20 * b.m02 + a.m21 * b.m12 + a.m22 * b.m22 + a.m23 * b.m32,
        a.m20 * b.m03 + a.m21 * b.m13 + a.m22 * b.m23 + a.m23 * b.m33,
        a.m30 * b.m00 + a.m31 * b.m10 + a.m32 * b.m20 + a.m33 * b.m30,
        a.m30 * b.m01 + a.m31 * b.m11 + a.m32 * b.m21 + a.m33 * b.m31,
        a.m30 * b.m02 + a.m31 * b.m12 + a.m32 * b.m22 + a.m33 * b.m32,
        a.m30 * b.m03 + a.m31 * b.m13 + a.m32 * b.m23 + a.m33 * b.m33)
end

---Negates a matrix.
---@param a table matrix
---@return table
function Mat4.negate(a)
    return Mat4.new(
        -a.m00, -a.m01, -a.m02, -a.m03,
        -a.m10, -a.m11, -a.m12, -a.m13,
        -a.m20, -a.m21, -a.m22, -a.m23,
        -a.m30, -a.m31, -a.m32, -a.m33)
end

---Creates an orthographic projection matrix.
---@param left number left edge
---@param right number right edge
---@param bottom number bottom edge
---@param top number top edge
---@param near number near clip plane
---@param far number far clip plane
---@return table
function Mat4.orthographic(
    left, right,
    bottom, top,
    near, far)

    local nVal = 0.001
    if near and near ~= 0.0 then nVal = near end

    local fVal = 1000.0
    if far and far ~= 0.0 then fVal = far end

    local w = right - left
    local h = top - bottom
    local d = fVal - nVal

    local wInv = 1.0
    local hInv = 1.0
    local dInv = 1.0

    if w ~= 0.0 then wInv = 1.0 / w end
    if h ~= 0.0 then hInv = 1.0 / h end
    if d ~= 0.0 then dInv = 1.0 / d end

    return Mat4.new(
        wInv + wInv, 0.0, 0.0, wInv * (left + right),
        0.0, hInv + hInv, 0.0, hInv * (top + bottom),
        0.0, 0.0, -(dInv + dInv), -dInv * (fVal + nVal),
        0.0, 0.0, 0.0, 1.0)
end

---Creates a perspective projection matrix.
---@param fov number field of view
---@param aspect number aspect ratio
---@param near number near clip plane
---@param far number far clip plane
---@return table
function Mat4.perspective(fov, aspect, near, far)
    local fovVal = 0.8660254037844386
    if fov and fov ~= 0.0 then fovVal = fov end

    local aVal = 1.0
    if aspect and aspect ~= 0.0 then aVal = aspect end

    local nVal = 0.001
    if near and near ~= 0.0 then nVal = near end

    local fVal = 1000.0
    if far and far ~= 0.0 then fVal = far end

    local tanFov = math.tan(fovVal * 0.5)
    local cotFov = 1.0 / tanFov
    local d = fVal - nVal
    local dInv = 1.0
    if d ~= 0.0 then dInv = 1.0 / d end

    return Mat4.new(
        cotFov / aVal, 0.0, 0.0, 0.0,
        0.0, cotFov, 0.0, 0.0,
        0.0, 0.0, (fVal + nVal) * -dInv,
        (nVal + nVal) * fVal * -dInv,
        0.0, 0.0, -1.0, 0.0)
end

---Subtracts the right matrix from the left.
---@param a table left operand
---@param b table right operand
---@return table
function Mat4.sub(a, b)
    return Mat4.new(
        a.m00 - b.m00, a.m01 - b.m01, a.m02 - b.m02, a.m03 - b.m03,
        a.m10 - b.m10, a.m11 - b.m11, a.m12 - b.m12, a.m13 - b.m13,
        a.m20 - b.m20, a.m21 - b.m21, a.m22 - b.m22, a.m23 - b.m23,
        a.m30 - b.m30, a.m31 - b.m31, a.m32 - b.m32, a.m33 - b.m33)
end

---Returns a JSON string of a matrix.
---@param a table matrix
---@return string
function Mat4.toJson(a)
    local m0 = string.format(
        "{\"m00\":%.4f,\"m01\":%.4f,\"m02\":%.4f,\"m03\":%.4f,",
        a.m00, a.m01, a.m02, a.m03)
    local m1 = string.format(
        "\"m10\":%.4f,\"m11\":%.4f,\"m12\":%.4f,\"m13\":%.4f,",
        a.m10, a.m11, a.m12, a.m13)
    local m2 = string.format(
        "\"m20\":%.4f,\"m21\":%.4f,\"m22\":%.4f,\"m23\":%.4f,",
        a.m20, a.m21, a.m22, a.m23)
    local m3 = string.format(
        "\"m30\":%.4f,\"m31\":%.4f,\"m32\":%.4f,\"m33\":%.4f}",
        a.m30, a.m31, a.m32, a.m33)
    return m0 .. m1 .. m2 .. m3
end

---Transposes a matrix's columns and rows.
---@param a table matrix
---@return table
function Mat4.transpose(a)
    return Mat4.new(
        a.m00, a.m10, a.m20, a.m30,
        a.m01, a.m11, a.m21, a.m31,
        a.m02, a.m12, a.m22, a.m32,
        a.m03, a.m13, a.m23, a.m33)
end

---Creates the identity matrix.
---@return table
function Mat4.identity()
    return Mat4.new(
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0)
end

return Mat4