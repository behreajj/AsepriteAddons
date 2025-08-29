dofile("./utilities.lua")

NormalUtilities = {}
NormalUtilities.__index = NormalUtilities

setmetatable(NormalUtilities, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Returns a copy of the source image that has been flipped horizontally.
---@param source Image source image
---@return Image
---@nodiscard
function NormalUtilities.flipImageX(source)
    local srcSpec <const> = source.spec
    local colorMode <const> = srcSpec.colorMode
    if colorMode ~= ColorMode.RGB then return source end

    local wSrc <const> = srcSpec.width
    local hSrc <const> = srcSpec.height
    local srcBytes <const> = Utilities.flipPixelsX(source.bytes,
        wSrc, hSrc, source.bytesPerPixel)

    ---@type string[]
    local normBytesArr <const> = {}
    ---@type table<integer, integer>
    local srcToTrg <const> = {}
    local lenTrg <const> = wSrc * hSrc

    -- Cache methods used in looop.
    local strpack <const> = string.pack
    local strsub <const> = string.sub
    local strunpack <const> = string.unpack
    local v3new <const> = Vec3.new
    local fromHex <const> = Rgb.fromHexAbgr32
    local toHex <const> = Rgb.toHex
    local toVec3 <const> = NormalUtilities.rgbToVec3
    local toRgb <const> = NormalUtilities.vec3ToRgb

    local i = 0
    while i < lenTrg do
        local i4 <const> = i * 4
        local srcAbgr32 <const> = strunpack("<I4", strsub(
            srcBytes, 1 + i4, 4 + i4))

        local transformed = srcToTrg[srcAbgr32]
        if not transformed then
            local rgb <const> = fromHex(srcAbgr32)
            local v <const>, _ <const> = toVec3(rgb)
            local rgbTr <const>, _ <const> = toRgb(
                v3new(-v.x, v.y, v.z), rgb.a)
            transformed = toHex(rgbTr)
            srcToTrg[srcAbgr32] = transformed
        end

        i = i + 1
        normBytesArr[i] = strpack("<I4", transformed)
    end

    local target <const> = Image(srcSpec)
    target.bytes = table.concat(normBytesArr)
    return target
end

---Returns a copy of the source image that has been flipped vertically.
---@param source Image source image
---@return Image
---@nodiscard
function NormalUtilities.flipImageY(source)
    local srcSpec <const> = source.spec
    local colorMode <const> = srcSpec.colorMode
    if colorMode ~= ColorMode.RGB then return source end

    local wSrc <const> = srcSpec.width
    local hSrc <const> = srcSpec.height
    local srcBytes <const> = Utilities.flipPixelsY(source.bytes,
        wSrc, hSrc, source.bytesPerPixel)

    ---@type string[]
    local normBytesArr <const> = {}
    ---@type table<integer, integer>
    local srcToTrg <const> = {}
    local lenTrg <const> = wSrc * hSrc

    -- Cache methods used in looop.
    local strpack <const> = string.pack
    local strsub <const> = string.sub
    local strunpack <const> = string.unpack
    local v3new <const> = Vec3.new
    local fromHex <const> = Rgb.fromHexAbgr32
    local toHex <const> = Rgb.toHex
    local toVec3 <const> = NormalUtilities.rgbToVec3
    local toRgb <const> = NormalUtilities.vec3ToRgb

    local i = 0
    while i < lenTrg do
        local i4 <const> = i * 4
        local srcAbgr32 <const> = strunpack("<I4", strsub(
            srcBytes, 1 + i4, 4 + i4))

        local transformed = srcToTrg[srcAbgr32]
        if not transformed then
            local rgb <const> = fromHex(srcAbgr32)
            local v <const>, _ <const> = toVec3(rgb)
            local rgbTr <const>, _ <const> = toRgb(
                v3new(v.x, -v.y, v.z), rgb.a)
            transformed = toHex(rgbTr)
            srcToTrg[srcAbgr32] = transformed
        end

        i = i + 1
        normBytesArr[i] = strpack("<I4", transformed)
    end

    local target <const> = Image(srcSpec)
    target.bytes = table.concat(normBytesArr)
    return target
end

---Converts colors in an image to a vector, then converts them back,
---ensuring colors conform to a normal map.
---@param source Image source image
---@return Image
function NormalUtilities.normalizeImage(source)
    local srcSpec <const> = source.spec
    local colorMode <const> = srcSpec.colorMode
    if colorMode ~= ColorMode.RGB then return source end

    ---@type string[]
    local normBytesArr <const> = {}
    ---@type table<integer, integer>
    local srcToTrg <const> = {}

    local srcBytes <const> = source.bytes
    local wSrc <const> = srcSpec.width
    local hSrc <const> = srcSpec.height
    local lenTrg <const> = wSrc * hSrc

    -- Cache methods used in looop.
    local strpack <const> = string.pack
    local strsub <const> = string.sub
    local strunpack <const> = string.unpack

    local fromHex <const> = Rgb.fromHexAbgr32
    local toHex <const> = Rgb.toHex
    local toVec3 <const> = NormalUtilities.rgbToVec3
    local toRgb <const> = NormalUtilities.vec3ToRgb

    local i = 0
    while i < lenTrg do
        local i4 <const> = i * 4
        local srcAbgr32 <const> = strunpack("<I4", strsub(
            srcBytes, 1 + i4, 4 + i4))

        local transformed = srcToTrg[srcAbgr32]
        if not transformed then
            local rgb <const> = fromHex(srcAbgr32)
            local v <const>, _ <const> = toVec3(rgb)
            transformed = rgb.a > 0.0 and toHex(toRgb(v, rgb.a)) or 0
            srcToTrg[srcAbgr32] = transformed
        end

        i = i + 1
        normBytesArr[i] = strpack("<I4", transformed)
    end

    local target <const> = Image(srcSpec)
    target.bytes = table.concat(normBytesArr)
    return target
end

---Returns a copy of the source image that has been resized to the width and
---height. Uses nearest neighbor sampling. If the width and height are equal to
---the original, then returns the source image by reference.
---Not intended for use when upscaling images on export.
---@param source Image source image
---@param wTrg integer resized width
---@param hTrg integer resized height
---@return Image
---@nodiscard
function NormalUtilities.resizeImageNearest(source, wTrg, hTrg)
    local srcSpec <const> = source.spec
    local colorMode <const> = srcSpec.colorMode
    if colorMode ~= ColorMode.RGB then return source end

    local wSrc <const> = srcSpec.width
    local hSrc <const> = srcSpec.height
    local wVrf <const> = math.max(1, math.abs(wTrg))
    local hVrf <const> = math.max(1, math.abs(hTrg))

    if wVrf == wSrc and hVrf == hSrc then
        return NormalUtilities.normalizeImage(source)
    end

    local alphaIndex <const> = srcSpec.transparentColor
    local bytesRsz <const> = Utilities.resizePixelsNearest(
        source.bytes, wSrc, hSrc, wVrf, hVrf, source.bytesPerPixel, alphaIndex)

    ---@type string[]
    local normBytesArr <const> = {}
    ---@type table<integer, integer>
    local srcToTrg <const> = {}
    local lenTrg <const> = wVrf * hVrf

    -- To transform normals, the inverse of the scalar is used,
    -- but the original scale also has to be accounted for.
    local denom <const> = Vec3.new(wSrc / wVrf, hSrc / hVrf, 1.0)

    -- Cache methods used in looop.
    local strpack <const> = string.pack
    local strsub <const> = string.sub
    local strunpack <const> = string.unpack
    local fromHex <const> = Rgb.fromHexAbgr32
    local toHex <const> = Rgb.toHex
    local toVec3 <const> = NormalUtilities.rgbToVec3
    local toRgb <const> = NormalUtilities.vec3ToRgb
    local hadamard <const> = Vec3.hadamard

    local i = 0
    while i < lenTrg do
        local i4 <const> = i * 4
        local srcAbgr32 <const> = strunpack("<I4", strsub(
            bytesRsz, 1 + i4, 4 + i4))

        local transformed = srcToTrg[srcAbgr32]
        if not transformed then
            local rgb <const> = fromHex(srcAbgr32)
            local v <const>, _ <const> = toVec3(rgb)
            local rgbTr <const>, _ <const> = toRgb(
                hadamard(v, denom), rgb.a)
            transformed = toHex(rgbTr)
            srcToTrg[srcAbgr32] = transformed
        end

        i = i + 1
        normBytesArr[i] = strpack("<I4", transformed)
    end

    local trgSpec <const> = ImageSpec {
        width = wVrf,
        height = hVrf,
        colorMode = colorMode,
        transparentColor = alphaIndex
    }
    trgSpec.colorSpace = srcSpec.colorSpace
    local target <const> = Image(trgSpec)
    target.bytes = table.concat(normBytesArr)
    return target
end

---Converts an rgb color to a normal, stored in a Vec3.
---If the color's alpha is zero, returns up.
---If the normal's magnitude is approximately zero, returns up.
---The boolean indicates the validity of the conversion.
---@param rgb Rgb color
---@return Vec3 converted
---@return boolean isValid
function NormalUtilities.rgbToVec3(rgb)
    -- TODO: Can this be used in other normal dialogs, like color picker?

    if rgb.a > 0.0 then
        local x <const> = rgb.r * 2.0 - 1.0
        local y <const> = rgb.g * 2.0 - 1.0
        local z <const> = rgb.b * 2.0 - 1.0
        local mSq <const> = x * x + y * y + z * z
        if mSq > 0.0000462 then
            local mInv <const> = 1.0 / math.sqrt(mSq)
            return Vec3.new(x * mInv, y * mInv, z * mInv), true
        end
    end
    return Vec3.new(0.0, 0.0, 1.0), false
end

---Returns a copy of the source image that has been rotated 90 degrees
---counter clockwise.
---@param source Image source image
---@return Image
---@nodiscard
function NormalUtilities.rotateImage90(source)
    local srcSpec <const> = source.spec
    local colorMode <const> = srcSpec.colorMode
    if colorMode ~= ColorMode.RGB then return source end

    local wSrc <const> = srcSpec.width
    local hSrc <const> = srcSpec.height
    local srcBytes <const> = Utilities.rotatePixels270(
        source.bytes, wSrc, hSrc, source.bytesPerPixel)

    ---@type string[]
    local normBytesArr <const> = {}
    ---@type table<integer, integer>
    local srcToTrg <const> = {}
    local lenTrg <const> = wSrc * hSrc

    -- Cache methods used in looop.
    local strpack <const> = string.pack
    local strsub <const> = string.sub
    local strunpack <const> = string.unpack
    local v3new <const> = Vec3.new
    local fromHex <const> = Rgb.fromHexAbgr32
    local toHex <const> = Rgb.toHex
    local toVec3 <const> = NormalUtilities.rgbToVec3
    local toRgb <const> = NormalUtilities.vec3ToRgb

    local i = 0
    while i < lenTrg do
        local i4 <const> = i * 4
        local srcAbgr32 <const> = strunpack("<I4", strsub(
            srcBytes, 1 + i4, 4 + i4))

        local transformed = srcToTrg[srcAbgr32]
        if not transformed then
            local rgb <const> = fromHex(srcAbgr32)
            local v <const>, _ <const> = toVec3(rgb)
            local rgbTr <const>, _ <const> = toRgb(
                v3new(-v.y, v.x, v.z), rgb.a)
            transformed = toHex(rgbTr)
            srcToTrg[srcAbgr32] = transformed
        end

        i = i + 1
        normBytesArr[i] = strpack("<I4", transformed)
    end

    local trgSpec <const> = ImageSpec {
        width = hSrc,
        height = wSrc,
        colorMode = colorMode,
        transparentColor = srcSpec.transparentColor
    }
    trgSpec.colorSpace = srcSpec.colorSpace
    local target <const> = Image(trgSpec)
    target.bytes = table.concat(normBytesArr)
    return target
end

---Returns a copy of the source image that has been rotated 180 degrees.
---@param source Image source image
---@return Image
---@nodiscard
function NormalUtilities.rotateImage180(source)
    local srcSpec <const> = source.spec
    local colorMode <const> = srcSpec.colorMode
    if colorMode ~= ColorMode.RGB then return source end

    local wSrc <const> = srcSpec.width
    local hSrc <const> = srcSpec.height
    local srcBytes <const> = Utilities.rotatePixels180(
        source.bytes, wSrc, hSrc, source.bytesPerPixel)

    ---@type string[]
    local normBytesArr <const> = {}
    ---@type table<integer, integer>
    local srcToTrg <const> = {}
    local lenTrg <const> = wSrc * hSrc

    -- Cache methods used in looop.
    local strpack <const> = string.pack
    local strsub <const> = string.sub
    local strunpack <const> = string.unpack
    local v3new <const> = Vec3.new
    local fromHex <const> = Rgb.fromHexAbgr32
    local toHex <const> = Rgb.toHex
    local toVec3 <const> = NormalUtilities.rgbToVec3
    local toRgb <const> = NormalUtilities.vec3ToRgb

    local i = 0
    while i < lenTrg do
        local i4 <const> = i * 4
        local srcAbgr32 <const> = strunpack("<I4", strsub(
            srcBytes, 1 + i4, 4 + i4))

        local transformed = srcToTrg[srcAbgr32]
        if not transformed then
            local rgb <const> = fromHex(srcAbgr32)
            local v <const>, _ <const> = toVec3(rgb)
            local rgbTr <const>, _ <const> = toRgb(v3new(-v.x, -v.y, v.z), rgb.a)
            transformed = toHex(rgbTr)
            srcToTrg[srcAbgr32] = transformed
        end

        i = i + 1
        normBytesArr[i] = strpack("<I4", transformed)
    end

    local target <const> = Image(srcSpec)
    target.bytes = table.concat(normBytesArr)
    return target
end

---Returns a copy of the source image that has been rotated 270 degrees
---counter clockwise.
---@param source Image source image
---@return Image
---@nodiscard
function NormalUtilities.rotateImage270(source)
    local srcSpec <const> = source.spec
    local colorMode <const> = srcSpec.colorMode
    if colorMode ~= ColorMode.RGB then return source end

    local wSrc <const> = srcSpec.width
    local hSrc <const> = srcSpec.height
    local srcBytes <const> = Utilities.rotatePixels270(
        source.bytes, wSrc, hSrc, source.bytesPerPixel)

    ---@type string[]
    local normBytesArr <const> = {}
    ---@type table<integer, integer>
    local srcToTrg <const> = {}
    local lenTrg <const> = wSrc * hSrc

    -- Cache methods used in looop.
    local strpack <const> = string.pack
    local strsub <const> = string.sub
    local strunpack <const> = string.unpack
    local v3new <const> = Vec3.new
    local fromHex <const> = Rgb.fromHexAbgr32
    local toHex <const> = Rgb.toHex
    local toVec3 <const> = NormalUtilities.rgbToVec3
    local toRgb <const> = NormalUtilities.vec3ToRgb

    local i = 0
    while i < lenTrg do
        local i4 <const> = i * 4
        local srcAbgr32 <const> = strunpack("<I4", strsub(
            srcBytes, 1 + i4, 4 + i4))

        local transformed = srcToTrg[srcAbgr32]
        if not transformed then
            local rgb <const> = fromHex(srcAbgr32)
            local v <const>, _ <const> = toVec3(rgb)
            local rgbTr <const>, _ <const> = toRgb(
                v3new(v.y, -v.x, v.z), rgb.a)
            transformed = toHex(rgbTr)
            srcToTrg[srcAbgr32] = transformed
        end

        i = i + 1
        normBytesArr[i] = strpack("<I4", transformed)
    end

    local trgSpec <const> = ImageSpec {
        width = hSrc,
        height = wSrc,
        colorMode = colorMode,
        transparentColor = srcSpec.transparentColor
    }
    trgSpec.colorSpace = srcSpec.colorSpace
    local target <const> = Image(trgSpec)
    target.bytes = table.concat(normBytesArr)
    return target
end

---Returns a copy of the source image that has been rotated counter
---clockwise around the z axis by an angle in degrees. Uses nearest
---neighbor sampling. If the angle is 0 degrees, then returns the
---source image by reference. If the angle is 90, 180 or 270 degrees,
---then defers to orthogonal rotations.
---@param source Image source image
---@param angle number angle in degrees
---@return Image
---@nodiscard
function NormalUtilities.rotateImageZ(source, angle)
    local deg <const> = Utilities.round(angle) % 360

    if deg == 0 then
        return NormalUtilities.normalizeImage(source)
    elseif deg == 90 then
        return NormalUtilities.rotateImage90(source)
    elseif deg == 180 then
        return NormalUtilities.rotateImage180(source)
    elseif deg == 270 then
        return NormalUtilities.rotateImage270(source)
    end

    local radians <const> = angle * 0.017453292519943
    return NormalUtilities.rotateImageZInternal(source,
        math.cos(radians), math.sin(radians))
end

---Internal helper function to rotateZ. Accepts pre-calculated cosine
---and sine of an angle.
---@param source Image source image
---@param cosa number sine of angle
---@param sina number cosine of angle
---@return Image
---@nodiscard
function NormalUtilities.rotateImageZInternal(source, cosa, sina)
    local srcSpec <const> = source.spec
    local colorMode <const> = srcSpec.colorMode
    if colorMode ~= ColorMode.RGB then return source end

    local alphaIndex <const> = srcSpec.transparentColor
    local srcBytes <const>,
    wSrc <const>,
    hSrc <const> = Utilities.rotatePixelsZ(
        source.bytes, srcSpec.width, srcSpec.height,
        cosa, sina, source.bytesPerPixel, alphaIndex)

    ---@type string[]
    local normBytesArr <const> = {}
    ---@type table<integer, integer>
    local srcToTrg <const> = {}
    local lenTrg <const> = wSrc * hSrc

    -- Cache methods used in looop.
    local strpack <const> = string.pack
    local strsub <const> = string.sub
    local strunpack <const> = string.unpack

    -- While this could be generalized to use Vec3 rotate axis,
    -- there's no general rotate axis for the image pixel
    -- locations anyway.
    local rotz <const> = Vec3.rotateZInternal
    local fromHex <const> = Rgb.fromHexAbgr32
    local toHex <const> = Rgb.toHex
    local toVec3 <const> = NormalUtilities.rgbToVec3
    local toRgb <const> = NormalUtilities.vec3ToRgb

    local i = 0
    while i < lenTrg do
        local i4 <const> = i * 4
        local srcAbgr32 <const> = strunpack("<I4", strsub(
            srcBytes, 1 + i4, 4 + i4))

        local transformed = srcToTrg[srcAbgr32]
        if not transformed then
            local rgb <const> = fromHex(srcAbgr32)
            local v <const>, _ <const> = toVec3(rgb)
            local rgbTr <const>, _ <const> = toRgb(
                rotz(v, cosa, sina), rgb.a)
            transformed = toHex(rgbTr)
            srcToTrg[srcAbgr32] = transformed
        end

        i = i + 1
        normBytesArr[i] = strpack("<I4", transformed)
    end

    local trgSpec <const> = ImageSpec {
        width = wSrc,
        height = hSrc,
        colorMode = colorMode,
        transparentColor = alphaIndex
    }
    trgSpec.colorSpace = srcSpec.colorSpace
    local target <const> = Image(trgSpec)
    target.bytes = table.concat(normBytesArr)
    return target
end

---Converts a vector to a color, stored in an Rgb.
---If the vector's magnitude is approximately zero, returns up.
---If the alpha is zero, returns clear black.
---The boolean indicates the validity of the conversion.
---@param v Vec3 vector
---@param alpha? number opacity
---@return Rgb converted
---@return boolean isValid
function NormalUtilities.vec3ToRgb(v, alpha)
    -- TODO: Can this be used in other normal dialogs, like color picker?
    local aVerif <const> = alpha or 1.0
    if aVerif <= 0.0 then
        return Rgb.new(0.0, 0.0, 0.0, 0.0), false
    end

    local mSq <const> = Vec3.magSq(v)
    if mSq > 0.0000462 then
        local mInv <const> = 1.0 / math.sqrt(mSq)
        return Rgb.new(
            (v.x * mInv) * 0.5 + 0.5,
            (v.y * mInv) * 0.5 + 0.5,
            (v.z * mInv) * 0.5 + 0.5,
            aVerif), true
    end
    return Rgb.new(0.5, 0.5, 1.0, aVerif), false
end

return NormalUtilities