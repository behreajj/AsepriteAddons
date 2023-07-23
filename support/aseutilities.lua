dofile("./utilities.lua")
dofile("./clr.lua")

AseUtilities = {}
AseUtilities.__index = AseUtilities

setmetatable(AseUtilities, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

-- Maximum number of a cels a script may
-- request to create before the user is
-- prompted to confirm.
AseUtilities.CEL_COUNT_LIMIT = 256

---Default palette used when no other
---is available. Simulates a RYB
---color wheel with black and white.
AseUtilities.DEFAULT_PAL_ARR = {
    0x00000000, -- Mask
    0xff000000, -- Black
    0xffffffff, -- White
    0xff3a3adc,
    0xff2a7af2,
    0xff14aefe,
    0xff19ddfd,
    0xff1ddbca,
    0xff3cc286,
    0xff699d03,
    0xff968e00,
    0xff9c7300,
    0xff9c5a02,
    0xff793162,
    0xff581b99
}

---Angles in degrees which are remapped to
---permutations of atan(1,2) and atan(1,3).
AseUtilities.DIMETRIC_ANGLES = {
    [18] = 0.32175055439664,
    [19] = 0.32175055439664,
    [26] = 0.46364760900081,
    [27] = 0.46364760900081,
    [63] = 1.1071487177940904,
    [64] = 1.1071487177940904,
    [71] = 1.2490457723983,
    [72] = 1.2490457723983,
    [108] = 1.8925468811915,
    [109] = 1.8925468811915,
    [116] = 2.0344439357957,
    [117] = 2.0344439357957,
    [153] = 2.677945044589,
    [154] = 2.677945044589,
    [161] = 2.8198420991932,
    [162] = 2.8198420991932,
    [198] = 3.4633432079864,
    [199] = 3.4633432079864,
    [206] = 3.6052402625906,
    [207] = 3.6052402625906,
    [243] = 4.2487413713839,
    [244] = 4.2487413713839,
    [251] = 4.390638425988,
    [252] = 4.390638425988,
    [288] = 5.0341395347813,
    [289] = 5.0341395347813,
    [296] = 5.1760365893855,
    [297] = 5.1760365893855,
    [333] = 5.8195376981788,
    [334] = 5.8195376981788,
    [341] = 5.9614347527829,
    [342] = 5.9614347527829
}

---Number of decimals to display when
---printing real numbers to the console.
AseUtilities.DISPLAY_DECIMAL = 3

---Table of file extensions supported by
---Aseprite for open and save file dialogs.
AseUtilities.FILE_FORMATS = {
    "ase", "aseprite", "bmp", "flc", "fli",
    "gif", "ico", "jpeg", "jpg", "pcc", "pcx",
    "png", "tga", "webp"
}

-- Maximum number of frames a script may
-- request to create before the user is
-- prompted to confirm.
AseUtilities.FRAME_COUNT_LIMIT = 256

-- Number of swatches to generate for
-- gray color mode sprites.
AseUtilities.GRAY_COUNT = 32

-- Maximum number of layers a script may
-- request to create before the user is
-- prompted to confirm.
AseUtilities.LAYER_COUNT_LIMIT = 96

---Camera projections.
AseUtilities.PROJECTIONS = {
    "ORTHO",
    "PERSPECTIVE"
}

---Houses utility methods for scripting
---Aseprite add-ons.
---@return table
function AseUtilities.new()
    local inst = setmetatable({}, AseUtilities)
    return inst
end

---Appends the child layers of a layer if it is a group
---to an array. If the layer is not a group, then whther
---it's appended depends on the arguments provided.
---@param layer Layer parent layer
---@param array Layer[] leaves array
---@param includeLocked? boolean include locked layers
---@param includeHidden? boolean include hidden layers
---@param includeTiles? boolean include tile maps
---@param includeBkg? boolean include backgrounds
---@return Layer[]
function AseUtilities.appendLeaves(
    layer, array,
    includeLocked, includeHidden,
    includeTiles, includeBkg)
    -- First check properties which are passed on by parents
    -- to their children.
    if (includeLocked or layer.isEditable)
        and (includeHidden or layer.isVisible) then
        if layer.isGroup then
            local append <const> = AseUtilities.appendLeaves
            local childLayers <const> = layer.layers --[[@as Layer]]
            local lenChildLayers <const> = #childLayers
            local i = 0
            while i < lenChildLayers do
                i = i + 1
                append(childLayers[i], array,
                    includeLocked, includeHidden,
                    includeTiles, includeBkg)
            end
        elseif (not layer.isReference)
            and (includeTiles or (not layer.isTilemap))
            and (includeBkg or (not layer.isBackground)) then
            -- Leaf order should be what's ideal for composition,
            -- with ascending stack indices.
            table.insert(array, layer)
        end
    end
    return array
end

---Finds the average color of a selection in a sprite.
---Calculates in the SR LAB 2 color space.
---@param sprite Sprite
---@param frame Frame|integer
---@return { l: number, a: number, b: number, alpha: number }
function AseUtilities.averageColor(sprite, frame)
    if not sprite then
        return { l = 0.0, a = 0.0, b = 0.0, alpha = 0.0 }
    end

    local sel <const> = AseUtilities.getSelection(sprite)
    local selBounds <const> = sel.bounds
    local xSel <const> = selBounds.x
    local ySel <const> = selBounds.y

    local sprSpec <const> = sprite.spec
    local colorMode <const> = sprSpec.colorMode
    local selSpec <const> = ImageSpec {
        width = math.max(1, selBounds.width),
        height = math.max(1, selBounds.height),
        colorMode = colorMode,
        transparentColor = sprSpec.transparentColor
    }
    selSpec.colorSpace = sprSpec.colorSpace

    local flatImage <const> = Image(selSpec)
    flatImage:drawSprite(
        sprite, frame, Point(-xSel, -ySel))

    local eval = nil
    local palette = nil
    if colorMode == ColorMode.RGB then
        eval = function(h, d)
            if (h & 0xff000000) ~= 0 then
                local q <const> = d[h]
                if q then d[h] = q + 1 else d[h] = 1 end
            end
        end
    elseif colorMode == ColorMode.GRAY then
        eval = function(gray, d)
            local a = (gray >> 0x08) & 0xff
            if a > 0 then
                local v <const> = gray & 0xff
                local h <const> = a << 0x18 | v << 0x10 | v << 0x08 | v
                local q <const> = d[h]
                if q then d[h] = q + 1 else d[h] = 1 end
            end
        end
    elseif colorMode == ColorMode.INDEXED then
        if not frame then
            return { l = 0.0, a = 0.0, b = 0.0, alpha = 0.0 }
        end

        palette = AseUtilities.getPalette(
            frame, sprite.palettes)

        eval = function(idx, d, pal)
            if idx > -1 and idx < #pal then
                local aseColor <const> = pal:getColor(idx)
                local a <const> = aseColor.alpha
                if a > 0 then
                    local h <const> = aseColor.rgbaPixel
                    local q <const> = d[h]
                    if q then d[h] = q + 1 else d[h] = 1 end
                end
            end
        end
    else
        return { l = 0.0, a = 0.0, b = 0.0, alpha = 0.0 }
    end

    -- The key is the color in hex; the value is a
    -- number of pixels with that color in the
    -- selection. This tally is for the average.
    ---@type table<integer, integer>
    local hexDict <const> = {}
    local pxItr <const> = flatImage:pixels()
    for pixel in pxItr do
        local x <const> = pixel.x + xSel
        local y <const> = pixel.y + ySel
        if sel:contains(x, y) then
            eval(pixel(), hexDict, palette)
        end
    end

    -- Cache methods used in loop.
    local fromHex <const> = Clr.fromHex
    local sRgbToLab <const> = Clr.sRgbToSrLab2

    local lSum = 0.0
    local aSum = 0.0
    local bSum = 0.0
    local alphaSum = 0.0
    local count = 0

    for k, v in pairs(hexDict) do
        local srgb <const> = fromHex(k)
        local lab <const> = sRgbToLab(srgb)
        lSum = lSum + lab.l * v
        aSum = aSum + lab.a * v
        bSum = bSum + lab.b * v
        alphaSum = alphaSum + lab.alpha * v
        count = count + v
    end

    if alphaSum > 0 and count > 0 then
        local countInv <const> = 1.0 / count
        return {
            l = lSum * countInv,
            a = aSum * countInv,
            b = bSum * countInv,
            alpha = alphaSum * countInv
        }
    end

    return { l = 0.0, a = 0.0, b = 0.0, alpha = 0.0 }
end

---Copies an Aseprite Color object by sRGB channel
---values. This is to prevent accidental pass by
---reference. The Color constructor does no bounds
---boundary checking for [0, 255].
---If the flag is "UNBOUNDED", then the raw values
---are used.
---If the flag is "MODULAR," this will copy by
---hexadecimal value, and hence use modular
---arithmetic.
---The default is saturation arithmetic.
---For more info, see
---https://www.wikiwand.com/en/Modular_arithmetic .
---@param aseColor Color aseprite color
---@param flag string out of bounds interpretation
---@return Color
function AseUtilities.aseColorCopy(aseColor, flag)
    if flag == "UNBOUNDED" then
        return Color {
            r = aseColor.red,
            g = aseColor.green,
            b = aseColor.blue,
            a = aseColor.alpha
        }
    elseif flag == "MODULAR" then
        return AseUtilities.hexToAseColor(
            AseUtilities.aseColorToHex(aseColor, ColorMode.RGB))
    else
        return Color {
            r = math.min(math.max(aseColor.red, 0), 255),
            g = math.min(math.max(aseColor.green, 0), 255),
            b = math.min(math.max(aseColor.blue, 0), 255),
            a = math.min(math.max(aseColor.alpha, 0), 255)
        }
    end
end

---Converts an Aseprite Color object to a Clr.
---Assumes that the Aseprite Color is in sRGB.
---Both Aseprite Color and Clr allow arguments
---to exceed the expected ranges, [0, 255] and
---[0.0, 1.0], respectively.
---@param aseColor Color aseprite color
---@return Clr
function AseUtilities.aseColorToClr(aseColor)
    return Clr.new(
        0.003921568627451 * aseColor.red,
        0.003921568627451 * aseColor.green,
        0.003921568627451 * aseColor.blue,
        0.003921568627451 * aseColor.alpha)
end

---Converts an Aseprite color object to an
---integer. The meaning of the integer depends
---on the color mode: the RGB integer is 32
---bits; GRAY, 16; INDEXED, 8. For RGB mode,
---uses modular arithmetic, i.e., does not check
---if red, green, blue and alpha channels are out
---of range [0, 255]. Returns zero if the color
---mode is not recognized.
---@param clr Color aseprite color
---@param clrMode ColorMode|integer color mode
---@return integer
function AseUtilities.aseColorToHex(clr, clrMode)
    if clrMode == ColorMode.RGB then
        return (clr.alpha << 0x18)
            | (clr.blue << 0x10)
            | (clr.green << 0x08)
            | clr.red
    elseif clrMode == ColorMode.GRAY then
        return clr.grayPixel
    elseif clrMode == ColorMode.INDEXED then
        return clr.index
    end
    return 0
end

---Loads a palette based on a string. The string is
---expected to be either "FILE", "PRESET" or "ACTIVE".
---The correctZeroAlpha flag replaces zero alpha colors
---with clear black, regardless of RGB channel values.
---
---Returns a tuple of tables. The first table is an
---array of hexadecimals according to the sprite color
---profile. The second is a copy of the first converted
---to sRGB.
---
---If a palette is loaded from a filepath or a
---preset the two tables should match, as Aseprite does
---not support color management for palettes.
---@param palType string enumeration
---@param filePath string file path
---@param startIndex integer? start index
---@param count integer? count of colors to sample
---@param correctZeroAlpha boolean? alpha correction flag
---@return integer[]
---@return integer[]
function AseUtilities.asePaletteLoad(
    palType, filePath,
    startIndex, count,
    correctZeroAlpha)
    local hexesProfile = nil
    local hexesSrgb = nil

    if palType == "FILE" then
        if filePath and #filePath > 0 then
            local isFile <const> = app.fs.isFile(filePath)
            if isFile then
                -- Loading an .aseprite file with multiple palettes
                -- will register only the first palette. Also may be
                -- problems with color profiles being ignored.
                local palFile <const> = Palette { fromFile = filePath }
                if palFile then
                    local cntVrf <const> = count or 256
                    local siVrf <const> = startIndex or 0
                    hexesProfile = AseUtilities.asePaletteToHexArr(
                        palFile, siVrf, cntVrf)
                end
            end
        end
    elseif palType == "ACTIVE" then
        local palActSpr <const> = app.site.sprite
        if palActSpr then
            local modeAct <const> = palActSpr.colorMode
            if modeAct == ColorMode.GRAY then
                local grCntVrf = AseUtilities.GRAY_COUNT
                if count then grCntVrf = math.min(count, 256) end
                hexesProfile = AseUtilities.grayHexes(grCntVrf)
            else
                hexesProfile = AseUtilities.asePalettesToHexArr(
                    palActSpr.palettes)
                local profileAct <const> = palActSpr.colorSpace
                if profileAct then
                    -- Tests a number of color profile components for
                    -- approximate equality. See
                    -- https://github.com/aseprite/laf/blob/
                    -- 11ffdbd9cc6232faaff5eecd8cc628bb5a2c706f/
                    -- gfx/color_space.cpp#L142

                    -- It might be safer not to treat the NONE color
                    -- space as equivalent to SRGB, as the user could
                    -- have a display profile which differs radically.
                    local profileSrgb <const> = ColorSpace { sRGB = true }
                    if profileAct ~= profileSrgb then
                        palActSpr:convertColorSpace(profileSrgb)
                        hexesSrgb = AseUtilities.asePalettesToHexArr(
                            palActSpr.palettes)
                        palActSpr:convertColorSpace(profileAct)
                    end
                end
            end
        end
    end

    -- Malformed file path could lead to nil.
    if hexesProfile == nil then
        hexesProfile = {}
        local src <const> = AseUtilities.DEFAULT_PAL_ARR
        local lenSrc <const> = #src
        local i = 0
        while i < lenSrc do
            i = i + 1
            hexesProfile[i] = src[i]
        end
    end

    -- Copy by value as a precaution.
    if hexesSrgb == nil then
        hexesSrgb = {}
        local lenProf <const> = #hexesProfile
        local i = 0
        while i < lenProf do
            i = i + 1
            hexesSrgb[i] = hexesProfile[i]
        end
    end

    -- Replace colors, e.g., 0x00ff0000, so that all
    -- are clear black. Since both arrays should have
    -- the same length, avoid safety of separate loops.
    if correctZeroAlpha then
        local lenHexes <const> = #hexesProfile
        local i = 0
        while i < lenHexes do
            i = i + 1
            if (hexesProfile[i] & 0xff000000) == 0x0 then
                hexesProfile[i] = 0x0
                hexesSrgb[i] = 0x0
            end
        end
    end

    return hexesProfile, hexesSrgb
end

---Converts an Aseprite palette to a table of
---hex color integers. If the palette is nil
---returns a default table. Assumes palette
---is in sRGB. The start index defaults to 0.
---The count defaults to 256.
---@param pal Palette aseprite palette
---@param startIndex integer? start index
---@param count integer? sample count
---@return integer[]
function AseUtilities.asePaletteToHexArr(pal, startIndex, count)
    if pal then
        local lenPal <const> = #pal

        local si = startIndex or 0
        si = math.min(math.max(si, 0), lenPal - 1)
        local vc = count or 256
        vc = math.min(math.max(vc, 2), lenPal - si)

        ---@type integer[]
        local hexes <const> = {}
        local convert <const> = AseUtilities.aseColorToHex
        local rgbColorMode <const> = ColorMode.RGB
        local i = 0
        while i < vc do
            local aseColor <const> = pal:getColor(si + i)
            i = i + 1
            hexes[i] = convert(aseColor, rgbColorMode)
        end

        if #hexes == 1 then
            local amsk <const> = hexes[1] & 0xff000000
            table.insert(hexes, 1, amsk)
            hexes[3] = amsk | 0x00ffffff
        end
        return hexes
    else
        return { 0x00000000, 0xffffffff }
    end
end

---Converts an array of Aseprite palettes to a
---table of hex color integers.
---@param palettes Palette[] aseprite palettes
---@return integer[]
function AseUtilities.asePalettesToHexArr(palettes)
    if palettes then
        ---@type integer[]
        local hexes <const> = {}
        local lenPalettes <const> = #palettes
        local convert <const> = AseUtilities.aseColorToHex
        local rgbColorMode <const> = ColorMode.RGB

        local i = 0
        local k = 0
        while i < lenPalettes do
            i = i + 1
            local palette <const> = palettes[i]
            if palette then
                local lenPalette <const> = #palette
                local j = 0
                while j < lenPalette do
                    local aseColor <const> = palette:getColor(j)
                    j = j + 1
                    local hex <const> = convert(
                        aseColor, rgbColorMode)
                    k = k + 1
                    hexes[k] = hex
                end
            end
        end

        if #hexes == 1 then
            local amsk <const> = hexes[1] & 0xff000000
            table.insert(hexes, 1, amsk)
            hexes[3] = amsk | 0x00ffffff
        end

        return hexes
    else
        return { 0x00000000, 0xffffffff }
    end
end

---Blends a backdrop and overlay image, creating a union
---image from the two sources. The union then intersects
---with a selection. If a selection is empty, or is not
---provided, a new selection is created from the union.
---If the cumulative flag is true, the backdrop image is
---sampled regardless of its inclusion in the selection.
---Returns a new, blended image and its top left corner
---x, y. Does not support tile maps or images with
---mismatched color modes.
---@param under Image under image
---@param over Image overlay image
---@param uxCel integer? under cel top left corner x
---@param uyCel integer? under cel top left corner y
---@param oxCel integer? overlay cel top left corner x
---@param oyCel integer? overlay cel top left corner y
---@param mask Selection? selection
---@param cumulative boolean? under ignore mask
---@returns Image
---@returns integer
---@returns integer
function AseUtilities.blendImage(
    under, over, uxCel, uyCel, oxCel, oyCel,
    mask, cumulative)
    -- Because this method uses a mask and offers a
    -- cumulative option, it cannot be replaced by
    -- drawImage in 1.3rc-2, which supports blend modes.
    -- This can also be used as a polyfill for indexed
    -- color mode.

    local cmVrf <const> = cumulative or false
    local oycVrf <const> = oyCel or 0
    local oxcVrf <const> = oxCel or 0
    local uycVrf <const> = uyCel or 0
    local uxcVrf <const> = uxCel or 0

    local uSpec <const> = under.spec
    local uw <const> = uSpec.width
    local uh <const> = uSpec.height
    local ucm <const> = uSpec.colorMode
    local uMask <const> = uSpec.transparentColor

    local oSpec <const> = over.spec
    local ow <const> = oSpec.width
    local oh <const> = oSpec.height
    local ocm <const> = oSpec.colorMode
    local oMask <const> = oSpec.transparentColor

    -- Find union of image bounds a and b.
    local uxMax <const> = uxcVrf + uw - 1
    local uyMax <const> = uycVrf + uh - 1
    local xMin = math.min(uxcVrf, oxcVrf)
    local yMin = math.min(uycVrf, oycVrf)
    local xMax = math.max(uxMax, oxcVrf + ow - 1)
    local yMax = math.max(uyMax, oycVrf + oh - 1)

    local wTarget = 1 + xMax - xMin
    local hTarget = 1 + yMax - yMin

    local selVrf = mask
    if selVrf and (not selVrf.isEmpty) then
        local selBounds <const> = selVrf.bounds
        local xSel <const> = selBounds.x
        local ySel <const> = selBounds.y

        -- Find intersection of composite and selection.
        xMin = math.max(xMin, xSel)
        yMin = math.max(yMin, ySel)
        xMax = math.min(xMax, xSel + selBounds.width - 1)
        yMax = math.min(yMax, ySel + selBounds.height - 1)

        if cmVrf then
            -- If cumulative, then union with backdrop.
            xMin = math.min(xMin, uxcVrf)
            yMin = math.min(yMin, uycVrf)
            xMax = math.max(xMax, uxMax)
            yMax = math.max(yMax, uyMax)
        end

        -- Update target image dimensions.
        wTarget = 1 + xMax - xMin
        hTarget = 1 + yMax - yMin
    else
        selVrf = Selection(Rectangle(
            xMin, yMin, wTarget, hTarget))
    end

    local tMask = 0
    if uMask == oMask then tMask = uMask end
    local modeTarget <const> = ucm

    local tSpec <const> = ImageSpec {
        width = wTarget,
        height = hTarget,
        colorMode = modeTarget,
        transparentColor = tMask
    }
    tSpec.colorSpace = uSpec.colorSpace
    local target <const> = Image(tSpec)

    -- Avoid tile map images and mismatched image modes.
    if (ucm ~= ocm) or ucm == ColorMode.TILEMAP then
        return target, 0, 0
    end

    -- Offset needed when reading from source images
    -- into target image.
    local uxDiff <const> = uxcVrf - xMin
    local uyDiff <const> = uycVrf - yMin
    local oxDiff <const> = oxcVrf - xMin
    local oyDiff <const> = oycVrf - yMin

    local blendFunc = nil
    if modeTarget == ColorMode.INDEXED then
        blendFunc = AseUtilities.blendIndices
    elseif modeTarget == ColorMode.GRAY then
        blendFunc = AseUtilities.blendGray
    else
        blendFunc = AseUtilities.blendRgba
    end

    local pxItr <const> = target:pixels()
    for pixel in pxItr do
        local xPixel <const> = pixel.x
        local yPixel <const> = pixel.y

        local xSmpl <const> = xPixel + xMin
        local ySmpl <const> = yPixel + yMin
        local isContained <const> = selVrf:contains(xSmpl, ySmpl)

        local uHex = 0x0
        if cmVrf or isContained then
            local ux <const> = xPixel - uxDiff
            local uy <const> = yPixel - uyDiff
            if uy > -1 and uy < uh
                and ux > -1 and ux < uw then
                uHex = under:getPixel(ux, uy)
            end
        end

        local oHex = 0x0
        if isContained then
            local ox <const> = xPixel - oxDiff
            local oy <const> = yPixel - oyDiff
            if oy > -1 and oy < oh
                and ox > -1 and ox < ow then
                oHex = over:getPixel(ox, oy)
            end
        end

        pixel(blendFunc(uHex, oHex, tMask))
    end

    return target, xMin, yMin
end

---Blends two 16-bit gray colors.
---Premultiplies each color by its alpha prior
---to blending. Unpremultiplies the result.
---@param a integer backdrop color
---@param b integer overlay color
---@return integer
function AseUtilities.blendGray(a, b)
    local t = b >> 0x08 & 0xff
    if t > 0xfe then return b end
    local v <const> = a >> 0x08 & 0xff
    if v < 0x01 then return b end

    local u <const> = 0xff - t
    if t > 0x7f then t = t + 1 end

    local uv <const> = (v * u) // 0xff
    local tuv = t + uv
    if tuv < 0x01 then return 0x0 end
    if tuv > 0xff then tuv = 0xff end

    local ag <const> = a & 0xff
    local bg <const> = b & 0xff
    local cg = (bg * t + ag * uv) // tuv
    if cg > 0xff then cg = 0xff end
    return tuv << 0x08 | cg
end

---Blends two indexed image colors. Prioritizes
---the overlay color, so long as it does not
---equal the mask index. Assumes backdrop and
---overlay use the same mask index.
---@param a integer backdrop color
---@param b integer overlay color
---@param mask integer mask index
---@return integer
function AseUtilities.blendIndices(a, b, mask)
    if b ~= mask then return b end
    if a ~= mask then return a end
    return mask
end

---Blends two 32-bit RGBA colors.
---Premultiplies each color by its alpha prior
---to blending. Unpremultiplies the result.
---For more information,
---see https://www.w3.org/TR/compositing-1/ .
---@param a integer backdrop color
---@param b integer overlay color
---@return integer
function AseUtilities.blendRgba(a, b)
    local t = b >> 0x18 & 0xff
    if t > 0xfe then return b end
    local v <const> = a >> 0x18 & 0xff
    if v < 0x01 then return b end

    -- Experimented with subtracting
    -- from 0x100 instead of 0xff, due to 255//2
    -- not having a whole number middle, but 0xff
    -- lead to more accurate results.
    local u <const> = 0xff - t
    if t > 0x7f then t = t + 1 end

    local uv <const> = (v * u) // 0xff
    local tuv = t + uv
    if tuv < 0x01 then return 0x0 end
    if tuv > 0xff then tuv = 0xff end

    local ab <const> = a >> 0x10 & 0xff
    local ag <const> = a >> 0x08 & 0xff
    local ar <const> = a & 0xff

    local bb <const> = b >> 0x10 & 0xff
    local bg <const> = b >> 0x08 & 0xff
    local br <const> = b & 0xff

    local cb = (bb * t + ab * uv) // tuv
    local cg = (bg * t + ag * uv) // tuv
    local cr = (br * t + ar * uv) // tuv

    if cb > 0xff then cb = 0xff end
    if cg > 0xff then cg = 0xff end
    if cr > 0xff then cr = 0xff end

    return tuv << 0x18
        | cb << 0x10
        | cg << 0x08
        | cr
end

---Wrapper for app.command.ChangePixelFormat which
---accepts an integer constant as an input. The constant
---should be included in the ColorMode enum: INDEXED,
---GRAY or RGB. Does nothing if the constant is invalid.
---@param format ColorMode|integer format constant
function AseUtilities.changePixelFormat(format)
    if format == ColorMode.INDEXED then
        app.command.ChangePixelFormat { format = "indexed" }
    elseif format == ColorMode.GRAY then
        app.command.ChangePixelFormat { format = "gray" }
    elseif format == ColorMode.RGB then
        app.command.ChangePixelFormat { format = "rgb" }
    end
end

---Converts a Clr to an Aseprite Color.
---Assumes that source and target are in sRGB.
---Clamps the Clr's channels to [0.0, 1.0] before
---they are converted. Beware that this could return
---(255, 0, 0, 0) or (0, 255, 0, 0), which may be
---visually indistinguishable from - and confused
---with - an alpha mask, (0, 0, 0, 0).
---@param clr Clr clr
---@return Color
function AseUtilities.clrToAseColor(clr)
    local r <const> = math.min(math.max(clr.r, 0.0), 1.0)
    local g <const> = math.min(math.max(clr.g, 0.0), 1.0)
    local b <const> = math.min(math.max(clr.b, 0.0), 1.0)
    local a <const> = math.min(math.max(clr.a, 0.0), 1.0)

    return Color {
        r = math.floor(r * 255.0 + 0.5),
        g = math.floor(g * 255.0 + 0.5),
        b = math.floor(b * 255.0 + 0.5),
        a = math.floor(a * 255.0 + 0.5)
    }
end

---Creates new cels in a sprite. Prompts users to
---confirm if requested count exceeds a limit. The
---count is derived from frameCount x layerCount.
---Returns a one-dimensional table of cels, where
---layers are treated as rows, frames are treated
---as columns and the flat ordering is row-major.
---To assign a GUI color, use a hexadecimal integer
---as an argument.
---Returns a table of layers.
---@param sprite Sprite
---@param frStrtIdx integer frame start index
---@param frCount integer frame count
---@param lyrStrtIdx integer layer start index
---@param lyrCount integer layer count
---@param image Image cel image
---@param position Point? cel position
---@param guiClr integer? hexadecimal color
---@return Cel[]
function AseUtilities.createCels(
    sprite, frStrtIdx, frCount, lyrStrtIdx,
    lyrCount, image, position, guiClr)
    -- Do not use app.transactions.
    -- https://github.com/aseprite/aseprite/issues/3276

    if not sprite then
        app.alert {
            title = "Error",
            text = "Sprite could not be found."
        }
        return {}
    end

    local sprLayers <const> = sprite.layers
    local sprFrames <const> = sprite.frames
    local sprLyrCt <const> = #sprLayers
    local sprFrmCt <const> = #sprFrames

    -- Validate layer start index.
    -- Allow for negative indices, which are wrapped.
    -- Length is one extra because this is an insert.
    local valLyrIdx = lyrStrtIdx or 1
    if valLyrIdx == 0 then
        valLyrIdx = 1
    else
        valLyrIdx = 1 + (valLyrIdx - 1) % (sprLyrCt + 1)
    end
    -- print("valLyrIdx: " .. valLyrIdx)

    -- Validate frame start index.
    local valFrmIdx = frStrtIdx or 1
    if valFrmIdx == 0 then
        valFrmIdx = 1
    else
        valFrmIdx = 1 + (valFrmIdx - 1) % (sprFrmCt + 1)
    end
    -- print("valFrmIdx: " .. valFrmIdx)

    -- Validate count for layers.
    local valLyrCt = lyrCount or sprLyrCt
    if valLyrCt < 1 then
        valLyrCt = 1
    elseif valLyrCt > (1 + sprLyrCt - valLyrIdx) then
        valLyrCt = 1 + sprLyrCt - valLyrIdx
    end
    -- print("valLyrCt: " .. valLyrCt)

    -- Validate count for frames.
    local valFrmCt = frCount or sprFrmCt
    if valFrmCt < 1 then
        valLyrCt = 1
    elseif valFrmCt > (1 + sprFrmCt - valFrmIdx) then
        valFrmCt = 1 + sprFrmCt - valFrmIdx
    end
    -- print("valFrmCt: " .. valFrmCt)

    local flatCount <const> = valLyrCt * valFrmCt
    -- print("flatCount: " .. flatCount)
    if flatCount > AseUtilities.CEL_COUNT_LIMIT then
        local response <const> = app.alert {
            title = "Warning",
            text = {
                string.format(
                    "This script will create %d cels,",
                    flatCount),
                string.format(
                    "%d beyond the limit of %d.",
                    flatCount - AseUtilities.CEL_COUNT_LIMIT,
                    AseUtilities.CEL_COUNT_LIMIT),
                "Do you wish to proceed?"
            },
            buttons = { "&YES", "&NO" }
        }

        if response == 2 then
            return {}
        end
    end

    -- Shouldn't need to bother with image spec in this case.
    local valImg <const> = image or Image(1, 1)
    local valPos <const> = position or Point(0, 0)

    -- Layers = y = rows
    -- Frames = x = columns
    ---@type Cel[]
    local cels <const> = {}
    local i = 0
    while i < flatCount do
        local frameIndex <const> = valFrmIdx + (i % valFrmCt)
        local layerIndex <const> = valLyrIdx + (i // valFrmCt)
        local frameObj <const> = sprFrames[frameIndex]
        local layerObj <const> = sprLayers[layerIndex]

        -- print(string.format("Frame Index %d", frameIndex))
        -- print(string.format("Layer Index %d", layerIndex))

        -- Frame and layer must objects, not indices.
        i = i + 1
        cels[i] = sprite:newCel(
            layerObj, frameObj, valImg, valPos)
    end

    if guiClr and guiClr ~= 0x0 then
        local aseColor <const> = AseUtilities.hexToAseColor(guiClr)
        local j = 0
        while j < flatCount do
            j = j + 1
            cels[j].color = aseColor
        end
    end

    return cels
end

---Creates new empty frames in a sprite. Prompts user
---to confirm if requested count exceeds a limit.
--- Returns a table of frames. Frame duration is assumed
---to have been divided by 1000.0, and ready to be
---assigned as is.
---@param sprite Sprite sprite
---@param count integer frames to create
---@param duration number frame duration
---@return Frame[]
function AseUtilities.createFrames(sprite, count, duration)
    -- Do not use app.transactions.
    -- https://github.com/aseprite/aseprite/issues/3276

    if not sprite then
        app.alert {
            title = "Error",
            text = "Sprite could not be found."
        }
        return {}
    end

    if count < 1 then return {} end
    if count > AseUtilities.FRAME_COUNT_LIMIT then
        local response <const> = app.alert {
            title = "Warning",
            text = {
                string.format(
                    "This script will create %d frames,",
                    count),
                string.format(
                    "%d beyond the limit of %d.",
                    count - AseUtilities.FRAME_COUNT_LIMIT,
                    AseUtilities.FRAME_COUNT_LIMIT),
                "Do you wish to proceed?"
            },
            buttons = { "&YES", "&NO" }
        }

        if response == 2 then
            return {}
        end
    end

    local durVrf <const> = duration or 1
    local countVrf = count or 1
    if countVrf < 1 then countVrf = 1 end

    ---@type Frame[]
    local frames <const> = {}
    local i = 0
    while i < countVrf do
        i = i + 1
        local frame <const> = sprite:newEmptyFrame()
        frame.duration = durVrf
        frames[i] = frame
    end

    return frames
end

---Creates new layers in a sprite. Prompts user
---to confirm if requested count exceeds a limit. Wraps
---the process in an app.transaction. To assign a GUI
-- color, use a hexadecimal integer as an argument.
---Returns a table of layers.
---@param sprite Sprite sprite
---@param count integer number of layers to create
---@param blendMode BlendMode? blend mode
---@param opacity integer? layer opacity
---@param guiClr integer? rgba color
---@return Layer[]
function AseUtilities.createNewLayers(
    sprite, count, blendMode, opacity, guiClr)
    if not sprite then
        app.alert {
            title = "Error",
            text = "Sprite could not be found."
        }
        return {}
    end

    if count < 1 then return {} end
    if count > AseUtilities.LAYER_COUNT_LIMIT then
        local response <const> = app.alert {
            title = "Warning",
            text = {
                string.format(
                    "This script will create %d layers,",
                    count),
                string.format(
                    "%d beyond the limit of %d.",
                    count - AseUtilities.LAYER_COUNT_LIMIT,
                    AseUtilities.LAYER_COUNT_LIMIT),
                "Do you wish to proceed?"
            },
            buttons = { "&YES", "&NO" }
        }

        if response == 2 then
            return {}
        end
    end

    local opacVrf = opacity or 255
    if opacVrf < 0 then opacVrf = 0 end
    if opacVrf > 255 then opacVrf = 255 end
    local bmVrf = blendMode or BlendMode.NORMAL
    local countVrf = count or 1
    if countVrf < 1 then countVrf = 1 end

    ---@type Layer[]
    local layers <const> = {}
    local oldLayerCount <const> = #sprite.layers
    app.transaction("New Layers", function()
        local i = 0
        while i < countVrf do
            i = i + 1
            local layer <const> = sprite:newLayer()
            layer.blendMode = bmVrf
            layer.opacity = opacVrf
            layer.name = string.format(
                "Layer %d",
                oldLayerCount + i)
            layers[i] = layer
        end
    end)

    if guiClr and guiClr ~= 0x0 then
        local aseColor <const> = AseUtilities.hexToAseColor(guiClr)
        app.transaction("Layer Colors", function()
            local i = 0
            while i < countVrf do
                i = i + 1
                layers[i].color = aseColor
            end
        end)
    end

    return layers
end

---Draws a filled circle. Uses the Aseprite image
---instance method drawPixel. This means that the
---pixel changes will not be tracked as a transaction.
---@param image Image Aseprite image
---@param xc integer center x
---@param yc integer center y
---@param r integer radius
---@param hex integer rgba integer
function AseUtilities.drawCircleFill(image, xc, yc, r, hex)
    local blend <const> = AseUtilities.blendRgba
    local rsq <const> = r * r
    local r2 <const> = r * 2
    local lenn1 <const> = r2 * r2 - 1
    local i = -1
    while i < lenn1 do
        i = i + 1
        local x <const> = (i % r2) - r
        local y <const> = (i // r2) - r
        if (x * x + y * y) < rsq then
            local xMark <const> = xc + x
            local yMark <const> = yc + y
            local srcHex <const> = image:getPixel(xMark, yMark)
            local trgHex <const> = blend(srcHex, hex)
            image:drawPixel(xMark, yMark, trgHex)
        end
    end
end

---Blits input image onto another that is the
---next power of 2 in dimension. The nonUniform
---flag specifies whether the result can have
---unequal width and height, e.g., 64x32. Returns
---the image by reference if its size is already
---a power of 2.
---@param img Image image
---@param colorMode ColorMode color mode
---@param alphaMask integer alpha mask index
---@param colorSpace ColorSpace color space
---@param nonUniform boolean non uniform dimensions
---@return Image
function AseUtilities.expandImageToPow2(
    img, colorMode, alphaMask, colorSpace, nonUniform)
    local wOrig <const> = img.width
    local hOrig <const> = img.height
    local wDest = wOrig
    local hDest = hOrig
    if nonUniform then
        wDest = Utilities.nextPowerOf2(wOrig)
        hDest = Utilities.nextPowerOf2(hOrig)
    else
        wDest = Utilities.nextPowerOf2(
            math.max(wOrig, hOrig))
        hDest = wDest
    end

    if wDest == wOrig and hDest == hOrig then
        return img
    end

    local potSpec <const> = ImageSpec {
        width = wDest,
        height = hDest,
        colorMode = colorMode,
        transparentColor = alphaMask
    }
    potSpec.colorSpace = colorSpace
    local potImg <const> = Image(potSpec)
    potImg:drawImage(img)

    return potImg
end

---Finds a filtered array of cels to be edited in-place
---according to the provided criteria. The target is a
---string constant that could be "ALL", "ACTIVE", "RANGE"
---or "SELECTION". When the target is "ACTIVE", this
---includes the children of the active layer if it's a group.
---
---Visibility and editability are only considered locally;
---it's assumed that if the user selects a child layer whose
---parent is locked or hidden, they intended to do so.
---
---The selection option will create a new layer and cel.
---@param sprite Sprite active sprite
---@param layer Layer|nil active layer
---@param frame Frame|integer|nil active frame
---@param target string target preset
---@param includeLocked? boolean include locked layers
---@param includeHidden? boolean include hidden layers
---@param includeTiles? boolean include tile maps
---@param includeBkg? boolean include backgrounds
---@return Cel[]
function AseUtilities.filterCels(
    sprite, layer, frame, target,
    includeLocked,
    includeHidden,
    includeTiles,
    includeBkg)
    if target == "ALL" then
        local leaves <const> = AseUtilities.getLayerHierarchy(
            sprite,
            includeLocked,
            includeHidden,
            includeTiles,
            includeBkg)
        return AseUtilities.getUniqueCelsFromLeaves(
            leaves, sprite.frames)
    elseif target == "RANGE" then
        ---@type Cel[]
        local trgCels <const> = {}

        local tlHidden <const> = not app.preferences.general.visible_timeline
        if tlHidden then
            app.command.Timeline { open = true }
        end

        local appRange <const> = app.range
        if appRange.sprite == sprite then
            local imgsRange <const> = appRange.images
            local lenImgsRange <const> = #imgsRange
            local i = 0
            while i < lenImgsRange do
                i = i + 1
                local image <const> = imgsRange[i]
                local cel <const> = image.cel
                local celLayer <const> = cel.layer

                if (not celLayer.isReference)
                    and (includeHidden or celLayer.isVisible)
                    and (includeLocked or celLayer.isEditable)
                    and (includeTiles or (not celLayer.isTilemap))
                    and (includeBkg or (not celLayer.isBackground)) then
                    trgCels[#trgCels + 1] = cel
                end -- End reference layer check.
            end     -- End range images loop.
        end         -- End valid range sprite check.

        if tlHidden then
            app.command.Timeline { close = true }
        end

        return trgCels
    elseif target == "SELECTION" then
        if frame then
            local sel <const> = AseUtilities.getSelection(sprite)
            local selBounds <const> = sel.bounds
            local xSel <const> = selBounds.x
            local ySel <const> = selBounds.y
            local activeSpec <const> = sprite.spec
            local alphaMask <const> = activeSpec.transparentColor

            -- Create a subset of flattened sprite.
            local flatSpec <const> = ImageSpec {
                width = math.max(1, selBounds.width),
                height = math.max(1, selBounds.height),
                colorMode = activeSpec.colorMode,
                transparentColor = alphaMask
            }
            flatSpec.colorSpace = activeSpec.colorSpace

            local flatImage <const> = Image(flatSpec)
            flatImage:drawSprite(
                sprite, frame, Point(-xSel, -ySel))

            -- Remove pixels within selection bounds
            -- but not within selection itself.
            local flatPxItr <const> = flatImage:pixels()
            for pixel in flatPxItr do
                local x <const> = pixel.x + xSel
                local y <const> = pixel.y + ySel
                if not sel:contains(x, y) then
                    pixel(alphaMask)
                end
            end

            local adjCel = nil
            app.transaction("Cel From Mask", function()
                local adjLayer <const> = sprite:newLayer()
                adjLayer.name = "Mask.Layer"
                adjCel = sprite:newCel(
                    adjLayer, frame,
                    flatImage, Point(xSel, ySel))
            end)

            return { adjCel }
        end
        return {}
    else
        -- Default to "ACTIVE"
        if layer and frame then
            ---@type Layer[]
            local leaves <const> = {}
            AseUtilities.appendLeaves(
                layer, leaves,
                includeLocked,
                includeHidden,
                includeTiles,
                includeBkg)
            return AseUtilities.getUniqueCelsFromLeaves(
                leaves, { frame })
        end
        return {}
    end
end

---Flattens a group layer to a composite image.
---Does not verify that a layer is a group. Child
---layers are filtered according to the provided
---criteria. Returns an image and a cel bounds.
---If no composite could be made, returns a 1x1
---image and a rectangle in the top left corner.
---@param group Layer group layer
---@param frame Frame|integer frame
---@param sprClrMode ColorMode|integer sprite color mode
---@param colorSpace ColorSpace color space
---@param alphaIndex? integer alpha mask index
---@param includeLocked? boolean include locked layers
---@param includeHidden? boolean include hidden layers
---@param includeTiles? boolean include tile maps
---@param includeBkg? boolean include backgrounds
---@return Image
---@return Rectangle
function AseUtilities.flattenGroup(
    group, frame, sprClrMode,
    colorSpace, alphaIndex,
    includeLocked, includeHidden,
    includeTiles, includeBkg)
    local aiVerif = 0
    if alphaIndex then aiVerif = alphaIndex end

    local leaves <const> = AseUtilities.appendLeaves(
        group, {},
        includeLocked, includeHidden,
        includeTiles, includeBkg)
    local lenLeaves <const> = #leaves

    local useZIndex <const> = app.apiVersion >= 23
    local packets <const> = {}
    local lenPackets = 0

    local isIndexed <const> = sprClrMode == ColorMode.INDEXED
    local tilesToImage <const> = AseUtilities.tilesToImage
    local blendImage <const> = AseUtilities.blendImage
    local xTlGroup = 2147483647
    local yTlGroup = 2147483647
    local xBrGroup = -2147483648
    local yBrGroup = -2147483648

    local image = nil
    local bounds = nil

    local i = 0
    while i < lenLeaves do
        i = i + 1
        local leafLayer <const> = leaves[i]
        local leafCel <const> = leafLayer:cel(frame)
        if leafCel then
            local leafImage = leafCel.image
            if leafLayer.isTilemap then
                local tileSet <const> = leafLayer.tileset --[[@as Tileset]]
                leafImage = tilesToImage(
                    leafImage, tileSet, sprClrMode)
            end

            -- An Image:isEmpty check could be used here, but
            -- it was avoided to not incur performance cost.
            -- Calculate manually. Do not use cel bounds.
            local leafPos <const> = leafCel.position
            local xTlCel <const> = leafPos.x
            local yTlCel <const> = leafPos.y
            local xBrCel <const> = xTlCel + leafImage.width - 1
            local yBrCel <const> = yTlCel + leafImage.height - 1

            if xTlCel < xTlGroup then xTlGroup = xTlCel end
            if yTlCel < yTlGroup then yTlGroup = yTlCel end
            if xBrCel > xBrGroup then xBrGroup = xBrCel end
            if yBrCel > yBrGroup then yBrGroup = yBrCel end

            local zIndex = 0
            if useZIndex then zIndex = leafCel.zIndex end
            local order <const> = (i - 1) + zIndex

            lenPackets = lenPackets + 1
            packets[lenPackets] = {
                blendMode = leafLayer.blendMode,
                image = leafImage,
                opacityCel = leafCel.opacity,
                opacityLayer = leafLayer.opacity,
                order = order,
                xtl = xTlCel,
                ytl = yTlCel,
                zIndex = zIndex
            }
        end
    end

    --https://github.com/aseprite/aseprite/blob/main/docs/ase-file-specs.md#note5
    table.sort(packets, function(a, b)
        return (a.order < b.order)
            or ((a.order == b.order)
                and (a.zIndex < b.zIndex))
    end)

    local wGroup <const> = 1 + xBrGroup - xTlGroup
    local hGroup <const> = 1 + yBrGroup - yTlGroup
    if wGroup > 0 and hGroup > 0 then
        bounds = Rectangle {
            x = xTlGroup,
            y = yTlGroup,
            width = wGroup,
            height = hGroup
        }

        local compSpec <const> = ImageSpec {
            width = wGroup,
            height = hGroup,
            colorMode = sprClrMode,
            transparentColor = aiVerif
        }
        compSpec.colorSpace = colorSpace
        image = Image(compSpec)

        local floor <const> = math.floor

        local j = 0
        while j < lenPackets do
            j = j + 1
            local packet <const> = packets[j]
            local leafBlendMode <const> = packet.blendMode --[[@as BlendMode]]
            local leafImage <const> = packet.image --[[@as Image]]
            local leafCelOpacity <const> = packet.opacityCel --[[@as integer]]
            local leafLayerOpacity <const> = packet.opacityLayer --[[@as integer]]
            local xTlLeaf <const> = packet.xtl --[[@as integer]]
            local yTlLeaf <const> = packet.ytl --[[@as integer]]

            local celOpac01 <const> = leafCelOpacity / 255.0
            local layerOpac01 <const> = leafLayerOpacity / 255.0
            local leafOpac01 <const> = celOpac01 * layerOpac01
            local leafOpacity <const> = floor(leafOpac01 * 255.0 + 0.5)

            local compPos <const> = Point(
                xTlLeaf - xTlGroup,
                yTlLeaf - yTlGroup)

            if isIndexed then
                image = blendImage(image, leafImage,
                    0, 0, compPos.x, compPos.y)
            else
                image:drawImage(
                    leafImage, compPos,
                    leafOpacity, leafBlendMode)
            end
        end
    end

    if (not image) or (not bounds) then
        bounds = Rectangle(0, 0, 1, 1)
        local invalSpec <const> = ImageSpec {
            width = 1,
            height = 1,
            colorMode = sprClrMode,
            transparentColor = aiVerif
        }
        invalSpec.colorSpace = colorSpace
        image = Image(invalSpec)
    end

    return image, bounds
end

---Returns a copy of the source image that has
---been flipped horizontally.
---Also returns displaced coordinates for the
---top-left corner.
---@param source Image source image
---@return Image
---@return integer
---@return integer
function AseUtilities.flipImageHoriz(source)
    ---@type integer[]
    local px <const> = {}
    local srcPxItr <const> = source:pixels()
    local i = 0
    for pixel in srcPxItr do
        i = i + 1
        px[i] = pixel()
    end

    local srcSpec <const> = source.spec
    local w <const> = srcSpec.width
    local h <const> = srcSpec.height
    Utilities.flipPixelsHoriz(px, w, h)

    local target <const> = Image(srcSpec)
    local trgPxItr <const> = target:pixels()
    local j = 0
    for pixel in trgPxItr do
        j = j + 1
        pixel(px[j])
    end

    return target, 1 - w, 0
end

---Returns a copy of the source image that has
---been flipped vertically.
---Also returns displaced coordinates for the
---top-left corner.
---@param source Image source image
---@return Image
---@return integer
---@return integer
function AseUtilities.flipImageVert(source)
    ---@type integer[]
    local px <const> = {}
    local srcPxItr <const> = source:pixels()
    local i = 0
    for pixel in srcPxItr do
        i = i + 1
        px[i] = pixel()
    end

    local srcSpec <const> = source.spec
    local w <const> = srcSpec.width
    local h <const> = srcSpec.height
    Utilities.flipPixelsVert(px, w, h)

    local target <const> = Image(srcSpec)
    local trgPxItr <const> = target:pixels()
    local j = 0
    for pixel in trgPxItr do
        j = j + 1
        pixel(px[j])
    end

    return target, 0, 1 - h
end

---Converts an array of frame objects to an array of
---frame numbers. Used primarily to set a range's frames.
---@param frObjs Frame[]
---@return integer[]
function AseUtilities.frameObjsToIdcs(frObjs)
    -- Next and previous layer could use this function
    -- but it's not worth it putting a dofile at the top.
    ---@type integer[]
    local frIdcs <const> = {}
    local lenFrames <const> = #frObjs
    local i = 0
    while i < lenFrames do
        i = i + 1
        frIdcs[i] = frObjs[i].frameNumber
    end
    return frIdcs
end

---Gets an array of arrays of frame indices from a
---sprite according to a string constant.
---"ALL" gets all frames in the sprite.
---"RANGE" gets the frames in the timeline range.
---"MANUAL" attempts to parse string of integers
---defined by commas and hyphens.
---"TAGS" gets the frames from an array of tags.
---"ACTIVE", the default, returns the active frame.
---If there's no active frame, returns an empty array.
---
---For tags and manual, duplicates will be included
---when the batched flag is true. Otherwise a unique
---set is returned.
---
---For ranges, call this method before new layers,
---frames or cels are created. Otherwise the range
---will be lost. Checks timeline visibility before
---accessing range.
---
---If a range is a layer type, returns all frames
---in the sprite.
---@param sprite Sprite sprite
---@param target string preset
---@param batch boolean? batch
---@param mnStr string? manual
---@param tags Tag[]? tags
---@return integer[][]
function AseUtilities.getFrames(sprite, target, batch, mnStr, tags)
    if target == "ALL" then
        return { AseUtilities.frameObjsToIdcs(sprite.frames) }
    elseif target == "MANUAL" then
        if mnStr then
            local docPrefs <const> = app.preferences.document(sprite)
            local frameUiOffset <const> = docPrefs.timeline.first_frame - 1
            local lenFrames <const> = #sprite.frames
            if batch then
                return Utilities.parseRangeStringOverlap(
                    mnStr, lenFrames, frameUiOffset)
            else
                return { Utilities.parseRangeStringUnique(
                    mnStr, lenFrames, frameUiOffset) }
            end
        else
            return { {} }
        end
    elseif target == "TAGS" then
        if tags then
            if batch then
                return AseUtilities.parseTagsOverlap(tags)
            else
                return { AseUtilities.parseTagsUnique(tags) }
            end
        else
            return { {} }
        end
    elseif target == "RANGE" then
        local tlHidden <const> = not app.preferences.general.visible_timeline
        if tlHidden then
            app.command.Timeline { open = true }
        end

        ---@type integer[][]
        local frIdcsRange = { {} }
        local appRange <const> = app.range
        if appRange.sprite == sprite then
            local rangeType <const> = appRange.type
            if rangeType == RangeType.LAYERS then
                frIdcsRange = { AseUtilities.frameObjsToIdcs(sprite.frames) }
            else
                -- TODO: It's possible for these to not be consecutive if
                -- shift key is held down when selecting.
                local frIdcs1 <const> = AseUtilities.frameObjsToIdcs(
                    appRange.frames)
                frIdcsRange = { frIdcs1 }
            end
        end

        if tlHidden then
            app.command.Timeline { close = true }
        end

        return frIdcsRange
    else
        -- Default to "ACTIVE".
        local activeFrame <const> = app.site.frame
        if activeFrame then
            return { { activeFrame.frameNumber } }
        else
            return { {} }
        end
    end
end

---Appends a sprite's layer hierarchy to an array.
---If no array is provided, one is created.
---Whether layers are appended depends on the
---arguments provided.
---@param sprite Sprite sprite
---@param includeLocked? boolean include locked layers
---@param includeHidden? boolean include hidden layers
---@param includeTiles? boolean include tile maps
---@param includeBkg? boolean include backgrounds
---@return Layer[]
function AseUtilities.getLayerHierarchy(
    sprite,
    includeLocked, includeHidden,
    includeTiles, includeBkg)
    local append <const> = AseUtilities.appendLeaves
    local array <const> = {}
    local layers <const> = sprite.layers
    local lenLayers <const> = #layers
    local i = 0
    while i < lenLayers do
        i = i + 1
        append(
            layers[i], array,
            includeLocked,
            includeHidden,
            includeTiles,
            includeBkg)
    end
    return array
end

---For sprites with multiple palettes, tries to get
---a palette from an Aseprite frame object. Defaults
---to index 1 if the frame index exceeds the number
---of palettes.
---@param frame Frame|integer frame
---@param palettes Palette[] palettes
---@return Palette
function AseUtilities.getPalette(frame, palettes)
    local idx = 1
    local typeFrObj <const> = type(frame)
    if typeFrObj == "number"
        and math.type(frame) == "integer" then
        idx = frame
    elseif typeFrObj == "userdata" then
        idx = frame.frameNumber
    end
    local lenPalettes <const> = #palettes
    if idx > lenPalettes then idx = 1 end
    return palettes[idx]
end

---Gets a selection from a sprite. Calls InvertMask
---command twice. Returns a copy of the selection,
---not a reference. If the selection is empty, then
---trys to return the cel bounds; if that is empty,
---then returns the sprite bounds.
---@param sprite Sprite sprite
---@return Selection
function AseUtilities.getSelection(sprite)
    -- If a selection is moved, but the drag and
    -- drop pixels checkmark is not pressed, then
    -- a crash will result. MoveMask doesn't work
    -- because move quantity has a minimum of 1.
    app.transaction("Commit Mask", function()
        app.command.InvertMask()
        app.command.InvertMask()
    end)

    local srcSel <const> = sprite.selection
    if (not srcSel) or srcSel.isEmpty then
        local activeCel <const> = app.site.cel
        if activeCel then
            -- Cel could be out-of-bounds, so this
            -- also needs to intersect with the sprite
            -- canvas. This ignores possibility that
            -- the cel image could be empty.
            local trgSel <const> = Selection(activeCel.bounds)
            trgSel:intersect(sprite.bounds)
            if not trgSel.isEmpty then return trgSel end
        end

        return Selection(sprite.bounds)
    end

    local trgSel <const> = Selection()
    trgSel:add(srcSel)
    return trgSel
end

---Gets tiles from a tile map that are entirely
---contained by a selection. Returns a dictionary
---where the tile map index serves as the key
---and the Tile object is the value.
---
---Assumes that tile map and tile set have been
---vetted to confirm their association.
---@param tileMap Image tile map, an image
---@param tileSet Tileset tile set
---@param selection Selection selection
---@param xtlCel integer? cel top left corner x
---@param ytlCel integer? cel top left corner y
---@return table<integer, Tile>
function AseUtilities.getSelectedTiles(
    tileMap, tileSet, selection, xtlCel, ytlCel)
    -- Validate optional arguments.
    local vytlCel <const> = ytlCel or 0
    local vxtlCel <const> = xtlCel or 0

    -- Results.
    ---@type table<integer, Tile>
    local tiles <const> = {}
    if tileMap.colorMode ~= ColorMode.TILEMAP then
        return tiles
    end

    -- Unpack tile set.
    local tileGrid <const> = tileSet.grid
    local tileDim <const> = tileGrid.tileSize
    local wTile <const> = tileDim.width
    local hTile <const> = tileDim.height
    local flatDimTile <const> = wTile * hTile
    local lenTileSet <const> = #tileSet

    -- Cache methods used in loop.
    local pxTilei <const> = app.pixelColor.tileI

    ---@type table<integer, boolean>
    local visitedTiles <const> = {}
    local mapItr <const> = tileMap:pixels()
    for mapEntry in mapItr do
        local mapif <const> = mapEntry() --[[@as integer]]
        local index <const> = pxTilei(mapif)
        if index > 0 and index < lenTileSet
            and (not visitedTiles[index]) then
            visitedTiles[index] = true

            local xMap <const> = mapEntry.x
            local yMap <const> = mapEntry.y
            local xtlTile <const> = vxtlCel + xMap * wTile
            local ytlTile <const> = vytlCel + yMap * hTile

            local contained = true
            local i = 0
            while contained and i < flatDimTile do
                local xLocal <const> = i % wTile
                local yLocal <const> = i // wTile
                local xPixel <const> = xtlTile + xLocal
                local yPixel <const> = ytlTile + yLocal
                contained = contained
                    and selection:contains(
                        Point(xPixel, yPixel))
                i = i + 1
            end

            if contained then
                -- print(string.format(
                --     "[%d, %d]: [%d, %d]: %d",
                --     xMap, yMap, xtlTile, ytlTile, index))
                tiles[index] = tileSet:tile(index)
            end
        end
    end

    return tiles
end

---Get unique cels from layers that have already been
---verified as leaves and filtered. If the output
---target array is not supplied, a new one is created.
---@param leaves Layer[] leaf layers
---@param frames integer[]|Frame[] frames
---@return Cel[]
function AseUtilities.getUniqueCelsFromLeaves(leaves, frames)
    ---@type table<integer, Cel>
    local uniqueCels <const> = {}

    local lenLeaves <const> = #leaves
    local lenFrames <const> = #frames
    local lenCompound <const> = lenLeaves * lenFrames
    local k = 0
    while k < lenCompound do
        local i <const> = k // lenFrames
        local j <const> = k % lenFrames
        k = k + 1

        local leaf <const> = leaves[1 + i]
        local frame <const> = frames[1 + j]
        local cel <const> = leaf:cel(frame)
        if cel then
            uniqueCels[cel.image.id] = cel
        end
    end

    ---@type Cel[]
    local celsArr <const> = {}
    for _, cel in pairs(uniqueCels) do
        celsArr[#celsArr + 1] = cel
    end
    return celsArr
end

---Gets the unique tiles from a tile map.
---Assumes that tile map and tile set have been
---vetted to confirm their association.
---@param tileMap Image tile map, an image
---@param tileSet Tileset tile set
---@return table<integer, Tile>
function AseUtilities.getUniqueTiles(tileMap, tileSet)
    ---@type table<integer, Tile>
    local tiles <const> = {}
    if tileMap.colorMode ~= ColorMode.TILEMAP then
        return tiles
    end
    local lenTileSet <const> = #tileSet
    local pxTilei <const> = app.pixelColor.tileI
    local mapItr <const> = tileMap:pixels()
    for mapEntry in mapItr do
        local mapif <const> = mapEntry() --[[@as integer]]
        local index <const> = pxTilei(mapif)
        if index > 0 and index < lenTileSet
            and (not tiles[index]) then
            tiles[index] = tileSet:tile(index)
        end
    end
    return tiles
end

---Creates a table of gray colors represented as
---32 bit integers, where the gray is repeated
---three times in red, green and blue channels.
---@param count integer swatch count
---@return integer[]
function AseUtilities.grayHexes(count)
    local floor <const> = math.floor
    local valCount = count or 255
    if valCount < 2 then valCount = 2 end
    local toGray <const> = 255.0 / (valCount - 1.0)

    ---@type integer[]
    local result <const> = {}
    local i = 0
    while i < valCount do
        local g <const> = floor(i * toGray + 0.5)
        i = i + 1
        result[i] = 0xff000000
            | g << 0x10 | g << 0x08 | g
    end
    return result
end

---Converts a 32 bit ABGR hexadecimal integer
---to an Aseprite Color object. Does not use
---the Color rgbaPixel constructor, as the color
---mode dictates how the integer is interpreted.
---@param hex integer hexadecimal color
---@return Color
function AseUtilities.hexToAseColor(hex)
    -- See https://github.com/aseprite/aseprite/
    -- blob/main/src/app/script/color_class.cpp#L22
    return Color {
        r = hex & 0xff,
        g = (hex >> 0x08) & 0xff,
        b = (hex >> 0x10) & 0xff,
        a = (hex >> 0x18) & 0xff
    }
end

---Adds padding around the edges of an image.
---Does not check if image is a tile map.
---If the padding is less than one, returns the
---source image.
---@param image Image source image
---@param padding integer padding
---@return Image
function AseUtilities.padImage(image, padding)
    if padding < 1 then return image end

    local pad2 <const> = padding + padding
    local imageSpec <const> = image.spec
    local padSpec <const> = ImageSpec {
        colorMode = imageSpec.colorMode,
        width = imageSpec.width + pad2,
        height = imageSpec.height + pad2,
        transparentColor = imageSpec.transparentColor
    }
    padSpec.colorSpace = imageSpec.colorSpace
    local padded <const> = Image(padSpec)
    padded:drawImage(image, Point(padding, padding))
    return padded
end

---Parses an Aseprite Tag to an array of frame
---indices. For example, a tag with a fromFrame
---of 8 and a toFrame of 10 will return 8, 9, 10
---if the tag has FORWARD direction; 10, 9, 8 for
---REVERSE. Ping-pong and its reverse excludes
---one boundary so that other renderers don't draw
---it twice. Doesn't interpret a tag's repeat count.
---
---A tag may contain frame indices that are out of
---bounds for the sprite that contains the tag.
---Returns an empty array if so.
---@param tag Tag Aseprite Tag
---@return integer[]
function AseUtilities.parseTag(tag)
    local destFrObj <const> = tag.toFrame
    if not destFrObj then return {} end

    local origFrObj <const> = tag.fromFrame
    if not origFrObj then return {} end

    local origIdx <const> = origFrObj.frameNumber
    local destIdx <const> = destFrObj.frameNumber
    if origIdx == destIdx then return { destIdx } end

    ---@type integer[]
    local arr <const> = {}
    local idxArr = 0
    local aniDir <const> = tag.aniDir
    if aniDir == AniDir.REVERSE then
        local j = destIdx + 1
        while j > origIdx do
            j = j - 1
            idxArr = idxArr + 1
            arr[idxArr] = j
        end
    elseif aniDir == AniDir.PING_PONG then
        local j = origIdx - 1
        while j < destIdx do
            j = j + 1
            idxArr = idxArr + 1
            arr[idxArr] = j
        end
        local op1 <const> = origIdx + 1
        while j > op1 do
            j = j - 1
            idxArr = idxArr + 1
            arr[idxArr] = j
        end
    elseif aniDir == AniDir.PING_PONG_REVERSE then
        local j = destIdx + 1
        while j > origIdx do
            j = j - 1
            idxArr = idxArr + 1
            arr[idxArr] = j
        end
        local dn1 <const> = destIdx - 1
        while j < dn1 do
            j = j + 1
            idxArr = idxArr + 1
            arr[idxArr] = j
        end
    else
        -- Default to AniDir.FOWARD
        local j = origIdx - 1
        while j < destIdx do
            j = j + 1
            idxArr = idxArr + 1
            arr[idxArr] = j
        end
    end

    return arr
end

---Parses an array of Aseprite tags. Returns
---an array of arrays. Inner arrays may hold
---duplicate frame indices, as the same frame
---could appear in multiple groups.
---@param tags Tag[] tags array
---@return integer[][]
function AseUtilities.parseTagsOverlap(tags)
    local lenTags <const> = #tags
    local arr2 <const> = {}
    local parseTag <const> = AseUtilities.parseTag
    local i = 0
    while i < lenTags do
        i = i + 1
        arr2[i] = parseTag(tags[i])
    end
    return arr2
end

---Parses an array of Aseprite tags. Returns
---an ordered set of integers.
---@param tags Tag[] tags array
---@return integer[]
function AseUtilities.parseTagsUnique(tags)
    ---@type table<integer, boolean>
    local dict <const> = {}
    local arr2 <const> = AseUtilities.parseTagsOverlap(tags)
    local i = 0
    local lenArr2 <const> = #arr2
    while i < lenArr2 do
        i = i + 1
        local arr1 <const> = arr2[i]
        local lenArr1 <const> = #arr1
        local j = 0
        while j < lenArr1 do
            j = j + 1
            dict[arr1[j]] = true
        end
    end
    return Utilities.dictToSortedSet(dict)
end

---Preserves the application fore- and background
---colors across sprite changes. Copies and
---reassigns the colors to themselves. Does nothing
---if there is no active sprite.
function AseUtilities.preserveForeBack()
    if app.activeSprite then
        app.fgColor = AseUtilities.aseColorCopy(app.fgColor, "")
        app.command.SwitchColors()
        app.fgColor = AseUtilities.aseColorCopy(app.fgColor, "")
        app.command.SwitchColors()
    end
end

---Returns a copy of the source image that has
---been resized to the width and height. Uses nearest
---neighbor sampling. If the width and height are
---equal to the original, returns the source image.
---@param source Image source image
---@param wTrg integer resized width
---@param hTrg integer resized height
---@return Image
function AseUtilities.resizeImageNearest(source, wTrg, hTrg)
    local srcSpec <const> = source.spec
    local wSrc <const> = srcSpec.width
    local hSrc <const> = srcSpec.height

    local wVrf = wTrg
    local hVrf = hTrg
    if wVrf < 0 then wVrf = -wVrf end
    if hVrf < 0 then hVrf = -hVrf end
    if wVrf < 1 then wVrf = 1 end
    if hVrf < 1 then hVrf = 1 end

    if wTrg == wSrc and hTrg == hSrc then
        return source
    end

    ---@type integer[]
    local px <const> = {}
    local srcPxItr <const> = source:pixels()
    local i = 0
    for pixel in srcPxItr do
        i = i + 1
        px[i] = pixel()
    end

    local trgSpec <const> = ImageSpec {
        width = wTrg,
        height = hTrg,
        colorMode = source.colorMode,
        transparentColor = srcSpec.transparentColor
    }
    trgSpec.colorSpace = srcSpec.colorSpace
    local target <const> = Image(trgSpec)

    local pxRsz <const> = Utilities.resizePixelsNearest(
        px, wSrc, hSrc, wTrg, hTrg)

    local trgPxItr <const> = target:pixels()
    local j = 0
    for pixel in trgPxItr do
        j = j + 1
        pixel(pxRsz[j])
    end

    return target
end

---Returns a copy of the source image that has
---been rotated 90 degrees counter-clockwise.
---Also returns displaced coordinates for the
---top-left corner.
---@param source Image source image
---@return Image
---@return integer
---@return integer
function AseUtilities.rotateImage90(source)
    local srcSpec <const> = source.spec
    local w <const> = srcSpec.width
    local h <const> = srcSpec.height

    ---@type integer[]
    local pxRot <const> = {}
    local lennh <const> = w * h - h
    local srcPxItr <const> = source:pixels()
    for pixel in srcPxItr do
        pxRot[1 + lennh + pixel.y - pixel.x * h] = pixel()
    end

    local trgSpec <const> = ImageSpec {
        width = h,
        height = w,
        colorMode = source.colorMode,
        transparentColor = srcSpec.transparentColor
    }
    trgSpec.colorSpace = srcSpec.colorSpace
    local target <const> = Image(trgSpec)

    local trgPxItr <const> = target:pixels()
    local j = 0
    for pixel in trgPxItr do
        j = j + 1
        pixel(pxRot[j])
    end
    return target, 0, 1 - w
end

---Returns a copy of the source image that has
---been rotated 180 degrees. Also returns
---displaced coordinates for the top-left corner.
---@param source Image source image
---@return Image
---@return integer
---@return integer
function AseUtilities.rotateImage180(source)
    ---@type integer[]
    local px <const> = {}
    local srcPxItr <const> = source:pixels()
    local i = 0
    for pixel in srcPxItr do
        i = i + 1
        px[i] = pixel()
    end

    -- Table is reversed in-place.
    Utilities.reverseTable(px)
    local target <const> = Image(source.spec)
    local trgPxItr <const> = target:pixels()
    local j = 0
    for pixel in trgPxItr do
        j = j + 1
        pixel(px[j])
    end

    return target,
        1 - source.width,
        1 - source.height
end

---Returns a copy of the source image that has
---been rotated 270 degrees counter-clockwise.
---Also returns displaced coordinates for the
---top-left corner.
---@param source Image source image
---@return Image
---@return integer
---@return integer
function AseUtilities.rotateImage270(source)
    local srcSpec <const> = source.spec
    local w <const> = srcSpec.width
    local h <const> = srcSpec.height

    ---@type integer[]
    local pxRot <const> = {}
    local hn1 <const> = h - 1
    local srcPxItr <const> = source:pixels()
    for pixel in srcPxItr do
        pxRot[1 + pixel.x * h + hn1 - pixel.y] = pixel()
    end

    local trgSpec <const> = ImageSpec {
        width = h,
        height = w,
        colorMode = source.colorMode,
        transparentColor = srcSpec.transparentColor
    }
    trgSpec.colorSpace = srcSpec.colorSpace
    local target <const> = Image(trgSpec)

    local trgPxItr <const> = target:pixels()
    local j = 0
    for pixel in trgPxItr do
        j = j + 1
        pixel(pxRot[j])
    end

    return target, 1 - h, 0
end

---Selects the non-zero pixels of a cel's image.
---Intersects the selection with the sprite bounds
---if provided. For cases where cel may be partially
---outside the canvas edges. For tile map layers,
---selects the cel's bounds.
---@param cel Cel cel
---@param spriteBounds Rectangle? sprite bounds
---@return Selection
function AseUtilities.selectCel(cel, spriteBounds)
    local celBounds <const> = cel.bounds
    local xCel <const> = celBounds.x
    local yCel <const> = celBounds.y

    local celImage <const> = cel.image
    local pxItr <const> = celImage:pixels()
    local celSpec <const> = celImage.spec
    local colorMode <const> = celSpec.colorMode

    -- Beware naming, 'select' is a method built-in to Lua.
    local mask <const> = Selection(celBounds)
    local pxRect <const> = Rectangle(0, 0, 1, 1)

    if colorMode == ColorMode.RGB then
        for pixel in pxItr do
            if pixel() & 0xff000000 == 0 then
                pxRect.x = pixel.x + xCel
                pxRect.y = pixel.y + yCel
                mask:subtract(pxRect)
            end
        end
    elseif colorMode == ColorMode.INDEXED then
        local alphaIndex <const> = celSpec.transparentColor
        for pixel in pxItr do
            if pixel() == alphaIndex then
                pxRect.x = pixel.x + xCel
                pxRect.y = pixel.y + yCel
                mask:subtract(pxRect)
            end
        end
    elseif colorMode == ColorMode.GRAY then
        for pixel in pxItr do
            if pixel() & 0xff00 == 0 then
                pxRect.x = pixel.x + xCel
                pxRect.y = pixel.y + yCel
                mask:subtract(pxRect)
            end
        end
    end

    if spriteBounds then
        mask:intersect(spriteBounds)
    end

    return mask
end

---Sets a palette in a sprite at a given index to a table
---of colors represented as hexadecimal integers. The
---palette index defaults to 1.
---@param arr integer[] color array
---@param sprite Sprite sprite
---@param paletteIndex integer? index
function AseUtilities.setPalette(arr, sprite, paletteIndex)
    local palIdxVerif = paletteIndex or 1
    local palettes <const> = sprite.palettes
    local lenPalettes <const> = #palettes
    local lenHexArr <const> = #arr
    -- This should be consistent behavior with getPalette.
    if palIdxVerif > lenPalettes then palIdxVerif = 1 end
    local palette <const> = palettes[palIdxVerif]
    if lenHexArr > 0 then
        app.transaction("Set Palette", function()
            palette:resize(lenHexArr)
            local i = 0
            while i < lenHexArr do
                i = i + 1
                -- It's not better to pass a hex to setColor.
                -- Doing so creates the same problems as the Color
                -- rgbaPixel constructor, where an image's mode
                -- determines how the integer is interpreted.
                -- See https://github.com/aseprite/aseprite/
                -- blob/main/src/app/script/palette_class.cpp#L196 ,
                -- https://github.com/aseprite/aseprite/blob/
                -- main/src/app/color_utils.cpp .
                local hex <const> = arr[i]
                local aseColor <const> = AseUtilities.hexToAseColor(hex)
                palette:setColor(i - 1, aseColor)
            end
        end)
    else
        local clearBlack <const> = Color { r = 0, g = 0, b = 0, a = 0 }
        app.transaction("Set Palette", function()
            palette:resize(1)
            palette:setColor(0, clearBlack)
        end)
    end
end

---Converts an image from a tile set layer to a regular
---image.
---@param imgSrc Image source image
---@param tileSet Tileset tile set
---@param sprClrMode ColorMode|integer sprite color mode
---@return Image
function AseUtilities.tilesToImage(imgSrc, tileSet, sprClrMode)
    local tileGrid <const> = tileSet.grid
    local tileDim <const> = tileGrid.tileSize
    local tileWidth <const> = tileDim.width
    local tileHeight <const> = tileDim.height
    local lenTileSet <const> = #tileSet

    -- The source image's color mode is 4 if it is a tile map.
    -- Assigning 4 to the target image when the sprite color
    -- mode is 2 (indexed) crashes Aseprite.
    local specSrc <const> = imgSrc.spec
    local specTrg <const> = ImageSpec {
        width = specSrc.width * tileWidth,
        height = specSrc.height * tileHeight,
        colorMode = sprClrMode,
        transparentColor = specSrc.transparentColor
    }
    specTrg.colorSpace = specSrc.colorSpace
    local imgTrg <const> = Image(specTrg)

    -- Separate a tile's index from the meta-data.
    -- The underlying logic is here:
    -- https://github.com/aseprite/aseprite/blob/main/src/doc/tile.h#L24
    -- local tileMetaMask  = 0xe0000000
    -- local maskFlipX = 0x20000000
    -- local maskFlipY = 0x40000000
    -- local maskRot90cw = 0x80000000
    -- local maskRot180 = maskFlipX | maskFlipY
    -- local maskRot90ccw = maskRot180 | maskRot90cw
    local pxTilei <const> = app.pixelColor.tileI

    local mapItr <const> = imgSrc:pixels()
    for mapEntry in mapItr do
        local mapif <const> = mapEntry() --[[@as integer]]
        local i <const> = pxTilei(mapif)

        if i > 0 and i < lenTileSet then
            local tile <const> = tileSet:tile(i)
            local tileImage <const> = tile.image
            -- TODO: Wait until this is useful to implement.
            -- local meta = tlData & tileMetaMask
            -- if meta == maskRot90ccw then
            --     tileImage = AseUtilities.rotateImage90(tileImage)
            -- elseif meta == maskRot180 then
            --     tileImage = AseUtilities.rotateImage180(tileImage)
            -- elseif meta == maskRot90cw then
            --     tileImage = AseUtilities.rotateImage270(tileImage)
            -- elseif meta == maskFlipY then
            --     tileImage = AseUtilities.flipImageVert(tileImage)
            -- elseif meta == maskFlipX then
            --     tileImage = AseUtilities.flipImageHoriz(tileImage)
            -- elseif meta == 0xc0000000 then
            --     tileImage = AseUtilities.flipImageVert(tileImage)
            --     tileImage = AseUtilities.rotateImage90(tileImage)
            -- elseif meta == 0xa0000000 then
            --     tileImage = AseUtilities.flipImageHoriz(tileImage)
            --     tileImage = AseUtilities.rotateImage90(tileImage)
            -- end

            imgTrg:drawImage(
                tileImage,
                Point(mapEntry.x * tileWidth,
                    mapEntry.y * tileHeight))
        end
    end

    return imgTrg
end

---Trims a cel's image and position to a selection.
---An image's pixel is cleared to the default color
---if it isn't contained by the selection. If the
---default is nil, uses the cel image's alpha mask.
---@param cel Cel source cel
---@param mask Selection selection
---@param hexDefault integer? default color
function AseUtilities.trimCelToSelect(cel, mask, hexDefault)
    -- Beware naming, 'select' is a method built-in to Lua.
    local selBounds <const> = mask.bounds
    local celBounds <const> = cel.bounds
    local clip <const> = celBounds:intersect(selBounds)
    local xClip <const> = clip.x
    local yClip <const> = clip.y

    -- Avoid transactions if possible.
    local oldPos <const> = cel.position
    if oldPos.x ~= xClip
        or oldPos.y ~= yClip then
        cel.position = Point(xClip, yClip)
    end

    local celImg <const> = cel.image
    local celSpec <const> = celImg.spec
    local alphaMask <const> = celSpec.transparentColor
    local trimSpec <const> = ImageSpec {
        width = math.max(1, clip.width),
        height = math.max(1, clip.height),
        colorMode = celSpec.colorMode,
        transparentColor = alphaMask
    }
    trimSpec.colorSpace = celSpec.colorSpace

    local trimImage <const> = Image(trimSpec)
    if clip.width > 0 and clip.height > 0 then
        local celPos <const> = cel.position
        trimImage:drawImage(
            celImg, Point(
                oldPos.x - celPos.x,
                oldPos.y - celPos.y))

        local hexVrf <const> = hexDefault or alphaMask
        local pxItr <const> = trimImage:pixels()
        for pixel in pxItr do
            if not mask:contains(
                    xClip + pixel.x,
                    yClip + pixel.y) then
                pixel(hexVrf)
            end
        end
    end
    cel.image = trimImage
end

---Trims a cel's image and position such that it no longer
---exceeds the sprite's boundaries. Unlike built-in method,
---does not trim the image's alpha.
---@param cel Cel source cel
---@param sprite Sprite parent sprite
function AseUtilities.trimCelToSprite(cel, sprite)
    local celBounds <const> = cel.bounds
    local spriteBounds <const> = sprite.bounds
    local clip <const> = celBounds:intersect(spriteBounds)

    -- Avoid transactions if possible.
    local oldPos <const> = cel.position
    if oldPos.x ~= clip.x
        or oldPos.y ~= clip.y then
        cel.position = Point(clip.x, clip.y)
    end

    local celImg <const> = cel.image
    local celSpec <const> = celImg.spec

    local trimSpec <const> = ImageSpec {
        width = math.max(1, clip.width),
        height = math.max(1, clip.height),
        colorMode = celSpec.colorMode,
        transparentColor = celSpec.transparentColor
    }
    trimSpec.colorSpace = celSpec.colorSpace
    local trimImage <const> = Image(trimSpec)

    if clip.width > 0 and clip.height > 0 then
        local celPos <const> = cel.position
        trimImage:drawImage(
            celImg, Point(
                oldPos.x - celPos.x,
                oldPos.y - celPos.y))
    end
    cel.image = trimImage
end

---Creates a copy of the image where excess
---transparent pixels have been trimmed from
---the edges. Padding is expected to be a positive
---number. It defaults to zero.
---
---Default width and height can be given in the
---event that the image is completey transparent.
---
---Returns a tuple containing the cropped image,
---the top left x and top left y. The top left
---should be added to the position of the cel
---that contained the source image.
---@param image Image aseprite image
---@param padding integer padding
---@param alphaIndex integer alpha mask index
---@param wDefault integer? width default
---@param hDefault integer? height default
---@return Image
---@return integer
---@return integer
function AseUtilities.trimImageAlpha(
    image, padding, alphaIndex,
    wDefault, hDefault)
    local padVrf = padding or 0
    padVrf = math.abs(padVrf)
    local pad2 <const> = padVrf + padVrf

    -- Available as of version 1.3-rc1.
    -- If the image contains no nonzero pixels,
    -- returns a rectangle of zero size.
    local rect <const> = image:shrinkBounds(alphaIndex)
    local rectIsValid <const> = rect.width > 0
        and rect.height > 0

    local lft = 0
    local top = 0
    local wTrg = wDefault or image.width
    local hTrg = hDefault or image.height
    if rectIsValid then
        lft = rect.x
        top = rect.y
        wTrg = rect.width
        hTrg = rect.height
    end

    local srcSpec <const> = image.spec
    local trgSpec <const> = ImageSpec {
        colorMode = srcSpec.colorMode,
        width = wTrg + pad2,
        height = hTrg + pad2,
        transparentColor = alphaIndex
    }
    trgSpec.colorSpace = srcSpec.colorSpace
    local target <const> = Image(trgSpec)

    if rectIsValid then
        target:drawImage(image,
            Point(padVrf - lft, padVrf - top))
    end
    return target, lft - padVrf, top - padVrf
end

---Converts a Vec2 to an Aseprite Point.
---@param v Vec2 vector
---@return Point
function AseUtilities.vec2ToPoint(v)
    return Point(
        Utilities.round(v.x),
        Utilities.round(v.y))
end

---Translates the pixels of an image by a vector,
---wrapping the elements that exceed its dimensions back
---to the beginning.
---@param source Image source image
---@param x integer x translation
---@param y integer y translation
---@return Image
function AseUtilities.wrapImage(source, x, y)
    ---@type integer[]
    local px <const> = {}
    local srcPxItr <const> = source:pixels()
    local i = 0
    for pixel in srcPxItr do
        i = i + 1
        px[i] = pixel()
    end

    local sourceSpec <const> = source.spec
    local w <const> = sourceSpec.width
    local h <const> = sourceSpec.height
    local wrp <const> = Utilities.wrapPixels(px, x, y, w, h)

    local target <const> = Image(sourceSpec)
    local trgPxItr <const> = target:pixels()
    local j = 0
    for pixel in trgPxItr do
        j = j + 1
        pixel(wrp[j])
    end

    return target
end

return AseUtilities