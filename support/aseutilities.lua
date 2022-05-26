dofile("./utilities.lua")

AseUtilities = {}
AseUtilities.__index = AseUtilities

setmetatable(AseUtilities, {
    __call = function(cls, ...)
        return cls.new(...)
    end })

-- Maximum number of a cels a script may
-- request to create before the user is
-- prompted to confirm.
AseUtilities.CEL_COUNT_LIMIT = 256

---Default fill color.
AseUtilities.DEFAULT_FILL = 0xffd7f5ff

---Default palette used when no other
---is available. Simulates a RYB
---color wheel with black and white.
AseUtilities.DEFAULT_PAL_ARR = {
    0x00000000, -- Mask
    0xff000000, -- Black
    0xffffffff, -- White
    0xff0000ff, -- Red
    0xff006aff, -- Red-orange
    0xff00a2ff, -- Orange
    0xff00cfff, -- Yellow-orange
    0xff00ffff, -- Yellow
    0xff1ad481, -- Green-yellow
    0xff33a900, -- Green
    0xff668415, -- Blue-green
    0xffa65911, -- Blue
    0xff922a3c, -- Blue-purple
    0xff850c69, -- Purple
    0xff5500aa -- Red-purple
}

---Default stroke color.
AseUtilities.DEFAULT_STROKE = 0xff202020

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

---Text horizontal alignment.
AseUtilities.GLYPH_ALIGN_HORIZ = {
    "CENTER",
    "LEFT",
    "RIGHT"
}

---Text vertical alignment.
AseUtilities.GLYPH_ALIGN_VERT = {
    "BOTTOM",
    "CENTER",
    "TOP"
}

-- Number of swatches to generate for
-- gray color mode sprites.
AseUtilities.GRAY_COUNT = 32

-- Maximum number of layers a script may
-- request to create before the user is
-- prompted to confirm.
AseUtilities.LAYER_COUNT_LIMIT = 96

---Text orientations.
AseUtilities.ORIENTATIONS = {
    "HORIZONTAL",
    "VERTICAL"
}

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

---Copies an Aseprite Color object by sRGB
---channel values. This is to prevent accidental
---pass by reference. The Color constructor does
---no boundary checking for [0, 255]. If the flag
---is "UNBOUNDED", then the raw values are used.
---If the flag is "MODULAR," this will copy by
---hexadecimal value, and hence use modular
---arithmetic. For more info, See
---https://www.wikiwand.com/en/Modular_arithmetic .
---The default is saturation arithmetic.
---@param aseClr userdata Aseprite color
---@param flag string out of bounds interpretation
---@return table
function AseUtilities.aseColorCopy(aseClr, flag)
    if flag == "UNBOUNDED" then
        return Color(
            aseClr.red,
            aseClr.green,
            aseClr.blue,
            aseClr.alpha)
    elseif flag == "MODULAR" then
        return AseUtilities.hexToAseColor(
            AseUtilities.aseColorToHex(aseClr, ColorMode.RGB))
    else
        return Color(
            math.max(0, math.min(255, aseClr.red)),
            math.max(0, math.min(255, aseClr.green)),
            math.max(0, math.min(255, aseClr.blue)),
            math.max(0, math.min(255, aseClr.alpha)))
    end
end

---Converts an Aseprite Color object to a Clr.
---Assumes that the Aseprite Color is in sRGB.
---Both Aseprite Color and Clr allow arguments
---to exceed the expected ranges, [0, 255] and
---[0.0, 1.0], respectively.
---@param aseClr userdata Aseprite color
---@return table
function AseUtilities.aseColorToClr(aseClr)
    return Clr.new(
        0.003921568627451 * aseClr.red,
        0.003921568627451 * aseClr.green,
        0.003921568627451 * aseClr.blue,
        0.003921568627451 * aseClr.alpha)
end

---Converts an Aseprite color object to an
---integer. The meaning of the integer depends
---on the color mode. For RGB, uses modular
---arithmetic, i.e., does not check if red,
---green, blue and alpha channels are out of
---range [0, 255]. Returns zero if the color
---mode is not recognized.
---@param clr userdata aseprite color
---@param clrMode number color mode
---@return number
function AseUtilities.aseColorToHex(clr, clrMode)
    if clrMode == ColorMode.RGB then
        return (clr.alpha << 0x18)
            | (clr.blue << 0x10)
            | (clr.green << 0x08)
            | clr.red
    elseif clrMode == ColorMode.GRAY then
        return clr.grayPixel
    elseif clrMode == ColorMode.INDEXED then
        -- In older API versions, Color.index
        -- returns a float, not an integer.
        return math.tointeger(clr.index)
    end
    return 0
end

---Loads a palette based on a string. The string is
---expected to be either "FILE", "PRESET" or "ACTIVE".
---Returns a tuple of tables. The first table is an
---array of hexadecimals according to the sprite color
---profile. The second is a copy of the first converted
---to SRGB. If a palette is loaded from a filepath or a
---preset the two tables should match, as Aseprite does
---not support color management for palettes. The
---correctZeroAlpha flag replaces zero alpha colors
---with 0x00000000, regardless of other channel data.
---@param palType string enumeration
---@param filePath string file path
---@param presetPath string preset path
---@param startIndex number start index
---@param count number count of colors to sample
---@param correctZeroAlpha boolean alpha correction flag
---@return table
---@return table
function AseUtilities.asePaletteLoad(
    palType, filePath, presetPath, startIndex, count,
    correctZeroAlpha)

    local cntVal = count or 256
    local siVal = startIndex or 0

    local hexesProfile = nil
    local hexesSrgb = nil

    local errorHandler = function(err)
        app.alert {
            title = "File Not Found",
            text = {
                "The palette could not be found.",
                "Please check letter case (lower or upper).",
                "A default palette will be used instead."
            }
        }
    end

    if palType == "FILE" then
        if filePath and #filePath > 0 then
            local exists = app.fs.isFile(filePath)
            if exists then
                -- Loading an .aseprite file with multiple palettes
                -- will register only the first palette.
                local palFile = Palette { fromFile = filePath }
                if palFile then
                    -- Palettes loaded from a file could support an
                    -- embedded color profile, but do not.
                    -- You could check the extension, and if it is a
                    -- .png, .aseprite, etc. then load as a sprite,
                    -- but it'd be difficult to dispose of the sprite.
                    hexesProfile = AseUtilities.asePaletteToHexArr(
                        palFile, siVal, cntVal)
                end
            end
        end
    elseif palType == "PRESET" then
        if presetPath and #presetPath > 0 then
            -- Given how unreliable xpcall has proven with Sprites and
            -- ColorProfiles, maybe don't use it.
            -- app.fs.isFile doesn't work here.
            local success = xpcall(
                function(y) Palette { fromResource = y } end,
                errorHandler, presetPath)
            if success then
                local palPreset = Palette { fromResource = presetPath }
                if palPreset then
                    hexesProfile = AseUtilities.asePaletteToHexArr(
                        palPreset, siVal, cntVal)
                end
            end
        end
    elseif palType == "ACTIVE" then
        local palActSpr = app.activeSprite
        if palActSpr then
            local modeAct = palActSpr.colorMode
            if modeAct == ColorMode.GRAY then
                hexesProfile = AseUtilities.grayHexes(
                    AseUtilities.GRAY_COUNT)
            else
                hexesProfile = AseUtilities.asePalettesToHexArr(
                    palActSpr.palettes)
                local profileAct = palActSpr.colorSpace
                if profileAct then
                    -- Tests a number of color profile components for
                    -- approximate equality. See
                    -- https://github.com/aseprite/laf/blob/
                    -- 11ffdbd9cc6232faaff5eecd8cc628bb5a2c706f/
                    -- gfx/color_space.cpp#L142

                    -- It might be safer not to treat the NONE color
                    -- space as equivalent to SRGB, as the user could
                    -- have a display profile which differs radically.
                    local profileSrgb = ColorSpace { sRGB = true }
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
        local src = AseUtilities.DEFAULT_PAL_ARR
        local lenSrc = #src
        local i = 0
        while i < lenSrc do
            i = i + 1
            hexesProfile[i] = src[i]
        end
    end

    -- Copy by value as a precaution.
    if hexesSrgb == nil then
        hexesSrgb = {}
        local lenProf = #hexesProfile
        local i = 0
        while i < lenProf do
            i = i + 1
            hexesSrgb[i] = hexesProfile[i]
        end
    end

    -- Replace colors, e.g., 0x00ff0000 (clear red),
    -- so that all are clear black. Since both arrays
    -- should be of the same length, avoid the safety
    -- of using separate arrays.
    if correctZeroAlpha then
        local lenProf = #hexesProfile
        local i = 0
        while i < lenProf do
            i = i + 1
            if (hexesProfile[i] & 0xff000000) == 0x0 then
                hexesProfile[i] = 0x0
                hexesSrgb[i] = 0x0
            end
        end
    end

    return hexesProfile, hexesSrgb
end

---Converts an Aseprite palette to a table
---of Clrs. If the palette is nil returns a
---default table. Assumes palette is in sRGB.
---@param pal userdata Aseprite palette
---@param startIndex number start index
---@param count number sample count
---@return table
function AseUtilities.asePaletteToClrArr(pal, startIndex, count)
    if pal then
        local palLen = #pal

        local si = startIndex or 0
        si = math.min(palLen - 1, math.max(0, si))
        local vc = count or 256
        vc = math.min(palLen - si, math.max(2, vc))

        local clrs = {}
        local convert = AseUtilities.aseColorToClr
        for i = 0, vc - 1, 1 do
            clrs[1 + i] = convert(pal:getColor(si + i))
        end

        -- This is intended for gradient work, so it
        -- returns an array with a length greater than
        -- one no matter what.
        if #clrs == 1 then
            local a = clrs[1].a
            table.insert(clrs, 1, Clr.new(0.0, 0.0, 0.0, a))
            clrs[3] = Clr.new(1.0, 1.0, 1.0, a)
        end

        return clrs
    else
        return { Clr.clearBlack(), Clr.white() }
    end
end

---Converts an array of Aseprite palettes to a
---table of hex color integers.
---@param palettes table
---@return table
function AseUtilities.asePalettesToHexArr(palettes)
    if palettes then
        local lenPalettes = #palettes
        local hexes = {}
        local i = 0
        local k = 0
        while i < lenPalettes do
            i = i + 1
            local palette = palettes[i]
            if palette then
                local lenPalette = #palette
                local j = 0
                while j < lenPalette do
                    local aseColor = palette:getColor(j)
                    j = j + 1
                    local hex = AseUtilities.aseColorToHex(
                        aseColor, ColorMode.RGB)
                    k = k + 1
                    hexes[k] = hex
                end
            end
        end

        if #hexes == 1 then
            local amsk = hexes[1] & 0xff000000
            table.insert(hexes, 1, amsk)
            hexes[3] = amsk | 0x00ffffff
        end

        return hexes
    else
        return { 0x00000000, 0xffffffff }
    end
end

---Converts an Aseprite palette to a table of
---hex color integers. If the palette is nil
---returns a default table. Assumes palette
---is in sRGB. The start index defaults to 0;
---the count defaults to 256.
---@param pal userdata Aseprite palette
---@param startIndex number start index
---@param count number sample count
---@return table
function AseUtilities.asePaletteToHexArr(pal, startIndex, count)
    if pal then
        local palLen = #pal

        local si = startIndex or 0
        si = math.min(palLen - 1, math.max(0, si))
        local vc = count or 256
        vc = math.min(palLen - si, math.max(2, vc))

        local hexes = {}
        for i = 0, vc - 1, 1 do
            -- Do you have to worry about overflow due to
            -- rgb being out of gamut? Doesn't seem so, even
            -- in cases of color profile transforms...
            local aseColor = pal:getColor(si + i)
            hexes[1 + i] = aseColor.rgbaPixel
        end

        if #hexes == 1 then
            local amsk = hexes[1] & 0xff000000
            table.insert(hexes, 1, amsk)
            hexes[3] = amsk | 0x00ffffff
        end
        return hexes
    else
        return { 0x00000000, 0xffffffff }
    end
end

---Bakes a layer's opacity into the images of each
---cel held by the layer. Also bakes cel opacities.
---Does not support group layers. Resets layer and
---cel opacities to 255. Layers that are not visible
---are treated like layers with zero opacity.
---@param layer userdata layer
function AseUtilities.bakeLayerOpacity(layer)
    if layer.isGroup then
        app.alert("Layer opacity is not supported for group layers.")
        return
    end

    local layerAlpha = 0xff
    if layer.opacity then layerAlpha = layer.opacity end
    if not layer.isVisible then layerAlpha = 0 end
    local cels = layer.cels
    local lenCels = #cels

    if layerAlpha < 0xff then
        if layerAlpha < 0x01 then
            -- Layer is completely transparent.
            local i = 0
            while i < lenCels do
                i = i + 1
                local cel = cels[i]
                local img = cel.image
                local pxItr = img:pixels()
                for elm in pxItr do elm(0x0) end
                cel.opacity = 0xff
            end
        else
            -- Layer is semi-transparent.
            local i = 0
            while i < lenCels do
                i = i + 1
                local cel = cels[i]
                local celAlpha = cel.opacity
                local img = cel.image
                local pxItr = img:pixels()
                if celAlpha < 0xff then
                    if celAlpha < 0x01 then
                        -- Cel is completely transparent.
                        for elm in pxItr do elm(0x0) end
                    else
                        -- Cel and layer are both semi-transparent.
                        local layerCelAlpha = (layerAlpha * celAlpha) // 0xff
                        for elm in pxItr do
                            local hex = elm()
                            local srcAlpha = hex >> 0x18 & 0xff
                            local cmpAlpha = (layerCelAlpha * srcAlpha) // 0xff
                            if cmpAlpha < 1 then
                                elm(0x0)
                            else
                                elm((cmpAlpha << 0x18)
                                    | (hex & 0x00ffffff))
                            end
                        end
                    end
                else
                    -- Cel is opaque, but layer is semi-transparent.
                    for elm in pxItr do
                        local hex = elm()
                        local srcAlpha = hex >> 0x18 & 0xff
                        local cmpAlpha = (layerAlpha * srcAlpha) // 0xff
                        if cmpAlpha < 0x01 then
                            elm(0x0)
                        else
                            elm((cmpAlpha << 0x18)
                                | (hex & 0x00ffffff))
                        end
                    end
                end
                cel.opacity = 0xff
            end
        end
        layer.opacity = 0xff
    else
        -- Layer is completely opaque.
        local bakeCel = AseUtilities.bakeCelOpacity
        local i = 0
        while i < lenCels do
            i = i + 1
            bakeCel(cels[i])
        end
    end
end

---Bakes a cel's opacity into the colors in the cel's
---image. Resets the cel's opacity to 255. Does not
---refer to layer visibility or opacity.
---@param cel userdata cel
function AseUtilities.bakeCelOpacity(cel)
    local celAlpha = cel.opacity
    if celAlpha < 0xff then
        local img = cel.image
        local pxItr = img:pixels()
        if celAlpha < 0x01 then
            for elm in pxItr do elm(0x0) end
        else
            for elm in pxItr do
                local hex = elm()
                local srcAlpha = hex >> 0x18 & 0xff
                local cmpAlpha = (celAlpha * srcAlpha) // 0xff
                if cmpAlpha < 0x01 then
                    elm(0x0)
                else
                    elm((cmpAlpha << 0x18)
                        | (hex & 0x00ffffff))
                end
            end
        end
        cel.opacity = 0xff
    end
end

---Blends together two hexadecimal colors.
---Premultiplies each color by its alpha prior
---to blending. Unpremultiplies the result.
---For more information,
---see https://www.w3.org/TR/compositing-1/ .
---@param a number backdrop color
---@param b number overlay color
---@return number
function AseUtilities.blend(a, b)
    local t = b >> 0x18 & 0xff
    if t > 0xfe then return b end
    local v = a >> 0x18 & 0xff
    if v < 0x01 then return b end

    -- Experimented with subtracting
    -- from 0x100 instead of 0xff, due to 255//2
    -- not having a whole number middle, but 0xff
    -- lead to more accurate results.
    local u = 0xff - t
    if t > 0x7f then t = t + 1 end

    local uv = (v * u) // 0xff
    local tuv = t + uv
    if tuv < 0x01 then return 0x0 end
    if tuv > 0xff then tuv = 0xff end

    local ab = a >> 0x10 & 0xff
    local ag = a >> 0x08 & 0xff
    local ar = a & 0xff

    local bb = b >> 0x10 & 0xff
    local bg = b >> 0x08 & 0xff
    local br = b & 0xff

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
---@param format number format constant
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
---@param clr table clr
---@return userdata
function AseUtilities.clrToAseColor(clr)
    local r = clr.r
    local g = clr.g
    local b = clr.b
    local a = clr.a

    if r < 0.0 then r = 0.0 elseif r > 1.0 then r = 1.0 end
    if g < 0.0 then g = 0.0 elseif g > 1.0 then g = 1.0 end
    if b < 0.0 then b = 0.0 elseif b > 1.0 then b = 1.0 end
    if a < 0.0 then a = 0.0 elseif a > 1.0 then a = 1.0 end

    return Color(
        math.tointeger(0.5 + 255.0 * r),
        math.tointeger(0.5 + 255.0 * g),
        math.tointeger(0.5 + 255.0 * b),
        math.tointeger(0.5 + 255.0 * a))
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
---@param sprite userdata
---@param frameStartIndex number frame start index
---@param frameCount number frame count
---@param layerStartIndex number layer start index
---@param layerCount number layer count
---@param image userdata cel image
---@param position userdata cel position
---@param guiClr number hexadecimal color
---@return table
function AseUtilities.createNewCels(
    sprite,
    frameStartIndex, frameCount,
    layerStartIndex, layerCount,
    image, position, guiClr)

    if not sprite then
        app.alert("Sprite could not be found.")
        return {}
    end

    local sprLayers = sprite.layers
    local sprFrames = sprite.frames
    local sprLyrCt = #sprLayers
    local sprFrmCt = #sprFrames

    -- Validate layer start index.
    -- Allow for negative indices, which are wrapped.
    -- Length is one extra because this is an insert.
    local valLyrIdx = layerStartIndex or 1
    if valLyrIdx == 0 then
        valLyrIdx = 1
    else
        valLyrIdx = 1 + (valLyrIdx - 1) % (sprLyrCt + 1)
    end
    -- print("valLyrIdx: " .. valLyrIdx)

    -- Validate frame start index.
    local valFrmIdx = frameStartIndex or 1
    if valFrmIdx == 0 then
        valFrmIdx = 1
    else
        valFrmIdx = 1 + (valFrmIdx - 1) % (sprFrmCt + 1)
    end
    -- print("valFrmIdx: " .. valFrmIdx)

    -- Validate count for layers.
    local valLyrCt = layerCount or sprLyrCt
    if valLyrCt < 1 then
        valLyrCt = 1
    elseif valLyrCt > (1 + sprLyrCt - valLyrIdx) then
        valLyrCt = 1 + sprLyrCt - valLyrIdx
    end
    -- print("valLyrCt: " .. valLyrCt)

    -- Validate count for frames.
    local valFrmCt = frameCount or sprFrmCt
    if valFrmCt < 1 then
        valLyrCt = 1
    elseif valFrmCt > (1 + sprFrmCt - valFrmIdx) then
        valFrmCt = 1 + sprFrmCt - valFrmIdx
    end
    -- print("valFrmCt: " .. valFrmCt)

    local flatCount = valLyrCt * valFrmCt
    -- print("flatCount: " .. flatCount)
    if flatCount > AseUtilities.CEL_COUNT_LIMIT then
        local response = app.alert {
            title = "Warning",
            text = {
                string.format(
                    "This script will create %d cels,",
                    flatCount),
                string.format(
                    "%d beyond the limit of %d.",
                    flatCount - AseUtilities.CEL_COUNT_LIMIT,
                    AseUtilities.CEL_COUNT_LIMIT),
                "Do you wish to proceed?" },
            buttons = { "&YES", "&NO" }
        }

        if response == 2 then
            return {}
        end
    end

    local valPos = position or Point(0, 0)

    -- Shouldn't need to bother with image spec in this case.
    local valImg = image or Image(1, 1)

    -- Layers = y = rows
    -- Frames = x = columns
    local cels = {}
    app.transaction(function()
        local i = 0
        while i < flatCount do
            local frameIndex = valFrmIdx + (i % valFrmCt)
            local layerIndex = valLyrIdx + (i // valFrmCt)
            local frameObj = sprFrames[frameIndex]
            local layerObj = sprLayers[layerIndex]

            -- print(string.format("Frame Index %d", frameIndex))
            -- print(string.format("Layer Index %d", layerIndex))

            -- Frame and layer must objects, not indices.
            i = i + 1
            cels[i] = sprite:newCel(
                layerObj, frameObj, valImg, valPos)

        end
    end)

    local useGuiClr = guiClr and guiClr ~= 0x0
    if useGuiClr then
        local aseColor = AseUtilities.hexToAseColor(guiClr)
        app.transaction(function()
            local j = 0
            while j < flatCount do
                j = j + 1
                cels[j].color = aseColor
            end
        end)
    end

    return cels
end

---Creates new empty frames in a sprite. Prompts user
---to confirm if requested count exceeds a limit. Wraps
---the process in an app.transaction. Returns a table
---of frames. Frame duration is assumed to have been
---divided by 1000.0, and ready to be assigned as is.
---@param sprite userdata sprite
---@param count number frames to create
---@param duration number frame duration
---@return table
function AseUtilities.createNewFrames(sprite, count, duration)
    if not sprite then
        app.alert("Sprite could not be found.")
        return {}
    end

    if count < 1 then return {} end
    if count > AseUtilities.FRAME_COUNT_LIMIT then
        local response = app.alert {
            title = "Warning",
            text = {
                string.format(
                    "This script will create %d frames,",
                    count),
                string.format(
                    "%d beyond the limit of %d.",
                    count - AseUtilities.FRAME_COUNT_LIMIT,
                    AseUtilities.FRAME_COUNT_LIMIT),
                "Do you wish to proceed?" },
            buttons = { "&YES", "&NO" }
        }

        if response == 2 then
            return {}
        end
    end

    local valDur = duration or 1
    local valCount = count or 1
    if valCount < 1 then valCount = 1 end

    local frames = {}
    app.transaction(function()
        local i = 0
        while i < valCount do
            i = i + 1
            local frame = sprite:newEmptyFrame()
            frame.duration = valDur
            frames[i] = frame
        end
    end)
    return frames
end

---Creates new layers in a sprite. Prompts user
---to confirm if requested count exceeds a limit. Wraps
---the process in an app.transaction. To assign a GUI
-- color, use a hexadecimal integer as an argument.
---Returns a table of layers.
---@param sprite userdata sprite
---@param count number number of layers to create
---@param blendMode number blend mode
---@param opacity number layer opacity
---@param guiClr number hexadecimal color
---@param parent userdata parent layer
---@return table
function AseUtilities.createNewLayers(
    sprite,
    count,
    blendMode,
    opacity,
    guiClr,
    parent)

    if not sprite then
        app.alert("Sprite could not be found.")
        return {}
    end

    if count < 1 then return {} end
    if count > AseUtilities.LAYER_COUNT_LIMIT then
        local response = app.alert {
            title = "Warning",
            text = {
                string.format(
                    "This script will create %d layers,",
                    count),
                string.format(
                    "%d beyond the limit of %d.",
                    count - AseUtilities.LAYER_COUNT_LIMIT,
                    AseUtilities.LAYER_COUNT_LIMIT),
                "Do you wish to proceed?" },
            buttons = { "&YES", "&NO" }
        }

        if response == 2 then
            return {}
        end
    end

    local valOpac = opacity or 255
    if valOpac < 0 then valOpac = 0 end
    if valOpac > 255 then valOpac = 255 end
    local valBlendMode = blendMode or BlendMode.NORMAL
    local valCount = count or 1
    if valCount < 1 then valCount = 1 end

    local useGuiClr = guiClr and guiClr ~= 0x0
    local useParent = parent and parent.isGroup

    local oldLayerCount = #sprite.layers
    local layers = {}
    app.transaction(function()
        for i = 1, valCount, 1 do
            local layer = sprite:newLayer()
            layer.blendMode = valBlendMode
            layer.opacity = valOpac
            layer.name = string.format(
                "Layer %d",
                oldLayerCount + i)
            layers[i] = layer
        end
    end)

    if useGuiClr then
        local aseColor = AseUtilities.hexToAseColor(guiClr)
        app.transaction(function()
            for i = 1, valCount, 1 do
                layers[i].color = aseColor
            end
        end)
    end

    -- TODO: The user interface does not update the parent-
    -- child relationship when this is used. Is the problem
    -- that app global has been used when a local should've
    -- been passed in? or with parent not being within the
    -- scope of transaction?
    if useParent then
        app.transaction(function()
            for i = 1, valCount, 1 do
                local layer = layers[i]
                layer.parent = parent
            end
        end)
    end

    return layers
end

---Draws a border around an image's perimeter. Uses the
---Aseprite image instance method drawPixel. This means
---that the pixel changes will not be tracked as a
---transaction.
---@param img userdata Aseprite image
---@param border number border depth
---@param borderHex number hexadecimal color
function AseUtilities.drawBorder(img, border, borderHex)
    if border < 1 then return img end

    local wBorder = img.width
    local hBorder = img.height
    if border >= math.min(wBorder, hBorder) then
        local itr = img:pixels()
        for elm in itr do elm(borderHex) end
        return img
    end

    local bord2 = border + border
    local trgWidth = wBorder - bord2
    local trgHeight = hBorder - bord2

    -- Top edge.
    local minorTop = trgWidth + border
    local lenTop = border * minorTop - 1
    for i = 0, lenTop, 1 do
        img:drawPixel(
            i % minorTop,
            i // minorTop,
            borderHex)
    end

    -- Left edge.
    local lenLeft = (hBorder - border) * border - 1
    for i = 0, lenLeft, 1 do
        img:drawPixel(
            i % border,
            border + i // border,
            borderHex)
    end

    -- Right edge.
    local xOffsetRight = trgWidth + border
    local minorRight = wBorder - xOffsetRight
    local lenRight = (trgHeight + border) * minorRight - 1
    for i = 0, lenRight, 1 do
        img:drawPixel(
            xOffsetRight + i % minorRight,
            i // minorRight,
            borderHex)
    end

    -- Bottom edge.
    local yOffsetBottom = trgHeight + border
    local minorBottom = wBorder - border
    local lenBottom = (hBorder - yOffsetBottom) * minorBottom - 1
    for i = 0, lenBottom, 1 do
        img:drawPixel(
            border + i % minorBottom,
            yOffsetBottom + i // minorBottom,
            borderHex)
    end

    return img
end

---Draws a filled circle. Uses the Aseprite image
---instance method drawPixel. This means that the
---pixel changes will not be tracked as a transaction.
---@param image userdata Aseprite image
---@param xc number center x
---@param yc number center y
---@param r number radius
---@param hex number hexadecimal color
function AseUtilities.drawCircleFill(image, xc, yc, r, hex)
    local rsq = r * r
    local r2 = r * 2
    local lenn1 = r2 * r2 - 1
    local blend = AseUtilities.blend
    for i = 0, lenn1, 1 do
        local x = (i % r2) - r
        local y = (i // r2) - r
        if (x * x + y * y) < rsq then
            local xMark = xc + x
            local yMark = yc + y
            local srcHex = image:getPixel(xMark, yMark)
            local trgHex = blend(srcHex, hex)
            image:drawPixel(xMark, yMark, trgHex)
        end
    end
end

---Draws a curve in Aseprite with the contour tool.
---If a stroke is used, draws the stroke line by line.
---@param curve table curve
---@param resolution number curve resolution
---@param useFill boolean use fill
---@param fillClr userdata fill color
---@param useStroke boolean use stroke
---@param strokeClr userdata stroke color
---@param brsh userdata brush
---@param cel userdata cel
---@param layer userdata layer
function AseUtilities.drawCurve2(
    curve, resolution,
    useFill, fillClr,
    useStroke, strokeClr,
    brsh, cel, layer)

    local vres = 2
    if resolution > 2 then vres = resolution end

    local toPoint = AseUtilities.vec2ToPoint
    local bezier = Vec2.bezierPoint
    local insert = table.insert

    local isLoop = curve.closedLoop
    local kns = curve.knots
    local knsLen = #kns
    local toPercent = 1.0 / vres
    local pts = {}
    local start = 2
    local prevKnot = kns[1]
    if isLoop then
        start = 1
        prevKnot = kns[knsLen]
    end

    for i = start, knsLen, 1 do
        local currKnot = kns[i]

        local coPrev = prevKnot.co
        local fhPrev = prevKnot.fh
        local rhNext = currKnot.rh
        local coNext = currKnot.co

        insert(pts, toPoint(coPrev))
        for j = 1, vres, 1 do
            insert(pts,
                toPoint(bezier(
                    coPrev, fhPrev,
                    rhNext, coNext,
                    j * toPercent)))
        end

        prevKnot = currKnot
    end

    -- Draw fill.
    if isLoop and useFill then
        app.transaction(function()
            app.useTool {
                tool = "contour",
                color = fillClr,
                brush = brsh,
                points = pts,
                cel = cel,
                layer = layer,
                freehandAlgorithm = 1 }
        end)
    end

    -- Draw stroke.
    if useStroke then
        app.transaction(function()
            local ptPrev = pts[1]
            local ptsLen = #pts
            if isLoop then
                ptPrev = pts[ptsLen]
            end

            for i = start, ptsLen, 1 do
                local ptCurr = pts[i]
                app.useTool {
                    tool = "line",
                    color = strokeClr,
                    brush = brsh,
                    points = { ptPrev, ptCurr },
                    cel = cel,
                    layer = layer,
                    freehandAlgorithm = 1 }
                ptPrev = ptCurr
            end
        end)
    end

    app.refresh()
end

---Draws a glyph at its native scale to an image.
---The color is to be represented in hexadecimal
---with AABBGGR order.
---Operates on pixels. This should not be used
---with app.useTool.
---@param image userdata image
---@param glyph table glyph
---@param hex number hexadecimal color
---@param x number x top left corner
---@param y number y top left corner
---@param gw number glyph width
---@param gh number glyph height
function AseUtilities.drawGlyph(
    image, glyph, hex,
    x, y, gw, gh)

    local lenn1 = gw * gh - 1
    local blend = AseUtilities.blend
    local glMat = glyph.matrix
    local glDrop = glyph.drop
    local ypDrop = y + glDrop
    for i = 0, lenn1, 1 do
        local shift = lenn1 - i
        local mark = (glMat >> shift) & 1
        if mark ~= 0 then
            local xMark = x + (i % gw)
            local yMark = ypDrop + (i // gw)
            local srcHex = image:getPixel(xMark, yMark)
            local trgHex = blend(srcHex, hex)
            image:drawPixel(xMark, yMark, trgHex)
        end
    end
end

---Draws a glyph to an image at a pixel scale.
---Resizes the glyph according to nearest neighbor.
---The color is to be represented in hexadecimal
---with AABBGGR order.
---Operates on pixels. This should not be used
---with app.useTool.
---@param image userdata image
---@param glyph table glyph
---@param hex number hexadecimal color
---@param x number x top left corner
---@param y number y top left corner
---@param gw number glyph width
---@param gh number glyph height
---@param dw number display width
---@param dh number display height
function AseUtilities.drawGlyphNearest(
    image, glyph, hex,
    x, y, gw, gh, dw, dh)

    if gw == dw and gh == dh then
        return AseUtilities.drawGlyph(
            image, glyph, hex,
            x, y, gw, gh)
    end

    local lenTrgn1 = dw * dh - 1
    local lenSrcn1 = gw * gh - 1
    local tx = gw / dw
    local ty = gh / dh
    local trunc = math.tointeger
    local blend = AseUtilities.blend
    local glMat = glyph.matrix
    local glDrop = glyph.drop
    local ypDrop = y + glDrop * (dh / gh)
    for k = 0, lenTrgn1, 1 do
        local xTrg = k % dw
        local yTrg = k // dw

        local xSrc = trunc(xTrg * tx)
        local ySrc = trunc(yTrg * ty)
        local idxSrc = ySrc * gw + xSrc

        local shift = lenSrcn1 - idxSrc
        local mark = (glMat >> shift) & 1
        if mark ~= 0 then
            local xMark = x + xTrg
            local yMark = ypDrop + yTrg
            local srcHex = image:getPixel(xMark, yMark)
            local trgHex = blend(srcHex, hex)
            image:drawPixel(xMark, yMark, trgHex)
        end
    end
end

---Draws the knot handles of a curve.
---Color arguments are optional.
---@param curve table curve
---@param cel userdata cel
---@param layer userdata layer
---@param lnClr userdata line color
---@param coClr userdata coordinate color
---@param fhClr userdata fore handle color
---@param rhClr userdata rear handle color
function AseUtilities.drawHandles2(
    curve, cel, layer,
    lnClr, coClr, fhClr, rhClr)

    local kns = curve.knots
    local knsLen = #kns
    local drawKnot = AseUtilities.drawKnot2
    app.transaction(function()
        for i = 1, knsLen, 1 do
            drawKnot(
                kns[i], cel, layer,
                lnClr, coClr,
                fhClr, rhClr)
        end
    end)
end

---Draws a knot for diagnostic purposes.
---Color arguments are optional.
---@param knot table knot
---@param cel userdata cel
---@param layer userdata layer
---@param lnClr userdata line color
---@param coClr userdata coordinate color
---@param fhClr userdata fore handle color
---@param rhClr userdata rear handle color
function AseUtilities.drawKnot2(
    knot, cel, layer,
    lnClr, coClr, fhClr, rhClr)

    -- Do not supply hexadecimals to color constructor.
    local lnClrVal = lnClr or Color(175, 175, 175, 255)
    local rhClrVal = rhClr or Color(2, 167, 235, 255)
    local coClrVal = coClr or Color(235, 225, 40, 255)
    local fhClrVal = fhClr or Color(235, 26, 64, 255)

    local lnBrush = Brush { size = 1 }
    local rhBrush = Brush { size = 4 }
    local coBrush = Brush { size = 6 }
    local fhBrush = Brush { size = 5 }

    local coPt = AseUtilities.vec2ToPoint(knot.co)
    local fhPt = AseUtilities.vec2ToPoint(knot.fh)
    local rhPt = AseUtilities.vec2ToPoint(knot.rh)

    app.transaction(function()
        -- Line from rear handle to coordinate.
        app.useTool {
            tool = "line",
            color = lnClrVal,
            brush = lnBrush,
            points = { rhPt, coPt },
            cel = cel,
            layer = layer }

        -- Line from coordinate to fore handle.
        app.useTool {
            tool = "line",
            color = lnClrVal,
            brush = lnBrush,
            points = { coPt, fhPt },
            cel = cel,
            layer = layer }

        -- Rear handle point.
        app.useTool {
            tool = "pencil",
            color = rhClrVal,
            brush = rhBrush,
            points = { rhPt },
            cel = cel,
            layer = layer }

        -- Coordinate point.
        app.useTool {
            tool = "pencil",
            color = coClrVal,
            brush = coBrush,
            points = { coPt },
            cel = cel,
            layer = layer }

        -- Fore handle point.
        app.useTool {
            tool = "pencil",
            color = fhClrVal,
            brush = fhBrush,
            points = { fhPt },
            cel = cel,
            layer = layer }
    end)
end

---Draws a mesh in Aseprite with the contour tool.
---If a stroke is used, draws the stroke line by line.
---@param mesh table mesh
---@param useFill boolean use fill
---@param fillClr userdata fill color
---@param useStroke boolean use stroke
---@param strokeClr userdata stroke color
---@param brsh userdata brush
---@param cel userdata cel
---@param layer userdata layer
function AseUtilities.drawMesh2(
    mesh,
    useFill,
    fillClr,
    useStroke,
    strokeClr,
    brsh,
    cel,
    layer)

    -- Convert Vec2s to Points.
    -- Round Vec2 for improved accuracy.
    local vs = mesh.vs
    local vsLen = #vs
    local pts = {}
    local toPt = AseUtilities.vec2ToPoint
    for i = 1, vsLen, 1 do
        pts[i] = toPt(vs[i])
    end

    -- Group points by face.
    local fs = mesh.fs
    local fsLen = #fs
    local ptsGrouped = {}
    for i = 1, fsLen, 1 do
        local f = fs[i]
        local fLen = #f
        local ptsFace = {}
        for j = 1, fLen, 1 do
            ptsFace[j] = pts[f[j]]
        end
        ptsGrouped[i] = ptsFace
    end

    -- Group fills into one transaction.
    local useTool = app.useTool
    if useFill then
        app.transaction(function()
            for i = 1, fsLen, 1 do
                useTool {
                    tool = "contour",
                    color = fillClr,
                    brush = brsh,
                    points = ptsGrouped[i],
                    cel = cel,
                    layer = layer }
            end
        end)
    end

    -- Group strokes into one transaction.
    -- Draw strokes line by line.
    if useStroke then
        app.transaction(function()
            for i = 1, fsLen, 1 do
                local ptGroup = ptsGrouped[i]
                local ptgLen = #ptGroup
                local ptPrev = ptGroup[ptgLen]
                for j = 1, ptgLen, 1 do
                    local ptCurr = ptGroup[j]
                    useTool {
                        tool = "line",
                        color = strokeClr,
                        brush = brsh,
                        points = { ptPrev, ptCurr },
                        cel = cel,
                        layer = layer }
                    ptPrev = ptCurr
                end
            end
        end)
    end

    app.refresh()
end

---Draws an array of characters to an image
---horizontally according to the coordinates.
---Operates on pixel by pixel level. Its use
---should not be mixed with app.useTool.
---@param lut table glyph look up table
---@param image userdata image
---@param chars table characters table
---@param hex number hexadecimal color
---@param x number x top left corner
---@param y number y top left corner
---@param gw number glyph width
---@param gh number glyph height
---@param scale number display scale
function AseUtilities.drawStringHoriz(
    lut, image, chars, hex,
    x, y, gw, gh, scale)

    local writeChar = x
    local writeLine = y
    local charLen = #chars
    local dw = gw * scale
    local dh = gh * scale
    local scale2 = scale + scale
    local drawGlyph = AseUtilities.drawGlyphNearest
    local defGlyph = lut[' ']
    for i = 1, charLen, 1 do
        local ch = chars[i]
        -- print(ch)
        if ch == '\n' then
            writeLine = writeLine + dh + scale2
            writeChar = x
        else
            local glyph = lut[ch] or defGlyph
            -- print(glyph)

            drawGlyph(
                image, glyph, hex,
                writeChar, writeLine,
                gw, gh, dw, dh)
            writeChar = writeChar + dw
        end
    end
end

---Draws an array of characters to an image
---vertically according to the coordinates.
---Operates on pixel by pixel level. Its use
---should not be mixed with app.useTool.
---@param lut table glyph look up table
---@param image userdata image
---@param chars table characters table
---@param hex number hexadecimal color
---@param x number x top left corner
---@param y number y top left corner
---@param gw number glyph width
---@param gh number glyph height
---@param scale number display scale
function AseUtilities.drawStringVert(
    lut, image, chars, hex,
    x, y, gw, gh, scale)

    local writeChar = y
    local writeLine = x
    local charLen = #chars
    local dw = gw * scale
    local dh = gh * scale
    local scale2 = scale + scale
    local rotateCcw = AseUtilities.rotateGlyphCcw
    local drawGlyph = AseUtilities.drawGlyphNearest
    local defGlyph = lut[' ']
    for i = 1, charLen, 1 do
        local ch = chars[i]
        if ch == '\n' then
            writeLine = writeLine + dw + scale2
            writeChar = y
        else
            local glyph = lut[ch] or defGlyph
            glyph = rotateCcw(glyph, gw, gh)
            drawGlyph(
                image, glyph, hex,
                writeLine, writeChar,
                gh, gw, dh, dw)
            writeChar = writeChar - dh
        end
    end
end

---Returns a copy of the source image that has
---been flipped horizontally.
---Also returns displaced coordinates for the
---top-left corner.
---@param source userdata source image
---@return userdata
---@return number
---@return number
function AseUtilities.flipImageHoriz(source)
    local px = {}
    local i = 1
    local srcPxItr = source:pixels()
    for elm in srcPxItr do
        px[i] = elm()
        i = i + 1
    end

    local srcSpec = source.spec
    local w = srcSpec.width
    local pxFlp = Utilities.flipPixelsHoriz(px, w)

    local target = Image(srcSpec)
    local j = 1
    local trgPxItr = target:pixels()
    for elm in trgPxItr do
        elm(pxFlp[j])
        j = j + 1
    end
    return target, 1 - w, 0
end

---Returns a copy of the source image that has
---been flipped vertically.
---Also returns displaced coordinates for the
---top-left corner.
---@param source userdata source image
---@return userdata
---@return number
---@return number
function AseUtilities.flipImageVert(source)
    local px = {}
    local i = 1
    local srcPxItr = source:pixels()
    for elm in srcPxItr do
        px[i] = elm()
        i = i + 1
    end

    local srcSpec = source.spec
    local w = srcSpec.width
    local h = srcSpec.height
    local pxFlp = Utilities.flipPixelsVert(px, w, h)

    local target = Image(srcSpec)
    local j = 1
    local trgPxItr = target:pixels()
    for elm in trgPxItr do
        elm(pxFlp[j])
        j = j + 1
    end
    return target, 0, 1 - h
end

---Gets a selection copied by value from a sprite.
---If the selection is empty, returns the sprite's
---bounds instead, i.e., from (0, 0) to (w, h).
---@param sprite userdata sprite
---@return table
function AseUtilities.getSelection(sprite)
    local select = sprite.selection
    if (not select) or select.isEmpty then
        return Selection(sprite.bounds)
    else
        -- This precaution must be taken because
        -- a transform cage can be dragged off
        -- canvas, causing Aseprite to crash.
        -- Problem is that the square bounds is not
        -- necessarily the same as the selection, e.g.,
        -- if it's created with magic wand or circle.
        return Selection(
            select.bounds:intersect(sprite.bounds))
    end
end

---Creates a table of gray colors represented as
---32 bit integers, where the gray is repeated
---three times in red, green and blue channels.
---@param count number swatch count
---@return table
function AseUtilities.grayHexes(count)
    local trunc = math.tointeger
    local valCount = count or 255
    valCount = math.max(2, valCount)
    local toFac = 255.0 / (valCount - 1.0)
    local result = {}
    for i = 1, valCount, 1 do
        local g = trunc(0.5 + (i - 1) * toFac)
        result[i] = 0xff000000
            | (g << 0x10)
            | (g << 0x08)
            | g
    end
    return result
end

---Converts a hexadecimal integer to an Aseprite
---Color object. Does not use the Color constructor
---for this purpose, as the color mode dictates
---how the integer is interpreted.
---@param hex number hexadecimal color
---@return userdata
function AseUtilities.hexToAseColor(hex)
    -- See https://github.com/aseprite/aseprite/
    -- blob/main/src/app/script/color_class.cpp#L22
    return Color(hex & 0xff,
        (hex >> 0x08) & 0xff,
        (hex >> 0x10) & 0xff,
        (hex >> 0x18) & 0xff)
end

---Initializes a sprite and layer.
---Sets palette to the colors provided,
---or, if nil, a default set. Colors should
---be hexadecimal integers.
---@param wDefault number default width
---@param hDefault number default height
---@param layerName string layer name
---@param colors table array of hexes
---@param colorSpace userdata color space
---@return table
function AseUtilities.initCanvas(
    wDefault,
    hDefault,
    layerName,
    colors,
    colorSpace)

    local clrsVal = AseUtilities.DEFAULT_PAL_ARR
    if colors and #colors > 0 then
        clrsVal = colors
    end

    local sprite = app.activeSprite
    local layer = nil

    if sprite then
        layer = sprite:newLayer()
    else
        local wVal = 32
        local hVal = 32
        if wDefault and wDefault > 0 then wVal = wDefault end
        if hDefault and hDefault > 0 then hVal = hDefault end

        local spec = ImageSpec {
            width = wVal,
            height = hVal,
            colorMode = ColorMode.RGB,
            transparentColor = 0 }
        if colorSpace then
            spec.colorSpace = colorSpace
        end

        sprite = Sprite(spec)
        app.activeSprite = sprite
        layer = sprite.layers[1]
        AseUtilities.setSpritePalette(clrsVal, sprite, 1)
    end

    layer.name = layerName or "Layer"
    return sprite
end

---Evaluates whether a layer is editable in the context
---of any parent layers, i.e., if a layer's parent is
---locked but the layer is unlocked, the method will
---return false.
---@param layer userdata aseprite layer
---@param sprite userdata aseprite sprite
---@return boolean
function AseUtilities.isEditableHierarchy(layer, sprite)
    local l = layer
    local sprName = "doc::Sprite"
    if sprite then sprName = sprite.__name end
    while l.__name ~= sprName do
        if not l.isEditable then
            return false
        end
        l = l.parent
    end
    return true
end

---Evaluates whether a layer is visible in the context
---of any parent layers, i.e., if a layer's parent is
---invisible but the layer is visible, the method will
---return false. Makes no evaluation of the layer's
---opacity; a layer could still have 0 alpha.
---@param layer userdata aseprite layer
---@param sprite userdata aseprite sprite
---@return boolean
function AseUtilities.isVisibleHierarchy(layer, sprite)
    local l = layer
    local sprName = "doc::Sprite"
    if sprite then sprName = sprite.__name end
    while l.__name ~= sprName do
        if not l.isVisible then
            return false
        end
        l = l.parent
    end
    return true
end

---Preserves the application fore- and background
---colors across sprite changes. Copies and
---reassigns the colors to themselves.
function AseUtilities.preserveForeBack()
    app.fgColor = AseUtilities.aseColorCopy(app.fgColor, "")
    app.command.SwitchColors()
    app.fgColor = AseUtilities.aseColorCopy(app.fgColor, "")
    app.command.SwitchColors()
end

---Rotates a glyph counter-clockwise.
---The glyph is to be represented as a binary matrix
---with a width and height, where 1 draws a pixel
---and zero does not, packed in to a number
---in row major order.
---@param gl number glyph
---@param w number width
---@param h number height
---@return number
function AseUtilities.rotateGlyphCcw(gl, w, h)
    local lenn1 = (w * h) - 1
    local wn1 = w - 1
    local vr = 0
    for i = 0, lenn1, 1 do
        local shift0 = lenn1 - i
        local bit = (gl >> shift0) & 1

        local x = i // w
        local y = wn1 - (i % w)
        local j = y * h + x
        local shift1 = lenn1 - j
        vr = vr | (bit << shift1)
    end
    return vr
end

---Returns a copy of the source image that has
---been rotated 90 degrees counter-clockwise.
---Also returns displaced coordinates for the
---top-left corner.
---@param source userdata source image
---@return userdata
---@return number
---@return number
function AseUtilities.rotateImage90(source)
    local px = {}
    local i = 1
    local srcPxItr = source:pixels()
    for elm in srcPxItr do
        px[i] = elm()
        i = i + 1
    end

    local srcSpec = source.spec
    local w = srcSpec.width
    local h = srcSpec.height
    local pxRot = Utilities.rotatePixels90(px, w, h)

    local trgSpec = ImageSpec {
        width = h,
        height = w,
        colorMode = source.colorMode,
        transparentColor = srcSpec.transparentColor }
    trgSpec.colorSpace = srcSpec.colorSpace
    local target = Image(trgSpec)

    local j = 1
    local trgPxItr = target:pixels()
    for elm in trgPxItr do
        elm(pxRot[j])
        j = j + 1
    end
    return target, 0, 1 - w
end

---Returns a copy of the source image that has
---been rotated 180 degrees.
---Also returns displaced coordinates for the
---top-left corner.
---@param source userdata source image
---@return userdata
---@return number
---@return number
function AseUtilities.rotateImage180(source)
    local px = {}
    local i = 1
    local srcPxItr = source:pixels()
    for elm in srcPxItr do
        px[i] = elm()
        i = i + 1
    end

    -- Table is reversed in-place.
    Utilities.reverseTable(px)
    local target = Image(source.spec)
    local j = 1
    local trgPxItr = target:pixels()
    for elm in trgPxItr do
        elm(px[j])
        j = j + 1
    end

    return target,
        1 - source.width,
        1 - source.height
end

---Returns a copy of the source image that has
---been rotated 270 degrees counter-clockwise.
---Also returns displaced coordinates for the
---top-left corner.
---@param source userdata source image
---@return userdata
---@return number
---@return number
function AseUtilities.rotateImage270(source)
    local px = {}
    local i = 1
    local srcPxItr = source:pixels()
    for elm in srcPxItr do
        px[i] = elm()
        i = i + 1
    end

    local srcSpec = source.spec
    local w = srcSpec.width
    local h = srcSpec.height
    local pxRot = Utilities.rotatePixels270(px, w, h)

    local trgSpec = ImageSpec {
        width = h,
        height = w,
        colorMode = source.colorMode,
        transparentColor = srcSpec.transparentColor }
    trgSpec.colorSpace = srcSpec.colorSpace
    local target = Image(trgSpec)

    local j = 1
    local trgPxItr = target:pixels()
    for elm in trgPxItr do
        elm(pxRot[j])
        j = j + 1
    end
    return target, 1 - h, 0
end

---Sets a palette in a sprite at a given index to a table
---of colors represented as hexadecimal integers.
---@param arr table color array
---@param sprite userdata sprite
---@param paletteIndex number index
function AseUtilities.setSpritePalette(arr, sprite, paletteIndex)
    local palettes = sprite.palettes
    local lenPalettes = #palettes
    local lenHexArr = #arr
    local palIdxVerif = paletteIndex or 1
    palIdxVerif = 1 + (palIdxVerif - 1) % lenPalettes
    -- if lenHexArr > 0
    --     and paletteIndex
    --     and paletteIndex >= 1
    --     and paletteIndex <= lenPalettes then
    local palette = palettes[palIdxVerif]
    if lenHexArr > 0 then
        app.transaction(function()
            palette:resize(lenHexArr)
            for i = 1, lenHexArr, 1 do
                -- It is not better to pass a hex to setColor.
                -- Doing so creates the same problems as the Color
                -- rgbaPixel constructor, where an image's mode
                -- determines how the integer is interpreted.
                -- See https://github.com/aseprite/aseprite/
                -- blob/main/src/app/script/palette_class.cpp#L196 ,
                -- https://github.com/aseprite/aseprite/blob/
                -- main/src/app/color_utils.cpp .
                local hex = arr[i]
                local aseColor = AseUtilities.hexToAseColor(hex)
                palette:setColor(i - 1, aseColor)
                -- palette:setColor(i - 1, arr[i])
            end
        end)
    else
        app.transaction(function()
            palette:resize(1)
            palette:setColor(0, Color(0, 0, 0, 0))
        end)
    end
end

---Converts an image from a tile set layer to a regular
---image. Supported in Aseprite version 1.3 or newer.
---@param imgSrc userdata source image
---@param tileSet userdata tile set
---@param sprClrMode number sprite color mode
---@return userdata
function AseUtilities.tilesToImage(imgSrc, tileSet, sprClrMode)
    local tileDim = tileSet.grid.tileSize
    local tileWidth = tileDim.width
    local tileHeight = tileDim.height

    -- The source image's color mode is 4 if it is a tile map.
    -- Assigning 4 to the target image when the sprite color
    -- mode is 2 (indexed) causes Aseprite to crash.
    local specSrc = imgSrc.spec
    local specTrg = ImageSpec {
        width = specSrc.width * tileWidth,
        height = specSrc.height * tileHeight,
        colorMode = sprClrMode,
        transparentColor = specSrc.transparentColor }
    specTrg.colorSpace = specSrc.colorSpace
    local imgTrg = Image(specTrg)

    local itrSrc = imgSrc:pixels()
    for elm in itrSrc do
        imgTrg:drawImage(
            tileSet:getTile(elm()),
            Point(elm.x * tileWidth,
                elm.y * tileHeight))
    end

    return imgTrg
end

---Trims a cel's image and position such that it no longer
---exceeds the sprite's boundaries. Unlike built-in method,
---does not trim the image's alpha.
---@param cel userdata source cel
---@param sprite userdata parent sprite
function AseUtilities.trimCelToSprite(cel, sprite)
    local celBounds = cel.bounds
    local spriteBounds = sprite.bounds
    local clip = celBounds:intersect(spriteBounds)

    local oldPos = cel.position
    cel.position = Point(clip.x, clip.y)

    local celImg = cel.image
    local celImgSpec = celImg.spec
    local trimSpec = ImageSpec {
        width = clip.width,
        height = clip.height,
        colorMode = celImgSpec.colorMode,
        transparentColor = celImgSpec.transparentColor }
    trimSpec.colorSpace = celImgSpec.colorSpace
    local trimImage = Image(trimSpec)
    trimImage:drawImage(celImg, oldPos - cel.position)
    cel.image = trimImage
end

---Creates a copy of the image where excess
---transparent pixels have been trimmed from
---the edges. Padding is expected to be a positive
---number; it defaults to zero. Adapted from the
---Stack Overflow implementation by Oleg Mikhailov:
---https://stackoverflow.com/a/36938923 .
---
---Returns a tuple containing the cropped image,
---the top left x and top left y. The top left
---should be added to the position of the cel
---that contained the source image.
---@param image userdata aseprite image
---@param padding number padding
---@param alphaIndex number alpha mask index
---@return table
---@return number
---@return number
function AseUtilities.trimImageAlpha(image, padding, alphaIndex)

    -- This cannot be extracted to a separate function,
    -- perhaps because alphaIndex needs to remain in scope.
    local colorMode = image.colorMode
    local eval = nil
    if colorMode == ColorMode.RGB then
        eval = function(hex)
            return hex & 0xff000000 ~= 0
        end
    elseif colorMode == ColorMode.GRAY then
        eval = function(hex)
            return hex & 0xff00 ~= 0
        end
    elseif colorMode == ColorMode.INDEXED then
        local valMask = alphaIndex or 0
        eval = function(index)
            return index ~= valMask
        end
    else
        -- This is possible, esp. in Aseprite v1.3 with
        -- tilemap layers, where colorMode = 4.
        return image, 0, 0
    end

    -- Immutable.
    local width = image.width
    local height = image.height
    if width < 2 or height < 2 then
        return image, 0, 0
    end
    local widthn1 = width - 1
    local heightn1 = height - 1

    -- Mutable.
    local left = 0
    local top = 0
    local right = widthn1
    local bottom = heightn1
    local minRight = widthn1
    local minBottom = heightn1

    -- 1D for-loop attempt:
    -- https://github.com/behreajj/AsepriteAddons/blob/
    -- c157511958578e475a3172bd16d55f8ad20ed0b3/
    -- support/aseutilities.lua

    -- TODO: All for loops need to be converted due to
    -- this: https://www.lua.org/manual/5.3/manual.html#3.3.5

    -- Top edge.
    local breakTop = false
    while top < bottom do
        for x = 0, widthn1, 1 do
            if eval(image:getPixel(x, top)) then
                minRight = x
                minBottom = top
                breakTop = true
                break
            end
        end
        if breakTop then break end
        top = top + 1
    end

    -- Left edge.
    local breakLeft = false
    local topp1 = top + 1
    while left < minRight do
        for y = heightn1, topp1, -1 do
            if eval(image:getPixel(left, y)) then
                minBottom = y
                breakLeft = true
                break
            end
        end
        if breakLeft then break end
        left = left + 1
    end

    -- Bottom edge.
    local breakBottom = false
    while bottom > minBottom do
        for x = widthn1, left, -1 do
            if eval(image:getPixel(x, bottom)) then
                minRight = x
                breakBottom = true
                break
            end
        end
        if breakBottom then break end
        bottom = bottom - 1
    end

    -- Right edge.
    local breakRight = false
    while right > minRight do
        for y = bottom, top, -1 do
            if eval(image:getPixel(right, y)) then
                breakRight = true
                break
            end
        end
        if breakRight then break end
        right = right - 1
    end

    local wTrg = right - left
    local hTrg = bottom - top
    if wTrg < 1 or hTrg < 1 then
        return image, 0, 0
    end
    wTrg = wTrg + 1
    hTrg = hTrg + 1

    local valPad = padding or 0
    valPad = math.abs(valPad)
    local pad2 = valPad + valPad

    local trgSpec = ImageSpec {
        colorMode = colorMode,
        width = wTrg + pad2,
        height = hTrg + pad2,
        transparentColor = alphaIndex }
    trgSpec.colorSpace = image.spec.colorSpace
    local target = Image(trgSpec)

    -- local sampleRect = Rectangle(left, top, wTrg, hTrg)
    -- local srcItr = image:pixels(sampleRect)
    -- for elm in srcItr do
    --     target:drawPixel(
    --         valPad + elm.x - left,
    --         valPad + elm.y - top,
    --         elm())
    -- end

    -- This creates a transaction.
    target:drawImage(image, Point(valPad - left, valPad - top))
    return target, left - valPad, top - valPad
end

---Converts a Vec2 to an Aseprite Point.
---@param a table vector
---@return userdata
function AseUtilities.vec2ToPoint(a)
    return Point(
        Utilities.round(a.x),
        Utilities.round(a.y))
end

---Translates the pixels of an image by a vector,
---wrapping the elements that exceed its dimensions back
---to the beginning.
---@param source userdata source image
---@param x number x translation
---@param y number y translation
---@return userdata
function AseUtilities.wrapImage(source, x, y)
    local px = {}
    local i = 1
    local srcPxItr = source:pixels()
    for elm in srcPxItr do
        px[i] = elm()
        i = i + 1
    end

    local sourceSpec = source.spec
    local w = sourceSpec.width
    local h = sourceSpec.height
    local wrp = Utilities.wrapPixels(px, x, y, w, h)

    local target = Image(sourceSpec)
    local j = 1
    local trgPxItr = target:pixels()
    for elm in trgPxItr do
        elm(wrp[j])
        j = j + 1
    end

    return target
end

return AseUtilities
