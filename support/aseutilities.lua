dofile("./utilities.lua")
dofile("./clr.lua")

AseUtilities = {}
AseUtilities.__index = AseUtilities

setmetatable(AseUtilities, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Maximum number of a cels a script may request to create before the user is
---prompted to confirm.
AseUtilities.CEL_COUNT_LIMIT = 256

---Default palette used when no other is available. Simulates a RYB color wheel
---with black and white.
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

---Angles in degrees which are remapped to permutations of atan(1,2), atan(1,3).
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

---Number of decimals to display when printing real numbers to the console.
AseUtilities.DISPLAY_DECIMAL = 3

---Table of file extensions supported for open file dialogs.
AseUtilities.FILE_FORMATS_OPEN = {
    "ase", "aseprite", "bmp", "flc", "fli",
    "gif", "jpeg", "jpg", "pcc", "pcx",
    "png", "qoi", "tga", "webp"
}

---Table of file extensions supported for open and save palette dialogs.
AseUtilities.FILE_FORMATS_PAL = {
    "act", "aseprite", "col", "gpl", "hex",
    "pal", "png"
}

---Table of file extensions supported for save file dialogs.
AseUtilities.FILE_FORMATS_SAVE = {
    "aseprite", "bmp", "flc", "fli",
    "gif", "pcc", "pcx",
    "png", "qoi", "tga", "webp"
}

---Maximum number of frames a script may request to create before the user is
---prompted to confirm.
AseUtilities.FRAME_COUNT_LIMIT = 256

---Number of swatches to generate for gray color mode sprites.
AseUtilities.GRAY_COUNT = 32

---Maximum number of layers a script may request to create before the user is
---prompted to confirm.
AseUtilities.LAYER_COUNT_LIMIT = 96

---Camera projections.
AseUtilities.PROJECTIONS = {
    "ORTHO",
    "PERSPECTIVE"
}

---Houses utility methods for scripting Aseprite add-ons.
---@return table
function AseUtilities.new()
    local inst <const> = setmetatable({}, AseUtilities)
    return inst
end

---If a layer is a group, appends the layer and any child groups to an array.
---@param layer Layer layer
---@param array Layer[] groups array
---@param includeLocked? boolean include locked groups
---@param includeHidden? boolean include hidden groups
---@return Layer[]
function AseUtilities.appendGroups(
    layer, array, includeLocked, includeHidden)
    -- TODO: Option to include or exclude collapsed?
    if layer.isGroup
        and (includeLocked or layer.isEditable)
        and (includeHidden or layer.isVisible) then
        array[#array + 1] = layer

        -- Using type annotation causes syntax highlight bug when looking
        -- at the code on Github.
        local childLayers <const> = layer.layers
        if childLayers then
            local append <const> = AseUtilities.appendGroups
            local lenChildLayers <const> = #childLayers
            local i = 0
            while i < lenChildLayers do
                i = i + 1
                append(childLayers[i], array, includeLocked, includeHidden)
            end
        end
    end
    return array
end

---If a layer is a group, appends its children to an array. If the layer
---is not a group, then whether it's appended depends on the filter booleans.
---Reference layers are excluded.
---@param layer Layer parent layer
---@param array Layer[] leaves array
---@param includeLocked? boolean include locked layers
---@param includeHidden? boolean include hidden layers
---@param includeTiles? boolean include tile maps
---@param includeBkg? boolean include backgrounds
---@return Layer[]
function AseUtilities.appendLeaves(
    layer, array, includeLocked, includeHidden, includeTiles, includeBkg)
    -- First, check properties passed by parents to their children.
    if (includeLocked or layer.isEditable)
        and (includeHidden or layer.isVisible) then
        if layer.isGroup then
            -- Using type annotation causes syntax highlight bug when looking
            -- at the code on Github.
            local childLayers <const> = layer.layers
            if childLayers then
                local append <const> = AseUtilities.appendLeaves
                local lenChildLayers <const> = #childLayers
                local i = 0
                while i < lenChildLayers do
                    i = i + 1
                    append(childLayers[i], array,
                        includeLocked, includeHidden,
                        includeTiles, includeBkg)
                end
            end
        elseif (not layer.isReference)
            and (includeTiles or (not layer.isTilemap))
            and (includeBkg or (not layer.isBackground)) then
            -- Leaf order should be what's ideal for composition, with
            -- ascending stack indices.
            array[#array + 1] = layer
        end
    end
    return array
end

---Copies an Aseprite Color object by sRGB channel values. This is to prevent
---accidental pass by reference. The Color constructor does no bounds checking
---for [0, 255]. If the flag is "UNBOUNDED", then the raw values are used. If
---the flag is "MODULAR," this will copy by hexadecimal value, and hence use
---modular arithmetic. The default is saturation arithmetic. For more, see
---https://www.wikiwand.com/en/Modular_arithmetic .
---@param aseColor Color aseprite color
---@param flag string out of bounds interpretation
---@return Color
---@nodiscard
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

---Converts an Aseprite Color object to a Clr. Both Aseprite Color and Clr
---allow arguments to exceed the expected ranges, [0, 255] and [0.0, 1.0],
---respectively.
---@param aseColor Color aseprite color
---@return Clr
---@nodiscard
function AseUtilities.aseColorToClr(aseColor)
    return Clr.new(
        aseColor.red / 255.0,
        aseColor.green / 255.0,
        aseColor.blue / 255.0,
        aseColor.alpha / 255.0)
end

---Converts an Aseprite color object to an integer. The meaning of the integer
---depends on the color mode: the RGB integer is 32 bits. GRAY, 16. INDEXED, 8.
---Returns zero if the color mode is not recognized.
---
---For RGB, uses modular arithmetic, i.e., does not check if red, green, blue
---and alpha channels are out of range [0, 255].
---
---For grayscale, uses Aseprite's definition of relative luminance, not HSL
---lightness.
---
---For indexed, may return an index that is greater than the range of one byte,
---[0, 255].
---@param clr Color aseprite color
---@param clrMode ColorMode color mode
---@return integer
---@nodiscard
function AseUtilities.aseColorToHex(clr, clrMode)
    if clrMode == ColorMode.RGB then
        return (clr.alpha << 0x18)
            | (clr.blue << 0x10)
            | (clr.green << 0x08)
            | clr.red
    elseif clrMode == ColorMode.GRAY then
        -- Color:grayPixel depends on HSL lightness, not on the user gray
        -- conversion preference (HSL, HSV or luma). See
        -- https://github.com/aseprite/aseprite/blob/main/src/app/color.cpp#L821
        -- https://github.com/aseprite/aseprite/blob/main/src/doc/color.h#L62
        -- and app.preferences.quantization.to_gray .
        local sr <const> = clr.red
        local sg <const> = clr.green
        local sb <const> = clr.blue
        -- Prioritize consistency with grayscale convert over correctness.
        -- For comparison, see
        -- https://www.w3.org/TR/compositing-1/#blendingnonseparable .
        -- local gray <const> = (sr * 30 + sg * 59 + sb * 11) // 100
        local gray <const> = (sr * 2126 + sg * 7152 + sb * 722) // 10000
        return (clr.alpha << 0x08) | gray
    elseif clrMode == ColorMode.INDEXED then
        return clr.index
    end
    return 0
end

---Loads a palette based on a string. The string is expected to be either
---"FILE" or "ACTIVE". The correctZeroAlpha flag replaces zero alpha
---colors with clear black, regardless of RGB channel values.
---
---Returns a tuple of tables. The first table is an array of hexadecimals
---according to the sprite color profile. The second is a copy of the first
---converted to sRGB.
---
---If a palette is loaded from a filepath, the two tables should match, as
---Aseprite does not support color management for palettes.
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
                -- Loading an .aseprite file with multiple palettes will
                -- register only the first palette. Also may be problems with
                -- color profiles being ignored?
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
        local palActSpr <const> = app.sprite
        if palActSpr ~= nil then
            local modeAct <const> = palActSpr.colorMode
            if modeAct == ColorMode.GRAY then
                local grCntVrf = AseUtilities.GRAY_COUNT
                if count then grCntVrf = math.min(count, 256) end
                hexesProfile = AseUtilities.grayHexes(grCntVrf)
            else
                hexesProfile = AseUtilities.asePalettesToHexArr(
                    palActSpr.palettes)
                local profileAct <const> = palActSpr.colorSpace
                if profileAct ~= nil then
                    -- Tests a number of color profile components for
                    -- approximate equality. See
                    -- https://github.com/aseprite/laf/blob/main/gfx/color_space.cpp#L107

                    -- It might be safer not to treat the NONE color space as
                    -- equivalent to sRGB, as the user could have a display
                    -- profile which differs radically.
                    local profileSrgb <const> = ColorSpace { sRGB = true }
                    if profileAct ~= profileSrgb then
                        palActSpr:convertColorSpace(profileSrgb)
                        hexesSrgb = AseUtilities.asePalettesToHexArr(
                            palActSpr.palettes)
                        palActSpr:convertColorSpace(profileAct)
                    end -- End unequal profiles.
                end     -- End profile exists.
            end         -- End color mode check.
        end             -- End sprite exists.
    end                 -- End pal type block.

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

    -- Replace colors, e.g., 0x00ff0000, so that all are clear black. Since
    -- both arrays should have the same length, avoid safety of separate loops.
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

---Converts an Aseprite palette to a table of hex color integers. If the
---palette is nil, returns a default table. Assumes palette is in sRGB. The
---start index defaults to 0. The count defaults to 256.
---@param pal Palette aseprite palette
---@param startIndex integer? start index
---@param count integer? sample count
---@return integer[]
---@nodiscard
function AseUtilities.asePaletteToHexArr(pal, startIndex, count)
    if pal then
        local lenPal <const> = #pal

        local si <const> = math.min(math.max(startIndex or 0, 0), lenPal - 1)
        local vc <const> = math.min(math.max(count or 256, 2), lenPal - si)

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

---Converts an array of Aseprite palettes to a table of hex color integers.
---@param palettes Palette[] Aseprite palettes
---@return integer[]
---@nodiscard
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
                    local hex <const> = convert(aseColor, rgbColorMode)
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

---Finds the average color of a selection in a sprite. If there is no selection,
---tries getting the color at the editor mouse position. Calculates the average
---in the SR LAB 2 color space.
---@param sprite Sprite
---@param frame Frame|integer
---@return { l: number, a: number, b: number, alpha: number }
---@nodiscard
function AseUtilities.averageColor(sprite, frame)
    local sprSpec <const> = sprite.spec
    local colorMode <const> = sprSpec.colorMode
    local alphaIndex <const> = sprSpec.transparentColor
    local colorSpace <const> = sprSpec.colorSpace

    local sel <const>,
    isValid <const> = AseUtilities.getSelection(sprite)

    local flat = nil
    if isValid then
        flat, _, _ = AseUtilities.imageFromSel(
            sel, sprite, frame)
    else
        local x <const>, y <const> = AseUtilities.getMouse()
        local mouseSpec <const> = ImageSpec {
            width = 1,
            height = 1,
            colorMode = colorMode,
            transparentColor = alphaIndex
        }
        mouseSpec.colorSpace = colorSpace
        flat = Image(mouseSpec)
        flat:drawSprite(sprite, frame, Point(-x, -y))
    end

    local flatBytes <const> = flat.bytes
    local wFlat <const> = flat.width
    local hFlat <const> = flat.height
    local areaFlat <const> = wFlat * hFlat

    local strunpack <const> = string.unpack
    local strsub <const> = string.sub

    -- The key is the color in hex. The value is a number of pixels with that
    -- color in the selection. This tally is for the average.
    ---@type table<integer, integer>
    local hd <const> = {}
    if colorMode == ColorMode.INDEXED then
        local aseToHex <const> = AseUtilities.aseColorToHex
        local strbyte <const> = string.byte

        local palette <const> = AseUtilities.getPalette(frame, sprite.palettes)
        local lenPalette <const> = #palette
        local cmRgb <const> = ColorMode.RGB
        local hasBkg <const> = sprite.backgroundLayer ~= nil
            and sprite.backgroundLayer.isVisible

        local i = 0
        while i < areaFlat do
            i = i + 1
            local idx <const> = strbyte(flatBytes, i)
            if (idx ~= alphaIndex or hasBkg)
                and idx >= 0 and idx < lenPalette then
                local aseColor <const> = palette:getColor(idx)
                if aseColor.alpha > 0 then
                    local abgr32 <const> = aseToHex(aseColor, cmRgb)
                    local q <const> = hd[abgr32]
                    if q then hd[abgr32] = q + 1 else hd[abgr32] = 1 end
                end -- End color alpha gt zero.
            end     -- End map index is in bounds.
        end         -- End pixel loop.
    elseif colorMode == ColorMode.GRAY then
        local i = 0
        while i < areaFlat do
            local i2 <const> = i * 2
            local av16 <const> = strunpack("<I2", strsub(
                flatBytes, 1 + i2, 2 + i2))
            local a8 <const> = av16 >> 0x08 & 0xff
            if a8 > 0 then
                local v8 <const> = av16 & 0xff
                local abgr32 <const> = a8 << 0x18 | v8 << 0x10 | v8 << 0x08 | v8
                local q <const> = hd[abgr32]
                if q then hd[abgr32] = q + 1 else hd[abgr32] = 1 end
            end
            i = i + 1
        end
    else
        -- Default to RGB color mode.
        local i = 0
        while i < areaFlat do
            local i4 <const> = i * 4
            local abgr32 <const> = strunpack("<I4", strsub(
                flatBytes, 1 + i4, 4 + i4))
            if (abgr32 & 0xff000000) ~= 0 then
                local q <const> = hd[abgr32]
                if q then hd[abgr32] = q + 1 else hd[abgr32] = 1 end
            end
            i = i + 1
        end
    end

    local lSum, aSum, bSum, alphaSum = 0.0, 0.0, 0.0, 0.0
    local count = 0

    local fromHex <const> = Clr.fromHexAbgr32
    local sRgbToLab <const> = Clr.sRgbToSrLab2
    for hex, tally in pairs(hd) do
        local lab <const> = sRgbToLab(fromHex(hex))
        lSum = lSum + lab.l * tally
        aSum = aSum + lab.a * tally
        bSum = bSum + lab.b * tally
        alphaSum = alphaSum + lab.alpha * tally
        count = count + tally
    end

    if count > 0 and alphaSum > 0.0 then
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

---Finds the average color of a selection in a sprite. Treats the color as a
---normal used in a normal map. If the sprite color mode is not RGB, returns
---up direction.
---@param sprite Sprite
---@param frame Frame|integer
---@return Vec3
---@nodiscard
function AseUtilities.averageNormal(sprite, frame)
    local sprSpec <const> = sprite.spec
    local colorMode <const> = sprSpec.colorMode
    if colorMode ~= ColorMode.RGB then return Vec3.up() end
    local alphaIndex <const> = sprSpec.transparentColor
    local colorSpace <const> = sprSpec.colorSpace

    local sel <const>,
    isValid <const> = AseUtilities.getSelection(sprite)

    local flat = nil
    if isValid then
        flat, _, _ = AseUtilities.imageFromSel(
            sel, sprite, frame)
    else
        local x <const>, y <const> = AseUtilities.getMouse()
        local mouseSpec <const> = ImageSpec {
            width = 1,
            height = 1,
            colorMode = colorMode,
            transparentColor = alphaIndex
        }
        mouseSpec.colorSpace = colorSpace
        flat = Image(mouseSpec)
        flat:drawSprite(sprite, frame, Point(-x, -y))
    end

    local flatBytes <const> = flat.bytes
    local wFlat <const> = flat.width
    local hFlat <const> = flat.height
    local areaFlat <const> = wFlat * hFlat

    local abs <const> = math.abs
    local strbyte <const> = string.byte

    local xSum, ySum, zSum = 0.0, 0.0, 0.0

    local i = 0
    while i < areaFlat do
        local i4 <const> = i * 4
        local a8 <const> = strbyte(flatBytes, 4 + i4)
        if a8 > 0 then
            local r8 <const>, g8 <const>, b8 <const> = strbyte(
                flatBytes, 1 + i4, 3 + i4)

            local x = (r8 + r8 - 255) / 255.0
            local y = (g8 + g8 - 255) / 255.0
            local z = (b8 + b8 - 255) / 255.0

            if abs(x) < 0.0039216 then x = 0.0 end
            if abs(y) < 0.0039216 then y = 0.0 end
            if abs(z) < 0.0039216 then z = 0.0 end

            xSum = xSum + x
            ySum = ySum + y
            zSum = zSum + z
        end
        i = i + 1
    end

    local mSq <const> = xSum * xSum + ySum * ySum + zSum * zSum
    if mSq > 0.0 then
        local mInv <const> = 1.0 / math.sqrt(mSq)
        return Vec3.new(xSum * mInv, ySum * mInv, zSum * mInv)
    end

    return Vec3.up()
end

---Transforms a source image according to a flipping flag. If the flag is valid,
---returns a transformed copy of the image and a boolean true. If not, returns
---the source image by reference and a boolean false.
---@param source Image source image
---@param flag integer flipping flag
---@return Image
---@return boolean
function AseUtilities.bakeFlag(source, flag)
    -- https://github.com/aseprite/aseprite/blob/main/src/doc/tile.h#L24
    if flag == 0x20000000 then     -- D
        return AseUtilities.transposeImage(source), true
    elseif flag == 0x40000000 then -- Y
        return AseUtilities.flipImageY(source), true
    elseif flag == 0x60000000 then -- Y | D
        return AseUtilities.rotateImage90(source), true
    elseif flag == 0x80000000 then -- X
        return AseUtilities.flipImageX(source), true
    elseif flag == 0xa0000000 then -- X | D
        return AseUtilities.rotateImage270(source), true
    elseif flag == 0xc0000000 then -- X | Y
        return AseUtilities.rotateImage180(source), true
    elseif flag == 0xe0000000 then -- X | Y | D
        return AseUtilities.flipImageAll(source), true
    end
    return source, false
end

---Converts a sprite's background layer, if any, to a normal layer. Uses the
---method Sprite.backgroundLayer to determine this. If a background has been
---childed to a group, this may fail. Returns true if a background was found
---and converted. Otherwise, returns false. Ignores linked cels. Always sets
---the new layer to stack index 1, parented to the sprite.
---@param sprite Sprite sprite
---@param overrideLock boolean? ignore layer lock
---@returns boolean
function AseUtilities.bkgToLayer(sprite, overrideLock)
    local bkgLayer <const> = sprite.backgroundLayer
    if bkgLayer and (overrideLock or bkgLayer.isEditable) then
        local unBkgLayer <const> = sprite:newLayer()
        unBkgLayer.color = bkgLayer.color
        unBkgLayer.data = bkgLayer.data
        unBkgLayer.isEditable = bkgLayer.isEditable
        unBkgLayer.isVisible = bkgLayer.isVisible
        unBkgLayer.isContinuous = bkgLayer.isContinuous
        unBkgLayer.name = "Bkg"
        -- Attempting to copy properties field by reference will cause crash.

        local lenFrObjs <const> = #sprite.frames
        local i = 0
        while i < lenFrObjs do
            i = i + 1
            local bkgCel <const> = bkgLayer:cel(i)
            if bkgCel then
                local bkgCelPos <const> = bkgCel.position
                local bkgImage <const> = bkgCel.image
                local unBkgCel <const> = sprite:newCel(unBkgLayer, i,
                    bkgImage, bkgCelPos)
                unBkgCel.color = bkgCel.color
                unBkgCel.data = bkgCel.data
                unBkgCel.zIndex = bkgCel.zIndex
            end
        end

        sprite:deleteLayer(bkgLayer)
        unBkgLayer.stackIndex = 1
        return true
    end
    return false
end

---Blends a backdrop and overlay image, creating a union image from the two
---sources. The union then intersects with a selection. If a selection is empty,
---or is not provided, a new selection is created from the union. If the
---cumulative flag is true, the backdrop image is sampled regardless of its
---inclusion in the selection. Returns a new, blended image and its top left
---corner. Does not support tile maps or images with mismatched color modes.
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
    -- Because this method uses a mask and offers a cumulative option, it can't
    -- be replaced by drawImage in 1.3rc-2, which supports blend modes. This
    -- can also be used as a polyfill for indexed color mode.

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
        selVrf = Selection(Rectangle(xMin, yMin, wTarget, hTarget))
    end

    local trgMask = 0
    if uMask == oMask and uMask >= 0 and uMask < 256 then
        trgMask = uMask
    end
    local modeTarget <const> = ucm

    local trgSpec <const> = ImageSpec {
        width = wTarget,
        height = hTarget,
        colorMode = modeTarget,
        transparentColor = trgMask
    }
    trgSpec.colorSpace = uSpec.colorSpace
    local target <const> = Image(trgSpec)

    -- Avoid tile map images and mismatched image modes.
    if (ucm ~= ocm) or ucm == ColorMode.TILEMAP then
        return target, 0, 0
    end

    -- Offset needed when reading from source images into target image.
    local uxDiff <const> = uxcVrf - xMin
    local uyDiff <const> = uycVrf - yMin
    local oxDiff <const> = oxcVrf - xMin
    local oyDiff <const> = oycVrf - yMin

    ---@type string[]
    local uStrs <const> = {}
    local uBytes <const> = under.bytes
    local uBpp <const> = under.bytesPerPixel
    local uDefault <const> = (ucm == ColorMode.INDEXED
            and (uMask < 0 or uMask > 255))
        and string.pack("<I" .. uBpp, 0)
        or string.pack("<I" .. uBpp, uMask)

    ---@type string[]
    local oStrs <const> = {}
    local oBytes <const> = over.bytes
    local oBpp <const> = over.bytesPerPixel
    local oDefault <const> = (ocm == ColorMode.INDEXED
            and (oMask < 0 or oMask > 255))
        and string.pack("<I" .. oBpp, 0)
        or string.pack("<I" .. oBpp, oMask)

    local getPixel <const> = Utilities.getPixelOmit
    local strbyte <const> = string.byte

    local lenFlat <const> = wTarget * hTarget
    local i = 0
    while i < lenFlat do
        local xPixel <const> = i % wTarget
        local yPixel <const> = i // wTarget

        local xSmpl <const> = xPixel + xMin
        local ySmpl <const> = yPixel + yMin
        local isContained <const> = selVrf:contains(xSmpl, ySmpl)

        local uStr = uDefault
        if cmVrf or isContained then
            local ux <const> = xPixel - uxDiff
            local uy <const> = yPixel - uyDiff
            uStr = getPixel(uBytes, ux, uy, uw, uh, uBpp, uDefault)
        end

        local oStr = oDefault
        if isContained then
            local ox <const> = xPixel - oxDiff
            local oy <const> = yPixel - oyDiff
            oStr = getPixel(oBytes, ox, oy, ow, oh, oBpp, oDefault)
        end

        i = i + 1
        uStrs[i] = uStr
        oStrs[i] = oStr
    end

    ---@type string[]
    local trgBytes <const> = {}
    if modeTarget == ColorMode.INDEXED then
        local blend <const> = AseUtilities.blendIndices
        local strchar <const> = string.char
        local j = 0
        while j < lenFlat do
            j = j + 1
            local uStr <const> = uStrs[j]
            local oStr <const> = oStrs[j]
            local aa <const> = strbyte(uStr)
            local ba <const> = strbyte(oStr)
            local ca <const> = blend(aa, ba, trgMask)
            trgBytes[j] = strchar(ca)
        end
    elseif modeTarget == ColorMode.GRAY then
        local blend <const> = AseUtilities.blendGray
        local strpack <const> = string.pack
        local j = 0
        while j < lenFlat do
            j = j + 1
            local uStr <const> = uStrs[j]
            local oStr <const> = oStrs[j]
            local ag <const>, aa <const> = strbyte(uStr, 1, 2)
            local bg <const>, ba <const> = strbyte(oStr, 1, 2)
            local cg <const>, ca <const> = blend(ag, aa, bg, ba)
            trgBytes[j] = strpack("B B", cg, ca)
        end
    else
        local blend <const> = AseUtilities.blendRgba
        local strpack <const> = string.pack
        local j = 0
        while j < lenFlat do
            j = j + 1
            local uStr <const> = uStrs[j]
            local oStr <const> = oStrs[j]
            local ar <const>, ag <const>, ab <const>, aa <const> = strbyte(uStr, 1, 4)
            local br <const>, bg <const>, bb <const>, ba <const> = strbyte(oStr, 1, 4)
            local cr <const>, cg <const>, cb <const>, ca <const> = blend(
                ar, ag, ab, aa, br, bg, bb, ba)
            trgBytes[j] = strpack("B B B B", cr, cg, cb, ca)
        end
    end

    target.bytes = table.concat(trgBytes, "")
    return target, xMin, yMin
end

---Blends two gray colors. Premultiplies each color by its alpha prior
---to blending. Unpremultiplies the result.
---@param ag integer backdrop gray
---@param aa integer backdrop alpha
---@param bg integer overlay gray
---@param ba integer overlay alpha
---@return integer cg blend gray
---@return integer ca blend alpha
---@nodiscard
function AseUtilities.blendGray(ag, aa, bg, ba)
    if ba > 0xfe or aa < 0x01 then return bg, ba end

    local t = ba
    local u <const> = 0xff - t
    if t > 0x7f then t = t + 1 end

    local uv <const> = (aa * u) // 0xff
    local tuv = t + uv
    if tuv < 0x01 then return 0, 0 end
    if tuv > 0xff then tuv = 0xff end

    local cg = (bg * t + ag * uv) // tuv
    if cg > 0xff then cg = 0xff end
    return cg, tuv
end

---Blends two indexed image colors. Prioritizes the overlay color, so long as
---it does not equal the mask index. Assumes backdrop and overlay use the same
---mask index.
---@param a integer backdrop color
---@param b integer overlay color
---@param alphaIndex integer alpha index
---@return integer
---@nodiscard
function AseUtilities.blendIndices(a, b, alphaIndex)
    if b ~= alphaIndex then return b end
    if a ~= alphaIndex then return a end
    return alphaIndex
end

---Blends two RGBA colors. Premultiplies each color by its alpha prior
---to blending. Unpremultiplies the result. For more information, see
---https://www.w3.org/TR/compositing-1/ .
---@param ar integer backdrop red
---@param ag integer backdrop green
---@param ab integer backdrop blue
---@param aa integer backdrop alpha
---@param br integer overlay red
---@param bg integer overlay green
---@param bb integer overlay blue
---@param ba integer overlay alpha
---@return integer cr blend red
---@return integer cg blend green
---@return integer cb blend blue
---@return integer ca blend alpha
---@nodiscard
function AseUtilities.blendRgba(
    ar, ag, ab, aa,
    br, bg, bb, ba)
    if ba > 0xfe or aa < 0x01 then return br, bg, bb, ba end

    local t = ba
    local u <const> = 0xff - t
    if t > 0x7f then t = t + 1 end

    local uv <const> = (aa * u) // 0xff
    local tuv = t + uv
    if tuv < 0x01 then return 0, 0, 0, 0 end
    if tuv > 0xff then tuv = 0xff end

    local cb = (bb * t + ab * uv) // tuv
    local cg = (bg * t + ag * uv) // tuv
    local cr = (br * t + ar * uv) // tuv

    if cb > 0xff then cb = 0xff end
    if cg > 0xff then cg = 0xff end
    if cr > 0xff then cr = 0xff end

    return cr, cg, cb, tuv
end

---Changes the active swatch in the color bar via a step.
---If the site is in tile map mode, then changes the active tile,
---otherwise changes the palette swatch.
---@param step integer step
---@param useBack boolean use background
function AseUtilities.changeActiveSwatch(step, useBack)
    local site <const> = app.site
    local activeSprite <const> = site.sprite
    if not activeSprite then return end

    local tilemapMode <const> = site.tilemapMode
    local activeLayer <const> = site.layer
        or activeSprite.layers[1]

    if tilemapMode == TilemapMode.TILES
        and activeLayer.isTilemap then
        local tileSet <const> = activeLayer.tileset
        if not tileSet then return end
        local lenTileSet <const> = #tileSet

        local field <const> = useBack and "bgTile" or "fgTile"
        local tifCurr <const> = app[field] --[[@as integer]]
        local tiCurr <const> = app.pixelColor.tileI(tifCurr)
        if tiCurr >= lenTileSet or tiCurr < 0 then
            app[field] = 0
        else
            local tfCurr <const> = app.pixelColor.tileF(tifCurr)
            local tiNext <const> = (tiCurr + step) % lenTileSet
            app[field] = app.pixelColor.tile(tiNext, tfCurr)
        end
    else
        local activeFrObj <const> = site.frame
            or activeSprite.frames[1]
        local palette <const> = AseUtilities.getPalette(
            activeFrObj, activeSprite.palettes)
        local lenPalette <const> = #palette

        if useBack then app.command.SwitchColors() end
        local idxCurr <const> = app.fgColor.index
        if idxCurr >= lenPalette or idxCurr < 0 then
            app.fgColor = palette:getColor(0)
        else
            local idxNext <const> = (idxCurr + step) % lenPalette
            app.fgColor = palette:getColor(idxNext)
        end
        if useBack then app.command.SwitchColors() end
    end
end

---Wrapper for app.command.ChangePixelFormat to accept ColorMode
---as an input.
---@param format ColorMode format constant
function AseUtilities.changePixelFormat(format)
    if format == ColorMode.INDEXED then
        app.command.ChangePixelFormat { format = "indexed" }
    elseif format == ColorMode.GRAY then
        app.command.ChangePixelFormat { format = "gray" }
    elseif format == ColorMode.RGB then
        app.command.ChangePixelFormat { format = "rgb" }
    end
end

---Generates an image with a checker pattern. For creating
---backgrounds onto which images with alpha may be blit.
---The colors should be integers with matching bytes per
---pixel to the image.
---@param wImg integer image width
---@param hImg integer image height
---@param wCheck integer checker width
---@param hCheck integer checker height
---@param aColor integer first checker hex
---@param bColor integer second checker hex
---@param colorMode? ColorMode color mode
---@param colorSpace? ColorSpace color space
---@param alphaIndex? integer transparent color
---@returns Image
---@nodiscard
function AseUtilities.checkerImage(
    wImg, hImg, wCheck, hCheck, aColor, bColor,
    colorMode, colorSpace, alphaIndex)
    local trgSpec <const> = AseUtilities.createSpec(
        wImg, hImg, colorMode, colorSpace, alphaIndex)
    local trgImg <const> = Image(trgSpec)
    trgImg.bytes = Utilities.checker(
        trgSpec.width, trgSpec.height, trgImg.bytesPerPixel,
        wCheck, hCheck, aColor, bColor)
    return trgImg
end

---Converts a Clr to an Aseprite Color. Assumes that source and target are in
---sRGB. Clamps the Clr's channels to [0.0, 1.0] before they are converted.
---Beware that this could return (255, 0, 0, 0) or (0, 255, 0, 0), which may be
---visually indistinguishable from - and confused with - an alpha mask.
---@param clr Clr clr
---@return Color
---@nodiscard
function AseUtilities.clrToAseColor(clr)
    return Color {
        r = math.floor(math.min(math.max(clr.r, 0.0), 1.0) * 255.0 + 0.5),
        g = math.floor(math.min(math.max(clr.g, 0.0), 1.0) * 255.0 + 0.5),
        b = math.floor(math.min(math.max(clr.b, 0.0), 1.0) * 255.0 + 0.5),
        a = math.floor(math.min(math.max(clr.a, 0.0), 1.0) * 255.0 + 0.5)
    }
end

---Creates new cels in a sprite. Prompts users to confirm if requested count
---exceeds a limit. The count is derived from frameCount x layerCount. Returns
---a one-dimensional table of cels, where layers are treated as rows, frames
---are treated as columns and the flat ordering is row-major. To assign a GUI
---color, use a hexadecimal integer as an argument. Returns a table of layers.
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
        cels[i] = sprite:newCel(layerObj, frameObj, valImg, valPos)
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

---Creates new empty frames in a sprite. Prompts user to confirm if requested
---count exceeds a limit. Returns a table of frames. Frame duration is assumed
---to have been divided by 1000.0, and ready to be assigned as is.
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

---Creates new layers in a sprite. Prompts user to confirm if requested count
---exceeds a limit. Wraps the process in an app.transaction. To assign a GUI
-- color, use a hexadecimal integer as an argument. Returns a table of layers.
---@param sprite Sprite sprite
---@param count integer number of layers to create
---@param blendMode BlendMode? blend mode
---@param opacity integer? layer opacity
---@param guiClr integer? rgba color
---@return Layer[]
function AseUtilities.createLayers(
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

---Creates a new ImageSpec. Width and height will be clamped to [1, 32767].
---If they are not defined, they default to new file preferences. The color
---mode defaults to RGB. The transparent color defaults to zero. If a color
---space is provided, it is assigned to the spec after construction. Otherwise,
---assigns an sRGB color space.
---@param width? integer image width
---@param height? integer image height
---@param colorMode? ColorMode color mode
---@param colorSpace? ColorSpace color space
---@param alphaIndex? integer transparent color
---@return ImageSpec
---@nodiscard
function AseUtilities.createSpec(
    width, height, colorMode, colorSpace, alphaIndex)
    local cmVerif <const> = colorMode or ColorMode.RGB

    -- transparentColor is an unsigned integer. Setting it to a negative
    -- number will wrap to a large positive, e.g., 4294967295, and when the
    -- file is saved an error will be raised.
    local tcVerif = 0
    if alphaIndex and alphaIndex >= 0 then
        tcVerif = alphaIndex
    end

    local wVerif = 320
    if width then
        wVerif = math.min(math.max(math.abs(width), 1), 32767)
    else
        wVerif = app.preferences.new_file.width --[[@as integer]]
    end

    local hVerif = 180
    if height then
        hVerif = math.min(math.max(math.abs(height), 1), 32767)
    else
        hVerif = app.preferences.new_file.height --[[@as integer]]
    end

    local spec <const> = ImageSpec {
        width = wVerif,
        height = hVerif,
        colorMode = cmVerif,
        transparentColor = tcVerif
    }

    if colorSpace then
        spec.colorSpace = colorSpace
    else
        spec.colorSpace = ColorSpace { sRGB = true }
    end

    return spec
end

---Creates a sprite from an ImageSpec. Gets the sprite's document preferences,
---turns off "Loop through tag frames" property. Turns on timeline overlays.
---The file name argument is not validated by the method.
---@param spec ImageSpec specification
---@param fileName? string file name
---@return Sprite
---@nodiscard
function AseUtilities.createSprite(spec, fileName)
    -- Do not allow slices UI interface to be active.
    local appPrefs <const> = app.preferences
    local appTool <const> = app.tool
    if appTool then
        if appTool.id == "slice" then
            app.tool = "hand"
        end

        -- Set ink to simple. If it's set after sprite creation then the UI
        -- won't update. Problem here is that multiple tools use an ink.
        -- If one of these tools isn't active, then its ink type won't be
        -- changed. Also, "share across tools" setting may or may not be true.
        -- if appPrefs then
        -- This should use the current tool, not the cached one.
        -- local toolPrefs <const> = appPrefs.tool(app.tool)
        -- if toolPrefs.ink then toolPrefs.ink = Ink.SIMPLE end
        -- end
    end

    local sprite <const> = Sprite(spec)
    if fileName and #fileName > 0 then sprite.filename = fileName end

    if appPrefs then
        -- https://community.aseprite.org/t/vertical-skewing-broken-when-pivot-is-set-to-the-right/
        -- https://steamcommunity.com/app/431730/discussions/2/4356743320309073149/
        -- appPrefs.selection.pivot_position = 4

        -- appPrefs.experimental.nonactive_layers_opacity and ... _preview can
        -- cause confusion, as only one layer will be visible at a time and the
        -- setting may default to zero in some cases?

        -- It's overkill to handle sprite.pixelRatio (a Size) here. Handle it in
        -- newSpritePlus and spriteProps, if at all. See also
        -- appPrefs.new_file.pixel_ratio, a string, "1:2", "2:1", "1:1" .

        -- https://steamcommunity.com/app/431730/discussions/2/3803906367798695226/
        local docPrefs <const> = appPrefs.document(sprite)
        if docPrefs then
            local onionSkinPrefs <const> = docPrefs.onionskin
            if onionSkinPrefs then
                onionSkinPrefs.loop_tag = false
            end

            -- Default overlay_size is 5.
            local thumbPrefs <const> = docPrefs.thumbnails
            if thumbPrefs then
                thumbPrefs.enabled = true
                thumbPrefs.zoom = 1
                thumbPrefs.overlay_enabled = true
            end
        end
    end

    return sprite
end

---Draws a filled circle. Uses the Aseprite Image instance method drawPixel.
---This means that the pixel changes will not be tracked as a transaction.
---@param pixels integer[] pixels
---@param wImage integer image width
---@param xc integer center x
---@param yc integer center y
---@param r integer radius
---@param rFill integer fill red
---@param gFill integer fill red
---@param bFill integer fill red
---@param aFill integer fill red
---@return integer[]
function AseUtilities.drawCircleFill(
    pixels, wImage, xc, yc, r,
    rFill, gFill, bFill, aFill)
    local blend <const> = AseUtilities.blendRgba
    local rsq <const> = r * r
    local r2 <const> = r + r
    local lenn1 <const> = r2 * r2 - 1
    local i = -1
    while i < lenn1 do
        i = i + 1
        local x <const> = (i % r2) - r
        local y <const> = (i // r2) - r
        if (x * x + y * y) < rsq then
            local xMark <const> = xc + x
            local yMark <const> = yc + y
            local j4 <const> = 4 * (yMark * wImage + xMark)

            local rTrg <const>,
            gTrg <const>,
            bTrg <const>,
            aTrg <const> = blend(pixels[1 + j4], pixels[2 + j4],
                pixels[3 + j4], pixels[4 + j4], rFill, gFill, bFill, aFill)

            pixels[1 + j4] = rTrg
            pixels[2 + j4] = gTrg
            pixels[3 + j4] = bTrg
            pixels[4 + j4] = aTrg
        end
    end

    return pixels
end

---Blits input image onto another that is the next power of 2 in dimension. The
---nonUniform flag specifies whether the result can have unequal width and
---height, e.g., 64x32. Returns the image by reference if its size is already
---a power of 2.
---@param img Image image
---@param nonUniform? boolean non uniform dimensions
---@return Image
---@nodiscard
function AseUtilities.expandImageToPow2(img, nonUniform)
    local srcSpec <const> = img.spec
    local wOrig <const> = srcSpec.width
    local hOrig <const> = srcSpec.height
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
        colorMode = srcSpec.colorMode,
        transparentColor = srcSpec.transparentColor
    }
    if srcSpec.colorSpace then potSpec.colorSpace = srcSpec.colorSpace end
    local potImg <const> = Image(potSpec)
    potImg:drawImage(img, Point(0, 0), 255, BlendMode.SRC)

    return potImg
end

---Finds a filtered array of cels to be edited in-place according to the
---provided criteria. The target is a string constant that could be "ALL",
---"ACTIVE", "RANGE" or "SELECTION".
---
---The selection option will create a new layer and cel.
---@param sprite Sprite active sprite
---@param layer Layer|nil active layer
---@param frames Frame[]|integer[] frames
---@param target string target preset
---@param includeLocked? boolean include locked layers
---@param includeHidden? boolean include hidden layers
---@param includeTiles? boolean include tile maps
---@param includeBkg? boolean include backgrounds
---@return Cel[]
function AseUtilities.filterCels(
    sprite, layer, frames, target,
    includeLocked, includeHidden, includeTiles, includeBkg)
    if target == "ALL" then
        local leaves <const> = AseUtilities.filterLayers(sprite, layer, target,
            includeLocked, includeHidden, includeTiles, includeBkg)
        return AseUtilities.getUniqueCelsFromLeaves(leaves, sprite.frames)
    elseif target == "RANGE" then
        local leaves <const> = AseUtilities.filterLayers(sprite, layer,
            target, includeLocked, includeHidden, includeTiles, includeBkg)
        local frIdcs <const> = Utilities.flatArr2(AseUtilities.getFrames(
            sprite, target, false))
        return AseUtilities.getUniqueCelsFromLeaves(leaves, frIdcs)
    elseif target == "SELECTION" then
        local trgCels <const> = {}
        local lenTrgCels = 0
        local sel <const>, _ <const> = AseUtilities.getSelection(sprite)
        local imageFromSel <const> = AseUtilities.imageFromSel

        app.transaction("Selection Layer", function()
            local srcLayer <const> = sprite:newLayer()
            srcLayer.name = "Selection"

            local lenFrames <const> = #frames
            local i = 0
            while i < lenFrames do
                i = i + 1
                local srcFrame <const> = frames[i]
                local selImage <const>,
                xSel <const>,
                ySel <const> = imageFromSel(sel, sprite, srcFrame)

                -- Avoid empty cels.
                if not selImage:isEmpty() then
                    local trgCel <const> = sprite:newCel(
                        srcLayer, srcFrame,
                        selImage, Point(xSel, ySel))
                    lenTrgCels = lenTrgCels + 1
                    trgCels[lenTrgCels] = trgCel
                end
            end
        end)

        return trgCels
    else
        -- Default to "ACTIVE"
        local leaves <const> = AseUtilities.filterLayers(sprite, layer, target,
            includeLocked, includeHidden, includeTiles, includeBkg)
        return AseUtilities.getUniqueCelsFromLeaves(leaves, frames)
    end
end

---Finds a filtered array of layers to be edited in-place according to the
---provided criteria. The target is a string constant that could be "ALL",
---"ACTIVE", "RANGE". When the target is "ACTIVE", this includes the children
---of the active layer if it's a group.
---
---Visibility and editability are only considered locally. It's assumed that if
---the user selects a child layer whose parent is locked or hidden, they
---intended to do so.
---
---Layers retrieved from a range may not be in stack index order.
---@param sprite Sprite active sprite
---@param layer Layer|nil active layer
---@param target string target preset
---@param includeLocked? boolean include locked layers
---@param includeHidden? boolean include hidden layers
---@param includeTiles? boolean include tile maps
---@param includeBkg? boolean include backgrounds
---@return Layer[]
---@nodiscard
function AseUtilities.filterLayers(
    sprite, layer, target,
    includeLocked, includeHidden, includeTiles, includeBkg)
    -- TODO: Are there other, older dialogs where this can be used?

    if target == "ALL" then
        return AseUtilities.getLayerHierarchy(sprite,
            includeLocked, includeHidden, includeTiles, includeBkg)
    elseif target == "RANGE" then
        ---@type Layer[]
        local trgLayers = {}

        local tlHidden <const> = not app.preferences.general.visible_timeline --[[@as boolean]]
        if tlHidden then
            app.command.Timeline { open = true }
        end

        local range <const> = app.range
        if range.sprite == sprite then
            if range.type == RangeType.FRAMES then
                trgLayers = AseUtilities.getLayerHierarchy(sprite,
                    includeLocked, includeHidden, includeTiles, includeBkg)
            else
                local lenTrgLayers = 0
                local rangeLayers <const> = range.layers
                local lenRangeLayers <const> = #rangeLayers
                local i = 0
                while i < lenRangeLayers do
                    i = i + 1
                    local rangeLayer <const> = rangeLayers[i]
                    if (not rangeLayer.isGroup)
                        and (not rangeLayer.isReference)
                        and (includeHidden or rangeLayer.isVisible)
                        and (includeLocked or rangeLayer.isEditable)
                        and (includeTiles or (not rangeLayer.isTilemap))
                        and (includeBkg or (not rangeLayer.isBackground)) then
                        lenTrgLayers = lenTrgLayers + 1
                        trgLayers[lenTrgLayers] = rangeLayer
                    end
                end
            end
        end

        if tlHidden then
            app.command.Timeline { close = true }
        end

        return trgLayers
    else
        -- Default to "ACTIVE"
        if layer then
            return AseUtilities.appendLeaves(layer, {},
                includeLocked, includeHidden, includeTiles, includeBkg)
        end
        return {}
    end
end

---Flattens a group layer to a composite image. Does not verify that a layer is
---a group. Child layers are filtered according to the provided criteria.
---Returns an image and a cel bounds. If no composite could be made, returns a
---1 by 1 image and a rectangle in the top left corner.
---@param group Layer group layer
---@param frame Frame|integer frame
---@param sprClrMode ColorMode|integer sprite color mode
---@param colorSpace? ColorSpace color space
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

    local packets <const> = {}
    local lenPackets = 0

    local isIndexed <const> = sprClrMode == ColorMode.INDEXED
    local tilesToImage <const> = AseUtilities.tileMapToImage
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
                local tileSet <const> = leafLayer.tileset
                leafImage = tilesToImage(leafImage, tileSet, sprClrMode)
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

            local zIndex <const> = leafCel.zIndex
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
        bounds = Rectangle(xTlGroup, yTlGroup, wGroup, hGroup)

        local compSpec <const> = ImageSpec {
            width = wGroup,
            height = hGroup,
            colorMode = sprClrMode,
            transparentColor = aiVerif
        }
        if colorSpace then compSpec.colorSpace = colorSpace end
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
        if colorSpace then invalSpec.colorSpace = colorSpace end
        image = Image(invalSpec)
    end

    return image, bounds
end

---Returns a copy of the source image that has been flipped and transposed.
---@param source Image source image
---@return Image
---@nodiscard
function AseUtilities.flipImageAll(source)
    local srcSpec <const> = source.spec
    local w <const> = srcSpec.width
    local h <const> = srcSpec.height

    local trgSpec <const> = ImageSpec {
        width = h,
        height = w,
        colorMode = srcSpec.colorMode,
        transparentColor = srcSpec.transparentColor
    }
    trgSpec.colorSpace = srcSpec.colorSpace
    local target <const> = Image(trgSpec)
    target.bytes = Utilities.flipPixelsAll(
        source.bytes, w, h, source.bytesPerPixel)
    return target
end

---Returns a copy of the source image that has been flipped horizontally.
---@param source Image source image
---@return Image
---@nodiscard
function AseUtilities.flipImageX(source)
    local srcSpec <const> = source.spec
    local target <const> = Image(srcSpec)
    target.bytes = Utilities.flipPixelsX(source.bytes, srcSpec.width,
        srcSpec.height, source.bytesPerPixel)
    return target
end

---Returns a copy of the source image that has been flipped vertically.
---@param source Image source image
---@return Image
---@nodiscard
function AseUtilities.flipImageY(source)
    local srcSpec <const> = source.spec
    local target <const> = Image(srcSpec)
    target.bytes = Utilities.flipPixelsY(source.bytes, srcSpec.width,
        srcSpec.height, source.bytesPerPixel)
    return target
end

---Converts an array of frame objects to an array of frame numbers.
---Used primarily to set a range's frames.
---@param frObjs Frame[]
---@return integer[]
---@nodiscard
function AseUtilities.frameObjsToIdcs(frObjs)
    -- Next and previous layer could use this function but it's not worth it
    -- putting a dofile at the top.

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

---Gets the sprite's background checker width, height and colors from
---from preferences. Colors are retrieved by reference.
---@param sprite Sprite sprite
---@return integer wCheck
---@return integer hCheck
---@return Color aAse
---@return Color bAse
---@nodiscard
function AseUtilities.getBkgChecker(sprite)
    local wCheck, hCheck = 8, 8
    local aAse = Color { r = 128, g = 128, b = 128, a = 255 }
    local bAse = Color { r = 202, g = 202, b = 202, a = 255 }

    local appPrefs <const> = app.preferences
    if not appPrefs then return wCheck, hCheck, aAse, bAse end

    local docPrefs <const> = appPrefs.document(sprite)
    if not docPrefs then return wCheck, hCheck, aAse, bAse end

    local bgPref <const> = docPrefs.bg
    if not bgPref then return wCheck, hCheck, aAse, bAse end

    -- https://github.com/aseprite/aseprite/blob/main/data/pref.xml#L521
    -- TODO: zoom field is relevant for the old render engine. See
    -- app.preferences.experimental.new_render_engine , a boolean.
    local typePref <const> = bgPref.type --[[@as integer]]
    if typePref == 0 then
        wCheck, hCheck = 16, 16
    elseif typePref == 1 then
        wCheck, hCheck = 8, 8
    elseif typePref == 2 then
        wCheck, hCheck = 4, 4
    elseif typePref == 3 then
        wCheck, hCheck = 2, 2
    elseif typePref == 4 then
        wCheck, hCheck = 1, 1
    elseif typePref == 5 then
        local checkSize <const> = bgPref.size --[[@as Size]]
        if checkSize then
            wCheck = math.max(1, math.abs(checkSize.width))
            hCheck = math.max(1, math.abs(checkSize.height))
        end
    end

    local bgPrefColor1 <const> = bgPref.color1 --[[@as Color]]
    if bgPrefColor1 then aAse = bgPrefColor1 end

    local bgPrefColor2 <const> = bgPref.color2 --[[@as Color]]
    if bgPrefColor2 then bAse = bgPrefColor2 end

    return wCheck, hCheck, aAse, bAse
end

---Gets an array of arrays of frame indices from a sprite according to a string.
---"ALL" gets all frames in the sprite.
---"RANGE" gets the frames in the timeline range.
---"MANUAL" attempts to parse string of integers defined by commas and colons.
---"TAGS" gets the frames from an array of tags.
---"TAG" gets the frames from the active tag.
---"ACTIVE", the default, returns the active frame.
---If there's no active frame, returns an empty array.
---
---For tags and manual, duplicates will be included when the batched flag is
---true. Otherwise a unique set is returned.
---
---For ranges, call this method before new layers, frames or cels are created.
---Otherwise the range will be lost. Checks timeline visibility before
---accessing range. If a range is a layer type, all sprite frames will be
---returned. The batched flag will break the return array into sequences.
---@param sprite Sprite sprite
---@param target string preset
---@param batch boolean? batch
---@param mnStr string? manual
---@param tags Tag[]? tags
---@return integer[][]
---@nodiscard
function AseUtilities.getFrames(sprite, target, batch, mnStr, tags)
    if target == "ALL" then
        return { AseUtilities.frameObjsToIdcs(sprite.frames) }
    elseif target == "RANGE" then
        local tlHidden <const> = not app.preferences.general.visible_timeline --[[@as boolean]]
        if tlHidden then
            app.command.Timeline { open = true }
        end

        ---@type integer[][]
        local frIdcsRange = { {} }
        local range <const> = app.range
        if range.sprite == sprite then
            if range.type == RangeType.LAYERS then
                frIdcsRange = { AseUtilities.frameObjsToIdcs(sprite.frames) }
            else
                local frIdcs1 <const> = AseUtilities.frameObjsToIdcs(
                    range.frames)
                if batch then
                    frIdcsRange = Utilities.sequential(frIdcs1)
                else
                    frIdcsRange = { frIdcs1 }
                end
            end
        end

        if tlHidden then
            app.command.Timeline { close = true }
        end

        return frIdcsRange
    elseif target == "MANUAL" then
        if mnStr then
            local docPrefs <const> = app.preferences.document(sprite)
            local tlPrefs <const> = docPrefs.timeline
            local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]
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
    elseif target == "TAG" then
        local tag <const> = app.tag
        if tag then
            return AseUtilities.parseTagsOverlap({ tag })
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

---Gets a sprite's groups as a flat array. Whether layers are appended depends
---on the arguments provided.
---@param sprite Sprite sprite
---@param includeLocked? boolean include locked layers
---@param includeHidden? boolean include hidden layers
---@return Layer[]
---@nodiscard
function AseUtilities.getGroups(sprite, includeLocked, includeHidden)
    ---@type Layer[]
    local array <const> = {}
    local append <const> = AseUtilities.appendGroups
    local layers <const> = sprite.layers
    local lenLayers <const> = #layers
    local i = 0
    while i < lenLayers do
        i = i + 1
        append(layers[i], array, includeLocked, includeHidden)
    end
    return array
end

---Gets the sprite's hierarchy of content-holding layers as a flat array.
---Whether layers are appended depends on the arguments provided.
---@param sprite Sprite sprite
---@param includeLocked? boolean include locked layers
---@param includeHidden? boolean include hidden layers
---@param includeTiles? boolean include tile maps
---@param includeBkg? boolean include backgrounds
---@return Layer[]
---@nodiscard
function AseUtilities.getLayerHierarchy(
    sprite, includeLocked, includeHidden, includeTiles, includeBkg)
    ---@type Layer[]
    local array <const> = {}
    local append <const> = AseUtilities.appendLeaves
    local layers <const> = sprite.layers
    local lenLayers <const> = #layers
    local i = 0
    while i < lenLayers do
        i = i + 1
        append(layers[i], array, includeLocked, includeHidden, includeTiles,
            includeBkg)
    end
    return array
end

---Gets the mouse cursor position relative to the sprite canvas.
---If view tiled mode is enabled, wraps one or both coordinates.
---Returns (-1, -1) if the editor is nil.
---@return integer
---@return integer
---@nodiscard
function AseUtilities.getMouse()
    -- TODO: Return tiledMode integer third?

    -- With View Tiled Mode, the sprite position shifts to
    -- the top left corner tile, not the center tile.
    -- See https://github.com/aseprite/aseprite/issues/4659 .

    local editor <const> = app.editor
    if not editor then return -1, -1 end

    local sprite <const> = editor.sprite
    local mouse <const> = editor.spritePos

    local tiledMode = 0
    local appPrefs <const> = app.preferences
    if appPrefs then
        local docPrefs <const> = appPrefs.document(sprite)
        if docPrefs then
            local tiledPrefs <const> = docPrefs.tiled
            if tiledPrefs then
                local tPrefsMode <const> = tiledPrefs.mode --[[@as integer]]
                if tPrefsMode then
                    tiledMode = tPrefsMode
                end
            end
        end
    end

    local xMouse = mouse.x
    local yMouse = mouse.y
    if tiledMode == 3 then
        -- Tiling on both axes.
        xMouse = xMouse % sprite.width
        yMouse = yMouse % sprite.height
    elseif tiledMode == 2 then
        -- Vertical tiling.
        yMouse = yMouse % sprite.height
    elseif tiledMode == 1 then
        -- Horizontal tiling.
        xMouse = xMouse % sprite.width
    end

    return xMouse, yMouse
end

---For sprites with multiple palettes, tries to get a palette from an Aseprite
---frame object. Defaults to index 1 if the frame index exceeds the number of
---palettes. Does not check if frame is nil.
---@param frame Frame|integer frame
---@param palettes Palette[] palettes
---@return Palette
---@nodiscard
function AseUtilities.getPalette(frame, palettes)
    local idx = 1
    local typeFrObj <const> = type(frame)
    if typeFrObj == "number"
        and math.type(frame) == "integer" then
        idx = frame
    elseif typeFrObj == "userdata" then
        ---@diagnostic disable-next-line: undefined-field
        idx = frame.frameNumber
    end
    if idx > #palettes then idx = 1 end
    return palettes[idx]
end

---Gets the pixels of an image as a byte array. The array's length is equal to
---width times height times bytes per pixel.
---@param image Image
---@return integer[]
---@nodiscard
function AseUtilities.getPixels(image)
    return Utilities.stringToByteArr(image.bytes)
end

---Gets a selection from a sprite. Calls InvertMask command twice. Returns a
---copy of the selection, not a reference. If the selection is empty, then tries
---to return the cel bounds. If that is empty, then returns the sprite bounds.
---Returns true if a selection was found. Returns false if a default selection
---was created from either a cel or sprite.
---@param sprite Sprite sprite
---@return Selection
---@return boolean
function AseUtilities.getSelection(sprite)
    -- If a selection is moved, but the drag and drop pixels checkmark is not
    -- pressed, then a crash will result. MoveMask doesn't work because move
    -- quantity has a minimum of 1. For this to work, it cannot be wrapped in
    -- a transaction.
    app.command.InvertMask()
    app.command.InvertMask()

    local srcSel <const> = sprite.selection
    if (not srcSel) or srcSel.isEmpty then
        local activeCel <const> = app.site.cel
        if activeCel then
            -- Cel could be out-of-bounds, so this also needs to intersect with
            -- the sprite canvas. This ignores possibility that the cel image
            -- could be empty.
            local trgSel <const> = Selection(activeCel.bounds)
            trgSel:intersect(sprite.bounds)
            if not trgSel.isEmpty then
                return trgSel, false
            end
        end

        return Selection(sprite.bounds), false
    end

    local trgSel <const> = Selection()
    trgSel:add(srcSel)
    return trgSel, true
end

---Gets the top most parent layer that is visible. Returns the sprite as a
---parent if it is reached.
---@param layer Layer
---@return Layer|Sprite
function AseUtilities.getTopVisibleParent(layer)
    local query = layer --[[@as Layer|Sprite]]
    while query do
        query = query.parent
        ---@diagnostic disable-next-line: undefined-field
        if query.__name == "doc::Sprite" then return query end
        if query.isVisible then return query end
    end
    return layer
end

---Get unique cels from layers that have already been verified as leaves and
---filtered. Cels are ordered by frame number, then by layer id.
---@param leaves Layer[] leaf layers
---@param frames integer[]|Frame[] frames
---@return Cel[]
---@nodiscard
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
        local cel <const> = leaves[1 + i]:cel(frames[1 + j])
        if cel then
            uniqueCels[cel.image.id] = cel
        end
        k = k + 1
    end

    ---@type Cel[]
    local celsArr <const> = {}
    local lenCelsArr = 0
    for _, cel in pairs(uniqueCels) do
        lenCelsArr = lenCelsArr + 1
        celsArr[lenCelsArr] = cel
    end

    table.sort(celsArr, function(a, b)
        local aFrIdx <const> = a.frame and a.frame.frameNumber or 1
        local bFrIdx <const> = b.frame and b.frame.frameNumber or 1
        if aFrIdx == bFrIdx then
            return a.layer.id < b.layer.id
        end
        return aFrIdx < bFrIdx
    end)

    return celsArr
end

---Creates a table of gray colors represented as 32 bit integers, where the
---gray is repeated three times in red, green and blue channels.
---@param count integer swatch count
---@return integer[]
---@nodiscard
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
        result[i] = 0xff000000 | g << 0x10 | g << 0x08 | g
    end
    return result
end

---Generates a signed 64 bit integer hash code for an image. If a size
---threshold is given, and the image's area exceeds the threshold squared,
---then the image is resized with nearest neighbor sampling.
---
---Does not distinguish between different color modes, as the hash function
---treats on the image bytes as a string.
---
---For best results, prior to use, trim images of excess alpha and filter out
---empty images.
---@param source Image source image
---@param sizeThresh integer? size threshold
function AseUtilities.hashImage(source, sizeThresh)
    -- Aseprite uses city hash, but only returns a 32 bit integer:
    -- https://github.com/aseprite/aseprite/blob/main/src/doc/primitives.cpp#L545

    local bytes = source.bytes
    if sizeThresh and sizeThresh > 0 then
        local srcSpec <const> = source.spec
        local wSrc <const> = srcSpec.width
        local hSrc <const> = srcSpec.height
        if wSrc * hSrc > sizeThresh * sizeThresh then
            local cmSrc <const> = srcSpec.colorMode
            local alphaIndex <const> = srcSpec.transparentColor
            local alphaIndexVerif <const> = (cmSrc ~= ColorMode.INDEXED
                    or (alphaIndex >= 0 and alphaIndex < 256))
                and alphaIndex
                or 0
            bytes = Utilities.resizePixelsNearest(bytes, wSrc, hSrc,
                sizeThresh, sizeThresh, source.bytesPerPixel, alphaIndexVerif)
        end
    end

    return Utilities.fnvHash(bytes)
end

---Converts a 32 bit ABGR hexadecimal integer to an Aseprite Color object.
---Does not use the Color rgbaPixel constructor, as the color mode dictates how
---the integer is interpreted.
---@param hex integer hexadecimal color
---@return Color
---@nodiscard
function AseUtilities.hexToAseColor(hex)
    -- https://github.com/aseprite/aseprite/blob/main/src/app/script/color_class.cpp#L22
    return Color {
        r = hex & 0xff,
        g = (hex >> 0x08) & 0xff,
        b = (hex >> 0x10) & 0xff,
        a = (hex >> 0x18) & 0xff
    }
end

---Hides an aspect of a source layer after an adjusted copy has been made.
---If the preset is "HIDE", then the layer's visibility is set to false.
---If a layer is not a background, then it can be deleted with "DELETE_LAYER"
---or its cels can be deleted with "DELETE_CELS", which creates a transaction.
---Returns true if the layer was altered, false if no action was taken.
---@param sprite Sprite sprite
---@param layer Layer source layer
---@param frames integer[]|Frame[] frames array
---@param preset string preset string
---@return boolean
function AseUtilities.hideSource(sprite, layer, frames, preset)
    if preset == "HIDE" then
        layer.isVisible = false
        return true
    elseif (not layer.isBackground) then
        if preset == "DELETE_LAYER" then
            -- It's possible to delete all layers in a sprite with deleteLayer
            -- method. However, it's not worth protecting against, because this
            -- should be called by dialogs that create a new layer.
            sprite:deleteLayer(layer)
            return true
        elseif preset == "DELETE_CELS" then
            app.transaction("Delete Cels", function()
                local idxDel = #frames + 1
                while idxDel > 1 do
                    -- API reports an error if a cel cannot be found, so the
                    -- layer needs to check that it has a cel first.
                    idxDel = idxDel - 1
                    local frame <const> = frames[idxDel]
                    local cel <const> = layer:cel(frame)
                    if cel then sprite:deleteCel(cel) end
                end
            end)
            return true
        end
    end
    return false
end

---Creates an image from the flattened sprite that is contained by the
---selection mask.
---@param sel Selection selection mask
---@param sprite Sprite sprite
---@param frame Frame|integer frame index
---@return Image
---@return integer xtl
---@return integer ytl
function AseUtilities.imageFromSel(sel, sprite, frame)
    local selBounds <const> = sel.bounds
    local xSel <const> = selBounds.x
    local ySel <const> = selBounds.y
    local wSel <const> = math.max(1, math.abs(selBounds.width))
    local hSel <const> = math.max(1, math.abs(selBounds.height))

    local spriteSpec <const> = sprite.spec
    local colorMode <const> = spriteSpec.colorMode
    local alphaIndex <const> = spriteSpec.transparentColor

    local imageSpec <const> = ImageSpec {
        width = wSel,
        height = hSel,
        colorMode = colorMode,
        transparentColor = alphaIndex
    }
    imageSpec.colorSpace = spriteSpec.colorSpace
    local image <const> = Image(imageSpec)
    image:drawSprite(sprite, frame, Point(-xSel, -ySel))

    local validAlpha <const> = colorMode ~= ColorMode.INDEXED
        or (alphaIndex >= 0 and alphaIndex < 256)
    if validAlpha then
        local areaSel <const> = wSel * hSel
        local srcBytes <const> = image.bytes
        ---@type string[]
        local trgBytesArr <const> = {}

        if colorMode == ColorMode.INDEXED then
            local strbyte <const> = string.byte
            local strchar <const> = string.char
            local i = 0
            while i < areaSel do
                local c8 = alphaIndex
                if sel:contains(xSel + i % wSel, ySel + i // wSel) then
                    -- As a precaution, you may want to also check that the
                    -- color in the palette at an index does not have 0 alpha.
                    c8 = strbyte(srcBytes, 1 + i)
                end

                i = i + 1
                trgBytesArr[i] = strchar(c8)
            end
        else
            local bpp <const> = image.bytesPerPixel
            local alphaPacked <const> = string.pack("<I" .. bpp, 0)
            local strsub <const> = string.sub

            local i = 0
            while i < areaSel do
                local cStr = alphaPacked
                if sel:contains(xSel + i % wSel, ySel + i // wSel) then
                    local iBpp <const> = i * bpp
                    cStr = strsub(srcBytes, 1 + iBpp, bpp + iBpp)
                end
                i = i + 1
                trgBytesArr[i] = cStr
            end
        end

        image.bytes = table.concat(trgBytesArr)
    end

    return image, xSel, ySel
end

---Adds padding around the edges of an image. Does not check if image is a tile
---map. If the padding is less than one, returns the source image.
---@param image Image source image
---@param padding integer padding
---@return Image
---@nodiscard
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
    padded:drawImage(image, Point(padding, padding),
        255, BlendMode.SRC)
    return padded
end

---Parses an Aseprite Tag to an array of frame indices. For example, a tag with
---a fromFrame of 8 and a toFrame of 10 will return 8, 9, 10 if the tag has
---FORWARD direction. 10, 9, 8 for REVERSE. Ping-pong and its reverse excludes
---one boundary so that other renderers don't draw it twice. Doesn't interpret
---a tag's repeat count.
---
---A tag may have frame indices that are out of bounds for the sprite that
---has the tag. Returns an empty array if so.
---@param tag Tag Aseprite Tag
---@return integer[]
---@nodiscard
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
        -- Default to AniDir.FORWARD
        local j = origIdx - 1
        while j < destIdx do
            j = j + 1
            idxArr = idxArr + 1
            arr[idxArr] = j
        end
    end

    return arr
end

---Parses an array of Aseprite tags. Returns an array of arrays. Inner arrays
---may hold duplicate frame indices, as the same frame could appear in multiple
---groups.
---@param tags Tag[] tags array
---@return integer[][]
---@nodiscard
function AseUtilities.parseTagsOverlap(tags)
    local lenTags <const> = #tags
    ---@type integer[][]
    local arr2 <const> = {}
    local parseTag <const> = AseUtilities.parseTag
    local i = 0
    while i < lenTags do
        i = i + 1
        arr2[i] = parseTag(tags[i])
    end
    return arr2
end

---Parses an array of Aseprite tags. Returns an ordered set of integers.
---@param tags Tag[] tags array
---@return integer[]
---@nodiscard
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

---Preserves the application fore- and background colors across sprite changes.
---Copies and reassigns the colors to themselves. Does nothing if there is no
---active sprite.
function AseUtilities.preserveForeBack()
    if app.site.sprite then
        app.fgColor = AseUtilities.aseColorCopy(app.fgColor, "")
        app.command.SwitchColors()
        app.fgColor = AseUtilities.aseColorCopy(app.fgColor, "")
        app.command.SwitchColors()
    end
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
function AseUtilities.resizeImageNearest(source, wTrg, hTrg)
    local srcSpec <const> = source.spec
    local wSrc <const> = srcSpec.width
    local hSrc <const> = srcSpec.height
    local wVrf <const> = math.max(1, math.abs(wTrg))
    local hVrf <const> = math.max(1, math.abs(hTrg))

    if wVrf == wSrc and hVrf == hSrc then
        return source
    end

    local colorMode <const> = srcSpec.colorMode
    local alphaIndex <const> = srcSpec.transparentColor
    if colorMode == ColorMode.INDEXED
        and (alphaIndex < 0 or alphaIndex > 255) then
        return source
    end

    local trgSpec <const> = ImageSpec {
        width = wVrf,
        height = hVrf,
        colorMode = colorMode,
        transparentColor = alphaIndex
    }
    trgSpec.colorSpace = srcSpec.colorSpace
    local target <const> = Image(trgSpec)

    local bytesRsz <const> = Utilities.resizePixelsNearest(
        source.bytes, wSrc, hSrc, wVrf, hVrf, source.bytesPerPixel, alphaIndex)
    target.bytes = bytesRsz
    return target
end

---Returns a copy of the source image that has been rotated 90 degrees counter
---clockwise.
---@param source Image source image
---@return Image
---@nodiscard
function AseUtilities.rotateImage90(source)
    local srcSpec <const> = source.spec
    local w <const> = srcSpec.width
    local h <const> = srcSpec.height

    local trgSpec <const> = ImageSpec {
        width = h,
        height = w,
        colorMode = srcSpec.colorMode,
        transparentColor = srcSpec.transparentColor
    }
    trgSpec.colorSpace = srcSpec.colorSpace
    local target <const> = Image(trgSpec)
    target.bytes = Utilities.rotatePixels90(
        source.bytes, w, h, source.bytesPerPixel)
    return target
end

---Returns a copy of the source image that has been rotated 180 degrees.
---@param source Image source image
---@return Image
---@nodiscard
function AseUtilities.rotateImage180(source)
    local srcSpec <const> = source.spec
    local target <const> = Image(srcSpec)
    target.bytes = Utilities.rotatePixels180(source.bytes, srcSpec.width,
        srcSpec.height, source.bytesPerPixel)
    return target
end

---Returns a copy of the source image that has been rotated 270 degrees counter
---clockwise.
---@param source Image source image
---@return Image
---@nodiscard
function AseUtilities.rotateImage270(source)
    local srcSpec <const> = source.spec
    local w <const> = srcSpec.width
    local h <const> = srcSpec.height

    local trgSpec <const> = ImageSpec {
        width = h,
        height = w,
        colorMode = srcSpec.colorMode,
        transparentColor = srcSpec.transparentColor
    }
    trgSpec.colorSpace = srcSpec.colorSpace
    local target <const> = Image(trgSpec)
    target.bytes = Utilities.rotatePixels270(
        source.bytes, w, h, source.bytesPerPixel)
    return target
end

---Returns a copy of the source image that has been rotated around the x axis
---by an angle in degrees. Uses nearest neighbor sampling.
---If the angle is 0 degrees, then returns the source image by reference.
---@param source Image source image
---@param angle number angle in degrees
---@return Image
---@nodiscard
function AseUtilities.rotateImageX(source, angle)
    local deg <const> = Utilities.round(angle) % 360
    if deg == 0 then
        return source
    elseif deg == 180 then
        return AseUtilities.flipImageY(source)
    end

    local srcSpec <const> = source.spec
    local colorMode <const> = srcSpec.colorMode
    local alphaIndex <const> = srcSpec.transparentColor
    if colorMode == ColorMode.INDEXED
        and (alphaIndex < 0 or alphaIndex > 255) then
        return source
    end

    local trgBytes <const>,
    wTrg <const>,
    hTrg <const> = Utilities.rotatePixelsX(
        source.bytes, srcSpec.width, srcSpec.height,
        math.cos(angle * 0.017453292519943), 0.0, source.bytesPerPixel,
        alphaIndex)

    local trgSpec <const> = ImageSpec {
        width = wTrg,
        height = hTrg,
        colorMode = colorMode,
        transparentColor = alphaIndex
    }
    trgSpec.colorSpace = srcSpec.colorSpace
    local target <const> = Image(trgSpec)
    target.bytes = trgBytes
    return target
end

---Returns a copy of the source image that has been rotated around the y axis
---by an angle in degrees. Uses nearest neighbor sampling.
---If the angle is 0 degrees, then returns the source image by reference.
---@param source Image source image
---@param angle number angle in degrees
---@return Image
---@nodiscard
function AseUtilities.rotateImageY(source, angle)
    local deg <const> = Utilities.round(angle) % 360
    if deg == 0 then
        return source
    elseif deg == 180 then
        return AseUtilities.flipImageX(source)
    end

    local srcSpec <const> = source.spec
    local colorMode <const> = srcSpec.colorMode
    local alphaIndex <const> = srcSpec.transparentColor
    if colorMode == ColorMode.INDEXED
        and (alphaIndex < 0 or alphaIndex > 255) then
        return source
    end

    local trgBytes <const>,
    wTrg <const>,
    hTrg <const> = Utilities.rotatePixelsY(
        source.bytes, srcSpec.width, srcSpec.height,
        math.cos(angle * 0.017453292519943), 0.0, source.bytesPerPixel,
        alphaIndex)

    local trgSpec <const> = ImageSpec {
        width = wTrg,
        height = hTrg,
        colorMode = colorMode,
        transparentColor = alphaIndex
    }
    trgSpec.colorSpace = srcSpec.colorSpace
    local target <const> = Image(trgSpec)
    target.bytes = trgBytes
    return target
end

---Returns a copy of the source image that has been rotated counter clockwise
---around the z axis by an angle in degrees. Uses nearest neighbor sampling.
---If the angle is 0 degrees, then returns the source image by reference.
---If the angle is 90, 180 or 270 degrees, then defers to orthogonal rotations.
---@param source Image source image
---@param angle number angle in degrees
---@return Image
---@nodiscard
function AseUtilities.rotateImageZ(source, angle)
    local deg <const> = Utilities.round(angle) % 360

    if deg == 0 then
        return source
    elseif deg == 90 then
        return AseUtilities.rotateImage90(source)
    elseif deg == 180 then
        return AseUtilities.rotateImage180(source)
    elseif deg == 270 then
        return AseUtilities.rotateImage270(source)
    end

    local rad <const> = angle * 0.017453292519943
    return AseUtilities.rotateImageZInternal(source,
        math.cos(rad), math.sin(rad))
end

---Internal helper function to rotateZ. Accepts pre-calculated cosine and sine
---of an angle.
---@param source Image source image
---@param cosa number sine of angle
---@param sina number cosine of angle
---@return Image
---@nodiscard
function AseUtilities.rotateImageZInternal(source, cosa, sina)
    local srcSpec <const> = source.spec
    local colorMode <const> = srcSpec.colorMode
    local alphaIndex <const> = srcSpec.transparentColor
    if colorMode == ColorMode.INDEXED
        and (alphaIndex < 0 or alphaIndex > 255) then
        return source
    end

    local trgBytes <const>,
    wTrg <const>,
    hTrg <const> = Utilities.rotatePixelsZ(
        source.bytes, srcSpec.width, srcSpec.height,
        cosa, sina, source.bytesPerPixel, alphaIndex)

    local trgSpec <const> = ImageSpec {
        width = wTrg,
        height = hTrg,
        colorMode = colorMode,
        transparentColor = alphaIndex
    }
    trgSpec.colorSpace = srcSpec.colorSpace
    local target <const> = Image(trgSpec)
    target.bytes = trgBytes
    return target
end

---Returns a copy of the source image that has been skewed on the x axis by an
---angle in degrees. Uses nearest neighbor sampling.
---If the angle is 0 degrees, then returns the source image by reference.
---If the angle is approximately 90 degrees, then returns a blank image.
---@param source Image source image
---@param angle number angle in degrees
---@return Image
---@nodiscard
function AseUtilities.skewImageX(source, angle)
    -- This doesn't have an internal version because it's not worth making
    -- a separate method for skewing by integer rise and run.
    local srcSpec <const> = source.spec
    local srcAlphaIndex <const> = srcSpec.transparentColor

    local srcColorMode <const> = srcSpec.colorMode
    if srcColorMode == ColorMode.INDEXED
        and (srcAlphaIndex < 0 or srcAlphaIndex > 255) then
        return source
    end

    local srcBytes <const> = source.bytes
    local srcBpp <const> = source.bytesPerPixel
    local wSrc <const> = srcSpec.width
    local hSrc <const> = srcSpec.height

    local trgBytes = ""
    local wTrg = 0
    local hTrg = 0

    local deg <const> = Utilities.round(angle) % 180
    if deg == 0 then
        return source
    elseif deg >= 26 and deg <= 27 then
        trgBytes, wTrg, hTrg = Utilities.skewPixelsXInt(srcBytes, wSrc, hSrc,
            1, 2, srcBpp, srcAlphaIndex)
    elseif deg == 45 then
        trgBytes, wTrg, hTrg = Utilities.skewPixelsXInt(srcBytes, wSrc, hSrc,
            1, 1, srcBpp, srcAlphaIndex)
    elseif deg >= 63 and deg <= 64 then
        trgBytes, wTrg, hTrg = Utilities.skewPixelsXInt(srcBytes, wSrc, hSrc,
            2, 1, srcBpp, srcAlphaIndex)
    elseif deg >= 88 and deg <= 92 then
        return Image(srcSpec)
    elseif deg >= 116 and deg <= 117 then
        trgBytes, wTrg, hTrg = Utilities.skewPixelsXInt(srcBytes, wSrc, hSrc,
            -2, 1, srcBpp, srcAlphaIndex)
    elseif deg == 135 then
        trgBytes, wTrg, hTrg = Utilities.skewPixelsXInt(srcBytes, wSrc, hSrc,
            -1, 1, srcBpp, srcAlphaIndex)
    elseif deg >= 153 and deg <= 154 then
        trgBytes, wTrg, hTrg = Utilities.skewPixelsXInt(srcBytes, wSrc, hSrc,
            -1, 2, srcBpp, srcAlphaIndex)
    else
        local radians <const> = angle * 0.017453292519943
        trgBytes, wTrg, hTrg = Utilities.skewPixelsX(srcBytes, wSrc, hSrc,
            math.tan(radians), srcBpp, srcAlphaIndex)
    end

    local trgSpec <const> = ImageSpec {
        width = wTrg,
        height = hTrg,
        colorMode = srcColorMode,
        transparentColor = srcAlphaIndex
    }
    trgSpec.colorSpace = srcSpec.colorSpace
    local target <const> = Image(trgSpec)
    target.bytes = trgBytes
    return target
end

---Returns a copy of the source image that has been skewed on the y axis by an
---angle in degrees. Uses nearest neighbor sampling.
---If the angle is 0 degrees, then returns the source image by reference.
---If the angle is approximately 90 degrees, then returns a blank image.
---@param source Image source image
---@param angle number angle in degrees
---@return Image
---@nodiscard
function AseUtilities.skewImageY(source, angle)
    -- This doesn't have an internal version because it's not worth making
    -- a separate method for skewing by integer rise and run.
    local srcSpec <const> = source.spec
    local srcAlphaIndex <const> = srcSpec.transparentColor

    local srcColorMode <const> = srcSpec.colorMode
    if srcColorMode == ColorMode.INDEXED
        and (srcAlphaIndex < 0 or srcAlphaIndex > 255) then
        return source
    end

    local srcBytes <const> = source.bytes
    local srcBpp <const> = source.bytesPerPixel
    local wSrc <const> = srcSpec.width
    local hSrc <const> = srcSpec.height

    local trgBytes = ""
    local wTrg = 0
    local hTrg = 0

    local deg <const> = Utilities.round(angle) % 180
    if deg == 0 then
        return source
    elseif deg >= 26 and deg <= 27 then
        trgBytes, wTrg, hTrg = Utilities.skewPixelsYInt(srcBytes, wSrc, hSrc,
            1, 2, srcBpp, srcAlphaIndex)
    elseif deg == 45 then
        trgBytes, wTrg, hTrg = Utilities.skewPixelsYInt(srcBytes, wSrc, hSrc,
            1, 1, srcBpp, srcAlphaIndex)
    elseif deg >= 63 and deg <= 64 then
        trgBytes, wTrg, hTrg = Utilities.skewPixelsYInt(srcBytes, wSrc, hSrc,
            2, 1, srcBpp, srcAlphaIndex)
    elseif deg >= 88 and deg <= 92 then
        return Image(srcSpec)
    elseif deg >= 116 and deg <= 117 then
        trgBytes, wTrg, hTrg = Utilities.skewPixelsYInt(srcBytes, wSrc, hSrc,
            -2, 1, srcBpp, srcAlphaIndex)
    elseif deg == 135 then
        trgBytes, wTrg, hTrg = Utilities.skewPixelsYInt(srcBytes, wSrc, hSrc,
            -1, 1, srcBpp, srcAlphaIndex)
    elseif deg >= 153 and deg <= 154 then
        trgBytes, wTrg, hTrg = Utilities.skewPixelsYInt(srcBytes, wSrc, hSrc,
            -1, 2, srcBpp, srcAlphaIndex)
    else
        local radians <const> = angle * 0.017453292519943
        trgBytes, wTrg, hTrg = Utilities.skewPixelsY(srcBytes, wSrc, hSrc,
            math.tan(radians), srcBpp, srcAlphaIndex)
    end

    local trgSpec <const> = ImageSpec {
        width = wTrg,
        height = hTrg,
        colorMode = srcColorMode,
        transparentColor = srcAlphaIndex
    }
    trgSpec.colorSpace = srcSpec.colorSpace
    local target <const> = Image(trgSpec)
    target.bytes = trgBytes
    return target
end

---Selects non-transparent pixels of a cel's image. Intersects the selection
---with the sprite bounds, if provided, for cases where cel may be partially
---outside the canvas edges.
---@param cel Cel cel
---@param spriteBounds Rectangle? sprite bounds
---@return Selection
---@nodiscard
function AseUtilities.selectCel(cel, spriteBounds)
    local celPos <const> = cel.position
    return AseUtilities.selectImage(cel.image, celPos.x, celPos.y,
        cel.layer.tileset, spriteBounds)
end

---Selects non-transparent pixels of an image. Intersects the selection with
---the sprite bounds, if provided, for cases where cel may be partially outside
---the canvas edges. Ignores tile flips and rotations. For indexed color mode,
---ignores the palette color's alpha channel.
---@param image Image source image
---@param xtl integer cel position x
---@param ytl integer cel position y
---@param tileSet Tileset? tile set
---@param spriteBounds Rectangle? sprite bounds
---@return Selection
---@nodiscard
function AseUtilities.selectImage(image, xtl, ytl, tileSet, spriteBounds)
    local bpp <const> = image.bytesPerPixel
    local bytes <const> = image.bytes

    local celSpec <const> = image.spec
    local wImage <const> = celSpec.width
    local hImage <const> = celSpec.height
    local colorMode <const> = celSpec.colorMode
    local alphaIndex <const> = celSpec.transparentColor

    -- Beware naming, 'select' is a method built-in to Lua.
    local pxRect <const> = Rectangle(0, 0, 1, 1)
    local lenImage <const> = wImage * hImage

    local mask = nil
    if colorMode == ColorMode.TILEMAP then
        if tileSet then
            local tileDim <const> = tileSet.grid.tileSize
            local wTile <const> = tileDim.width
            local hTile <const> = tileDim.height

            mask = Selection(Rectangle(xtl, ytl,
                wTile * wImage, hTile * hImage))
            pxRect.width = wTile
            pxRect.height = hTile

            local pxTilei <const> = app.pixelColor.tileI
            local strsub <const> = string.sub
            local strunpack <const> = string.unpack

            local i = 0
            while i < lenImage do
                local ibpp <const> = i * bpp
                local str <const> = strsub(bytes, 1 + ibpp, bpp + ibpp)
                local mapif <const> = strunpack("<I4", str)
                local idx <const> = pxTilei(mapif)
                if idx == 0 then
                    pxRect.x = wTile * (i % wImage) + xtl
                    pxRect.y = hTile * (i // wImage) + ytl
                    mask:subtract(pxRect)
                end
                i = i + 1
            end
        else
            mask = Selection()
        end
    else
        mask = Selection(Rectangle(xtl, ytl, wImage, hImage))
        local strbyte <const> = string.byte
        local i = 0
        while i < lenImage do
            if strbyte(bytes, i * bpp + bpp) == alphaIndex then
                pxRect.x = (i % wImage) + xtl
                pxRect.y = (i // wImage) + ytl
                mask:subtract(pxRect)
            end
            i = i + 1
        end
    end

    if spriteBounds then
        mask:intersect(spriteBounds)
    end

    return mask
end

---Sets a palette in a sprite at a given index to a table of colors represented
---as hexadecimal integers. The palette index defaults to 1.
---The keepMaxLen flag is for setting palettes in indexed color mode, where a
---shorter palette would cause invalid indices in image maps.
---Creates a transaction.
---@param arr integer[] color array
---@param sprite Sprite sprite
---@param paletteIndex integer? index
---@param keepMaxLen boolean? keep maximum length
function AseUtilities.setPalette(arr, sprite, paletteIndex, keepMaxLen)
    local palIdxVerif = paletteIndex or 1
    local palettes <const> = sprite.palettes
    local lenPalettes <const> = #palettes
    local lenHexArr <const> = #arr
    -- This should be consistent behavior with getPalette.
    if palIdxVerif > lenPalettes then palIdxVerif = 1 end
    local palette <const> = palettes[palIdxVerif]
    if lenHexArr > 0 then
        app.transaction("Set Palette", function()
            local lenNew <const> = keepMaxLen
                and math.max(lenHexArr, #palette)
                or lenHexArr
            palette:resize(lenNew)
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
                local aseColor <const> = AseUtilities.hexToAseColor(arr[i])
                palette:setColor(i - 1, aseColor)
            end
        end)
    else
        app.transaction("Set Palette", function()
            palette:resize(1)
            palette:setColor(0, Color { r = 0, g = 0, b = 0, a = 0 })
        end)
    end
end

---Sets an image to an array of bytes. No validation is performed on the array
---elements or length. The length should be width times height times bytes per
---pixel.
---@param image Image
---@param pixels integer[]
---@return Image
function AseUtilities.setPixels(image, pixels)
    image.bytes = Utilities.bytesArrToString(pixels)
    return image
end

---Converts an image from a tile set layer to a regular image. If the Tileset
---is nil, returns an image that copies the source's ImageSpec.
---@param imgSrc Image source image
---@param tileSet Tileset|nil tile set
---@param sprClrMode ColorMode sprite color mode
---@return Image
---@nodiscard
function AseUtilities.tileMapToImage(imgSrc, tileSet, sprClrMode)
    local srcSpec <const> = imgSrc.spec
    local wSrc <const> = srcSpec.width
    local hSrc <const> = srcSpec.height
    local alphaIndex <const> = srcSpec.transparentColor
    local colorSpace <const> = srcSpec.colorSpace

    if not tileSet then
        local imageSpec <const> = ImageSpec {
            width = wSrc,
            height = hSrc,
            colorMode = sprClrMode,
            transparentColor = alphaIndex,
        }
        imageSpec.colorSpace = colorSpace
        return Image(imageSpec)
    end

    local tileDim <const> = tileSet.grid.tileSize
    local tileWidth <const> = math.max(1, math.abs(tileDim.width))
    local tileHeight <const> = math.max(1, math.abs(tileDim.height))

    local trgSpec <const> = ImageSpec {
        width = wSrc * tileWidth,
        height = hSrc * tileHeight,
        colorMode = sprClrMode,
        transparentColor = alphaIndex,
    }
    trgSpec.colorSpace = colorSpace
    local imgTrg <const> = Image(trgSpec)

    local pixelColor <const> = app.pixelColor
    local pxTilei <const> = pixelColor.tileI
    local pxTilef <const> = pixelColor.tileF
    local bakeFlag <const> = AseUtilities.bakeFlag
    local strsub <const> = string.sub
    local strunpack <const> = string.unpack

    local srcBytes <const> = imgSrc.bytes
    local srcBpp <const> = imgSrc.bytesPerPixel
    local fmtStr <const> = "<I" .. srcBpp
    local blendModeSrc <const> = BlendMode.SRC
    local srcArea <const> = wSrc * hSrc

    local i = 0
    while i < srcArea do
        local ibpp <const> = i * srcBpp
        local mapif <const> = strunpack(fmtStr, strsub(srcBytes,
            1 + ibpp, srcBpp + ibpp))
        local idx <const> = pxTilei(mapif)
        local tile <const> = tileSet:tile(idx)
        if tile then
            local meta <const> = pxTilef(mapif)
            local tileImage <const>, _ <const> = bakeFlag(tile.image, meta)
            imgTrg:drawImage(tileImage,
                Point((i % wSrc) * tileWidth, (i // wSrc) * tileHeight),
                255, blendModeSrc)
        end
        i = i + 1
    end

    return imgTrg
end

---Returns a copy of the source image that has been transposed.
---@param source Image source image
---@return Image
---@nodiscard
function AseUtilities.transposeImage(source)
    local srcSpec <const> = source.spec
    local w <const> = srcSpec.width
    local h <const> = srcSpec.height

    local trgSpec <const> = ImageSpec {
        width = h,
        height = w,
        colorMode = srcSpec.colorMode,
        transparentColor = srcSpec.transparentColor
    }
    trgSpec.colorSpace = srcSpec.colorSpace
    local target <const> = Image(trgSpec)
    target.bytes = Utilities.transposePixels(
        source.bytes, w, h, source.bytesPerPixel)
    return target
end

---Trims a cel's image and position to a selection. An image's pixel is cleared
---to the default color if it isn't contained by the selection. If the default
---is nil, uses the cel image's alpha mask.
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

    -- Avoid creating transactions if possible.
    local oldPos <const> = cel.position
    if oldPos.x ~= xClip
        or oldPos.y ~= yClip then
        cel.position = Point(xClip, yClip)
    end

    local celImg <const> = cel.image
    local celSpec <const> = celImg.spec

    local wTrim <const> = math.max(1, clip.width)
    local hTrim <const> = math.max(1, clip.height)
    local alphaIndex <const> = celSpec.transparentColor
    local colorMode <const> = celSpec.colorMode

    local trimSpec <const> = ImageSpec {
        width = wTrim,
        height = hTrim,
        colorMode = colorMode,
        transparentColor = alphaIndex
    }
    trimSpec.colorSpace = celSpec.colorSpace

    local trimImage <const> = Image(trimSpec)
    if clip.width > 0 and clip.height > 0 then
        local celPos <const> = cel.position
        trimImage:drawImage(
            celImg, Point(
                oldPos.x - celPos.x,
                oldPos.y - celPos.y),
            255, BlendMode.SRC)

        local alphaIndexVerif <const> = (colorMode ~= ColorMode.INDEXED
                or (alphaIndex >= 0 and alphaIndex < 256)) and
            alphaIndex or 0
        local hexVerif <const> = hexDefault or alphaIndexVerif
        local trimBytesStr <const> = trimImage.bytes
        local bpp <const> = trimImage.bytesPerPixel
        local hexPacked <const> = string.pack("<I" .. bpp, hexVerif)
        local strsub <const> = string.sub

        ---@type string[]
        local trimBytesArr <const> = {}
        local areaTrim <const> = wTrim * hTrim
        local i = 0
        while i < areaTrim do
            local byteStr = hexPacked
            if mask:contains(
                    xClip + i % wTrim,
                    yClip + i // wTrim) then
                local ibpp <const> = i * bpp
                byteStr = strsub(trimBytesStr, 1 + ibpp, bpp + ibpp)
            end
            i = i + 1
            trimBytesArr[i] = byteStr
        end
        trimImage.bytes = table.concat(trimBytesArr)
    end
    cel.image = trimImage
end

---Trims a cel's image and position such that it no longer exceeds the sprite's
---boundaries. Unlike built-in method, does not trim the image's alpha.
---@param cel Cel source cel
---@param sprite Sprite parent sprite
function AseUtilities.trimCelToSprite(cel, sprite)
    local celBounds <const> = cel.bounds
    local spriteBounds <const> = sprite.bounds
    local clip <const> = celBounds:intersect(spriteBounds)

    -- Avoid creating transactions if possible.
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
                oldPos.y - celPos.y),
            255, BlendMode.SRC)
    end
    cel.image = trimImage
end

---Creates a copy of the image where excess transparent pixels have been
---trimmed from the edges. Padding is expected to be a positive number. It
---defaults to zero.
---
---Default width and height can be given in the event that the image is
---completely transparent.
---
---Returns a tuple with the cropped image, the top left x and top left y.
---The top left should be added to the position of the cel that owned the
---source image.
---@param image Image aseprite image
---@param padding integer padding
---@param alphaIndex integer alpha mask index
---@param wDefault integer? width default
---@param hDefault integer? height default
---@return Image trimmed
---@return integer xShift
---@return integer yShift
function AseUtilities.trimImageAlpha(
    image, padding, alphaIndex,
    wDefault, hDefault)
    local padVrf = padding or 0
    padVrf = math.abs(padVrf)
    local pad2 <const> = padVrf + padVrf

    -- If the image has no nonzero pixels, or is a tile map,
    -- returns a rectangle of zero size. Old version which could
    -- work around this is at:
    -- 606a86e64801e63e18662650288ccd5df3b4ef27
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
        width = wTrg + pad2,
        height = hTrg + pad2,
        colorMode = srcSpec.colorMode,
        transparentColor = alphaIndex
    }
    trgSpec.colorSpace = srcSpec.colorSpace
    local target <const> = Image(trgSpec)

    if rectIsValid then
        target:drawImage(image,
            Point(padVrf - lft, padVrf - top),
            255, BlendMode.SRC)
    end
    return target, lft - padVrf, top - padVrf
end

---Creates a copy of the map where excess transparent pixels have been
---trimmed from the edges.
---
---Default width and height can be given in the event that the image is
---completely transparent.
---
---Returns a tuple with the cropped image, the top left x and top left y.
---The top left should be added to the position of the cel that owned the
---source image.
---@param map Image tile map image
---@param alphaIndex integer alpha mask index
---@param wTile integer tile width
---@param hTile integer tile height
---@param wDefault integer? map width default
---@param hDefault integer? map height default
---@return Image trimmed
---@return integer xShift
---@return integer yShift
function AseUtilities.trimMapAlpha(
    map, alphaIndex, wTile, hTile, wDefault, hDefault)
    local pxTilei <const> = app.pixelColor.tileI
    local strunpack <const> = string.unpack
    local strsub <const> = string.sub

    local bytes <const> = map.bytes
    local bpp <const> = map.bytesPerPixel
    local srcSpec <const> = map.spec
    local wSrc <const> = srcSpec.width
    local hSrc <const> = srcSpec.height
    local wSrcn1 <const> = math.max(0, wSrc - 1)
    local hSrcn1 <const> = math.max(0, hSrc - 1)
    local minRight = wSrcn1
    local minBottom = hSrcn1

    local lft = 0
    local top = 0
    local wTrg = wDefault or wSrc
    local hTrg = hDefault or hSrc
    local isValid = false

    -- Top edge.
    local topSearch = -1
    local goTop = true
    while topSearch < hSrcn1 and goTop do
        topSearch = topSearch + 1
        local x = -1
        while x < wSrcn1 and goTop do
            x = x + 1
            local iTop <const> = bpp * (x + wSrc * topSearch)
            local mapif <const> = strunpack("<I4", strsub(
                bytes, 1 + iTop, bpp + iTop))
            if pxTilei(mapif) ~= 0 then
                minRight = x
                minBottom = topSearch
                goTop = false
            end
        end
    end

    -- Left edge.
    local lftSearch = -1
    local goLft = true
    while lftSearch < minRight and goLft do
        lftSearch = lftSearch + 1
        local y = hSrc
        while y > topSearch and goLft do
            y = y - 1
            local iLft <const> = bpp * (lftSearch + wSrc * y)
            local mapif <const> = strunpack("<I4", strsub(
                bytes, 1 + iLft, bpp + iLft))
            if pxTilei(mapif) ~= 0 then
                minBottom = y
                goLft = false
            end
        end
    end

    -- Bottom edge.
    local btm = hSrc
    local goBtm = true
    while btm > minBottom and goBtm do
        btm = btm - 1
        local x = wSrc
        while x > lftSearch and goBtm do
            x = x - 1
            local iBtm <const> = bpp * (x + wSrc * btm)
            local mapif <const> = strunpack("<I4", strsub(
                bytes, 1 + iBtm, bpp + iBtm))
            if pxTilei(mapif) ~= 0 then
                minRight = x
                goBtm = false
            end
        end
    end

    -- Right edge.
    local rgt = wSrc
    local goRgt = true
    while rgt > minRight and goRgt do
        rgt = rgt - 1
        local y = btm + 1
        while y > topSearch and goRgt do
            y = y - 1
            local iRgt <const> = bpp * (rgt + wSrc * y)
            local mapif <const> = strunpack("<I4", strsub(
                bytes, 1 + iRgt, bpp + iRgt))
            if pxTilei(mapif) ~= 0 then
                goRgt = false
            end
        end
    end

    local wSum <const> = 1 + rgt - lftSearch
    local hSum <const> = 1 + btm - topSearch
    isValid = wSum > 0 and hSum > 0
    if isValid then
        lft = lftSearch
        top = topSearch
        wTrg = wSum
        hTrg = hSum
    end

    local trgSpec <const> = ImageSpec {
        width = wTrg,
        height = hTrg,
        colorMode = ColorMode.TILEMAP,
        transparentColor = alphaIndex
    }
    trgSpec.colorSpace = srcSpec.colorSpace
    local target <const> = Image(trgSpec)

    if isValid then
        target:drawImage(map,
            Point(-lft, -top),
            255, BlendMode.SRC)
    end

    return target, lft * wTile, top * hTile
end

---Returns a copy of the source image that has been scaled up for export. Uses
---integer arithmetic only. If the scales are both 1, then returns the source
---by reference.
---@param source Image source image
---@param wScale integer width scalar
---@param hScale integer height scalar
---@return Image
---@nodiscard
function AseUtilities.upscaleImageForExport(source, wScale, hScale)
    local wScaleVrf <const> = math.max(1, math.abs(wScale))
    local hScaleVrf <const> = math.max(1, math.abs(hScale))
    if wScaleVrf == 1 and hScaleVrf == 1 then
        return source
    end

    local srcByteStr <const> = source.bytes
    local bpp <const> = source.bytesPerPixel
    local srcSpec <const> = source.spec
    local wSrc <const> = srcSpec.width
    local hSrc <const> = srcSpec.height

    ---@type string[]
    local resized <const> = {}
    local lenKernel <const> = wScaleVrf * hScaleVrf
    local lenSrc <const> = wSrc * hSrc
    local wTrg <const> = wSrc * wScaleVrf
    local hTrg <const> = hSrc * hScaleVrf

    local trgSpec <const> = ImageSpec {
        width = wTrg,
        height = hTrg,
        colorMode = srcSpec.colorMode,
        transparentColor = srcSpec.transparentColor
    }
    trgSpec.colorSpace = srcSpec.colorSpace
    local target <const> = Image(trgSpec)

    -- This doesn't rely on a Utilities method because it is specific to
    -- pixel art export from Aseprite vs. resizing an image for a
    -- transformation on the canvas.
    local strsub <const> = string.sub
    local i = 0
    while i < lenSrc do
        local xTrg <const> = wScaleVrf * (i % wSrc)
        local yTrg <const> = hScaleVrf * (i // wSrc)
        local ibpp <const> = i * bpp
        local srcStr <const> = strsub(srcByteStr, 1 + ibpp, bpp + ibpp)
        local j = 0
        while j < lenKernel do
            local xKernel <const> = xTrg + j % wScaleVrf
            local yKernel <const> = yTrg + j // wScaleVrf
            resized[1 + yKernel * wTrg + xKernel] = srcStr
            j = j + 1
        end
        i = i + 1
    end

    target.bytes = table.concat(resized)
    return target
end

---Converts a Vec2 to an Aseprite Point.
---@param v Vec2 vector
---@return Point
---@nodiscard
function AseUtilities.vec2ToPoint(v)
    return Point(
        Utilities.round(v.x),
        Utilities.round(v.y))
end

---Translates the pixels of an image by a vector, wrapping the elements that
---exceed its dimensions back to the beginning.
---@param source Image source image
---@param xt integer x translation
---@param yt integer y translation
---@return Image
---@nodiscard
function AseUtilities.wrapImage(source, xt, yt)
    local sourceSpec <const> = source.spec
    local target <const> = Image(sourceSpec)
    target.bytes = Utilities.wrapPixels(
        source.bytes, xt, yt,
        sourceSpec.width, sourceSpec.height,
        source.bytesPerPixel)
    return target
end

return AseUtilities