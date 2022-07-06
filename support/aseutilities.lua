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
---@return userdata
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
            math.min(math.max(aseClr.red, 0), 255),
            math.min(math.max(aseClr.green, 0), 255),
            math.min(math.max(aseClr.blue, 0), 255),
            math.min(math.max(aseClr.alpha, 0), 255))
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
---@param clrMode integer color mode
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
---@param startIndex integer start index
---@param count integer count of colors to sample
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
                "A default palette will be used instead." } }
    end

    if palType == "FILE" then
        if filePath and #filePath > 0 then
            local exists = app.fs.isFile(filePath)
            if exists then
                -- Loading an .aseprite file with multiple palettes
                -- will register only the first palette. Also may be
                -- problems with color profiles being ignored.
                local palFile = Palette { fromFile = filePath }
                if palFile then
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
        while i < lenSrc do i = i + 1
            hexesProfile[i] = src[i]
        end
    end

    -- Copy by value as a precaution.
    if hexesSrgb == nil then
        hexesSrgb = {}
        local lenProf = #hexesProfile
        local i = 0
        while i < lenProf do i = i + 1
            hexesSrgb[i] = hexesProfile[i]
        end
    end

    -- Replace colors, e.g., 0x00ff0000 (clear red),
    -- so that all are clear black. Since both arrays
    -- should be of the same length, avoid the safety
    -- provided by separate loops.
    if correctZeroAlpha then
        local lenHexes = #hexesProfile
        local i = 0
        while i < lenHexes do i = i + 1
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
---@param pal userdata Aseprite palette
---@param startIndex integer|nil start index
---@param count integer|nil sample count
---@return table
function AseUtilities.asePaletteToHexArr(pal, startIndex, count)
    if pal then
        local palLen = #pal

        local si = startIndex or 0
        si = math.min(math.max(si, 0), palLen - 1)
        local vc = count or 256
        vc = math.min(math.max(vc, 2), palLen - si)

        local hexes = {}
        local i = 0
        local convert = AseUtilities.aseColorToHex
        while i < vc do
            local aseColor = pal:getColor(si + i)
            i = i + 1
            hexes[i] = convert(aseColor, ColorMode.RGB)
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
        local convert = AseUtilities.aseColorToHex
        while i < lenPalettes do
            i = i + 1
            local palette = palettes[i]
            if palette then
                local lenPalette = #palette
                local j = 0
                while j < lenPalette do
                    local aseColor = palette:getColor(j)
                    j = j + 1
                    local hex = convert(
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

---Bakes a layer's opacity into the images of each
---cel held by the layer. Also bakes cel opacities.
---Does not support group layers. Resets layer and
---cel opacities to 255. Layers that are not visible
---are treated like layers with zero opacity.
---@param layer userdata layer
function AseUtilities.bakeLayerOpacity(layer)
    if layer.isGroup then
        app.alert {
            title = "Error",
            text = "Layer opacity is not supported for group layers." }
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
---@param a integer backdrop color
---@param b integer overlay color
---@return integer
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
---@param format integer format constant
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
        math.floor(r * 0xff + 0.5),
        math.floor(g * 0xff + 0.5),
        math.floor(b * 0xff + 0.5),
        math.floor(a * 0xff + 0.5))
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
---@param frameStartIndex integer frame start index
---@param frameCount integer frame count
---@param layerStartIndex integer layer start index
---@param layerCount integer layer count
---@param image userdata cel image
---@param position userdata cel position
---@param guiClr integer hexadecimal color
---@return table
function AseUtilities.createCels(
    sprite,
    frameStartIndex, frameCount,
    layerStartIndex, layerCount,
    image, position, guiClr)

    -- Do not use app.transactions.
    -- https://github.com/aseprite/aseprite/issues/3276

    if not sprite then
        app.alert {
            title = "Error",
            text = "Sprite could not be found." }
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

    local useGuiClr = guiClr and guiClr ~= 0x0
    if useGuiClr then
        local aseColor = AseUtilities.hexToAseColor(guiClr)
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
---@param sprite userdata sprite
---@param count integer frames to create
---@param duration number frame duration
---@return table
function AseUtilities.createFrames(sprite, count, duration)

    -- Do not use app.transactions.
    -- https://github.com/aseprite/aseprite/issues/3276

    if not sprite then
        app.alert {
            title = "Error",
            text = "Sprite could not be found." }
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
    local i = 0
    while i < valCount do
        i = i + 1
        local frame = sprite:newEmptyFrame()
        frame.duration = valDur
        frames[i] = frame
    end
    return frames
end

---Creates new layers in a sprite. Prompts user
---to confirm if requested count exceeds a limit. Wraps
---the process in an app.transaction. To assign a GUI
-- color, use a hexadecimal integer as an argument.
---Returns a table of layers.
---@param sprite userdata sprite
---@param count integer number of layers to create
---@param blendMode integer blend mode
---@param opacity integer layer opacity
---@param guiClr integer hexadecimal color
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
        local i = 0
        while i < valCount do
            i = i + 1
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
            local i = 0
            while i < valCount do
                i = i + 1
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
            local i = 0
            while i < valCount do
                i = i + 1
                local layer = layers[i]
                layer.parent = parent
            end
        end)
    end

    return layers
end

---Draws a border within an image's perimeter. Uses the
---Aseprite image instance method drawPixel. This means
---that the pixel changes will not be tracked as a
---transaction.
---@param img userdata Aseprite image
---@param border integer border depth
---@param bordHex integer hexadecimal color
function AseUtilities.drawBorder(img, border, bordHex)
    -- This is no longer used by either layerExport
    -- or frameExport, but keep it around. The new
    -- strategy is to clear an image to a border color,
    -- then blit the inner image over that.
    if border < 1 then return img end
    if bordHex == img.spec.transparentColor then
        -- This could be misinterpreted if the bordHex
        -- color is expected to be an ABGR32 rather than
        -- whatever format is image appropriate.
        return img
    end
    local w = img.width
    local h = img.height
    if border >= math.min(w, h) then
        local itr = img:pixels()
        for elm in itr do elm(bordHex) end
        return img
    end

    local hnbord = h - border
    local wnbord = w - border
    local rect = Rectangle()

    -- Left edge.
    rect.x = 0
    rect.y = 0
    rect.width = border
    rect.height = hnbord
    local leftItr = img:pixels(rect)
    for elm in leftItr do elm(bordHex) end

    -- Top edge.
    rect.x = border
    rect.y = 0
    rect.width = wnbord
    rect.height = border
    local topItr = img:pixels(rect)
    for elm in topItr do elm(bordHex) end

    -- Right edge.
    rect.x = wnbord
    rect.y = border
    rect.width = border
    rect.height = hnbord
    local rightItr = img:pixels(rect)
    for elm in rightItr do elm(bordHex) end

    -- Bottom edge.
    rect.x = 0
    rect.y = hnbord
    rect.width = wnbord
    rect.height = border
    local bottomItr = img:pixels(rect)
    for elm in bottomItr do elm(bordHex) end

    return img
end

---Draws a filled circle. Uses the Aseprite image
---instance method drawPixel. This means that the
---pixel changes will not be tracked as a transaction.
---@param image userdata Aseprite image
---@param xc integer center x
---@param yc integer center y
---@param r integer radius
---@param hex integer hexadecimal color
function AseUtilities.drawCircleFill(image, xc, yc, r, hex)
    local blend = AseUtilities.blend
    local rsq = r * r
    local r2 = r * 2
    local lenn1 = r2 * r2 - 1
    local i = -1
    while i < lenn1 do
        i = i + 1
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
---@param resolution integer curve resolution
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

    local h = start - 1
    local j = 0
    while h < knsLen do h = h + 1
        local currKnot = kns[h]

        local coPrev = prevKnot.co
        local fhPrev = prevKnot.fh
        local rhNext = currKnot.rh
        local coNext = currKnot.co

        j = j + 1
        pts[j] = toPoint(coPrev)
        local i = 0
        while i < vres do
            i = i + 1
            j = j + 1
            pts[j] = toPoint(bezier(
                coPrev, fhPrev,
                rhNext, coNext,
                i * toPercent))
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

            local k = start - 1
            while k < ptsLen do
                k = k + 1
                local ptCurr = pts[k]
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
end

---Draws a glyph at its native scale to an image.
---The color is to be represented in hexadecimal
---with AABBGGR order.
---Operates on pixels. This should not be used
---with app.useTool.
---@param image userdata image
---@param glyph table glyph
---@param hex integer hexadecimal color
---@param x integer x top left corner
---@param y integer y top left corner
---@param gw integer glyph width
---@param gh integer glyph height
function AseUtilities.drawGlyph(
    image, glyph, hex,
    x, y, gw, gh)

    local lenn1 = gw * gh - 1
    local blend = AseUtilities.blend
    local glMat = glyph.matrix
    local glDrop = glyph.drop
    local ypDrop = y + glDrop

    local i = -1
    while i < lenn1 do i = i + 1
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
---@param hex integer hexadecimal color
---@param x integer x top left corner
---@param y integer y top left corner
---@param gw integer glyph width
---@param gh integer glyph height
---@param dw integer display width
---@param dh integer display height
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
    local floor = math.floor
    local blend = AseUtilities.blend
    local glMat = glyph.matrix
    local glDrop = glyph.drop
    local ypDrop = y + glDrop * (dh / gh)
    local k = -1
    while k < lenTrgn1 do
        k = k + 1
        local xTrg = k % dw
        local yTrg = k // dw

        local xSrc = floor(xTrg * tx)
        local ySrc = floor(yTrg * ty)
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
        local i = 0
        while i < knsLen do
            i = i + 1
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
    mesh, useFill, fillClr,
    useStroke, strokeClr,
    brsh, cel, layer)

    -- Convert Vec2s to Points.
    -- Round Vec2 for improved accuracy.
    local vs = mesh.vs
    local vsLen = #vs
    local pts = {}
    local toPt = AseUtilities.vec2ToPoint
    local idx0 = 0
    while idx0 < vsLen do
        idx0 = idx0 + 1
        pts[idx0] = toPt(vs[idx0])
    end

    -- Group points by face.
    local fs = mesh.fs
    local fsLen = #fs
    local ptsGrouped = {}
    local idx1 = 0
    while idx1 < fsLen do idx1 = idx1 + 1
        local f = fs[idx1]
        local fLen = #f
        local ptsFace = {}
        local idx2 = 0
        while idx2 < fLen do
            idx2 = idx2 + 1
            ptsFace[idx2] = pts[f[idx2]]
        end
        ptsGrouped[idx1] = ptsFace
    end

    -- Group fills into one transaction.
    local useTool = app.useTool
    if useFill then
        app.transaction(function()
            local idx3 = 0
            while idx3 < fsLen do
                idx3 = idx3 + 1
                useTool {
                    tool = "contour",
                    color = fillClr,
                    brush = brsh,
                    points = ptsGrouped[idx3],
                    cel = cel,
                    layer = layer }
            end
        end)
    end

    -- Group strokes into one transaction.
    -- Draw strokes line by line.
    if useStroke then
        app.transaction(function()
            local idx4 = 0
            while idx4 < fsLen do
                idx4 = idx4 + 1
                local ptGroup = ptsGrouped[idx4]
                local ptgLen = #ptGroup
                local ptPrev = ptGroup[ptgLen]
                local idx5 = 0
                while idx5 < ptgLen do
                    idx5 = idx5 + 1
                    local ptCurr = ptGroup[idx5]
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
end

---Draws an array of characters to an image
---according to the coordinates.
---Operates on pixel by pixel level. Its use
---should not be mixed with app.useTool.
---@param lut table glyph look up table
---@param image userdata image
---@param chars table characters table
---@param hex integer hexadecimal color
---@param x integer x top left corner
---@param y integer y top left corner
---@param gw integer glyph width
---@param gh integer glyph height
---@param scale integer display scale
function AseUtilities.drawString(
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
    local i = 0
    while i < charLen do
        i = i + 1
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

---Blits input image onto another that is the
---next power of 2 in dimension. The nonUniform
---flag specifies whether the result can have
---unequal width and height, e.g., 64x32. Returns
---the image by reference if its size is already
---a power of 2.
---@param img userdata image
---@param colorMode integer color mode
---@param alphaMask integer alpha mask index
---@param colorSpace userdata color space
---@param nonUniform boolean non uniform dimensions
---@return userdata
function AseUtilities.expandImageToPow2(
    img, colorMode, alphaMask,
    colorSpace, nonUniform)
    local wOrig = img.width
    local hOrig = img.height
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

    local potSpec = ImageSpec {
        width = wDest,
        height = hDest,
        colorMode = colorMode,
        transparentColor = alphaMask }
    potSpec.colorSpace = colorSpace
    local potImg = Image(potSpec)
    potImg:drawImage(img)
    return potImg
end

---Returns a copy of the source image that has
---been flipped horizontally.
---Also returns displaced coordinates for the
---top-left corner.
---@param source userdata source image
---@return userdata
---@return integer
---@return integer
function AseUtilities.flipImageHoriz(source)
    local px = {}
    local i = 0
    local srcPxItr = source:pixels()
    for elm in srcPxItr do
        i = i + 1
        px[i] = elm()
    end

    local srcSpec = source.spec
    local w = srcSpec.width
    local pxFlp = Utilities.flipPixelsHoriz(px, w)

    local target = Image(srcSpec)
    local j = 0
    local trgPxItr = target:pixels()
    for elm in trgPxItr do
        j = j + 1
        elm(pxFlp[j])
    end
    return target, 1 - w, 0
end

---Returns a copy of the source image that has
---been flipped vertically.
---Also returns displaced coordinates for the
---top-left corner.
---@param source userdata source image
---@return userdata
---@return integer
---@return integer
function AseUtilities.flipImageVert(source)
    local px = {}
    local i = 0
    local srcPxItr = source:pixels()
    for elm in srcPxItr do
        i = i + 1
        px[i] = elm()
    end

    local srcSpec = source.spec
    local w = srcSpec.width
    local h = srcSpec.height
    local pxFlp = Utilities.flipPixelsVert(px, w, h)

    local target = Image(srcSpec)
    local j = 0
    local trgPxItr = target:pixels()
    for elm in trgPxItr do
        j = j + 1
        elm(pxFlp[j])
    end
    return target, 0, 1 - h
end

---For sprites with multiple palettes, tries to get
---a palette from an Aseprite frame object. Defaults
---to index 1 if the frame index exceeds the number
---of palettes.
---@param frObj userdata|integer Aseprite frame object
---@param palettes table table of Aseprite palettes
---@return userdata
function AseUtilities.getPalette(frObj, palettes)
    -- TODO: Where else can this be used?
    local idx = 1
    local typeFrObj = type(frObj)
    if typeFrObj == "number"
        and math.type(frObj) == "integer" then
        idx = frObj
    elseif typeFrObj == "userdata" then
        idx = frObj.frameNumber
    end
    local lenPalettes = #palettes
    if idx > lenPalettes then idx = 1 end
    return palettes[idx]
end

---Gets a selection copied by value from a sprite.
---If the selection is empty, returns the sprite's
---bounds instead, i.e., from (0, 0) to (w, h).
---If the selection is not entirely contained by
---the canvas, returns the bounds intersection.
---@param sprite userdata sprite
---@return table
function AseUtilities.getSelection(sprite)
    local sel = sprite.selection
    if (not sel) or sel.isEmpty then
        return Selection(sprite.bounds)
    end

    local selBounds = sel.bounds
    local sprBounds = sprite.bounds
    local tlx = selBounds.x
    local tly = selBounds.y
    local brx = tlx + selBounds.width - 1
    local bry = tly + selBounds.height - 1

    -- A selection can be moved partially
    -- or entirely outside the canvas bounds,
    -- leading Aseprite to crash.
    if (tlx >= 0) and (tly >= 0)
        and (brx <= sprBounds.width)
        and (bry <= sprBounds.height) then
        local sprSel = Selection(sprBounds)
        sprSel:intersect(sel)
        return sprSel
    else
        return Selection(
            sprBounds:intersect(selBounds))
    end
end

---Creates a table of gray colors represented as
---32 bit integers, where the gray is repeated
---three times in red, green and blue channels.
---@param count integer swatch count
---@return table
function AseUtilities.grayHexes(count)
    local floor = math.floor
    local valCount = count or 255
    valCount = math.max(2, valCount)
    local toFac = 255.0 / (valCount - 1.0)
    local result = {}
    local i = 0
    while i < valCount do
        local g = floor(0.5 + i * toFac)
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
---@return userdata
function AseUtilities.hexToAseColor(hex)
    -- See https://github.com/aseprite/aseprite/
    -- blob/main/src/app/script/color_class.cpp#L22
    return Color(hex & 0xff,
        (hex >> 0x08) & 0xff,
        (hex >> 0x10) & 0xff,
        (hex >> 0x18) & 0xff)
end

---Initializes a sprite and layer. Sets palette
---to the colors provided, or, if nil, a default
---set. Colors should be hexadecimal integers.
---@param wDefault integer default width
---@param hDefault integer default height
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
        local wVal = app.preferences.new_file.width
        local hVal = app.preferences.new_file.height
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
        AseUtilities.setPalette(clrsVal, sprite, 1)
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
---opacity. A layer could still have 0 alpha.
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

---Parses Aseprite range object to find the
---frames it contains. Returns an array
---of frame indices.
---@param range userdata Aseprite range
---@return table
function AseUtilities.parseRange(range)
    local framesObj = range.frames
    local framIdcs = {}
    local lenFramesObj = #framesObj
    local i = 0
    while i < lenFramesObj do
        i = i + 1
        framIdcs[i] = framesObj[i].frameNumber
    end
    -- This doesn't need sorting.
    return framIdcs
end

---Parses an Aseprite Tag to an array of frame
---indices. For example, a tag with a fromFrame
---of 8 and a toFrame of 10 will return 8, 9, 10
---if the tag has FORWARD direction; 10, 9, 8 for
---REVERSE; 8, 9, 10, 9 for PING_PONG. Ping-pong
---is upper-bounds exclusive so that other
---renderers will not draw the boundary twice.
---
---It is possible for a tag to contain frame
---indices that are out-of-bounds for the sprite
---that contains the tag. This function assumes
---the tag is valid.
---@param tag userdata Aseprite Tag
---@return table
function AseUtilities.parseTag(tag)
    local origFrameObj = tag.fromFrame
    local destFrameObj = tag.toFrame
    local origIdx = origFrameObj.frameNumber
    local destIdx = destFrameObj.frameNumber

    local arr = {}
    local idxArr = 0

    local aniDir = tag.aniDir
    if aniDir == AniDir.PING_PONG then
        if destIdx ~= origIdx then
            local j = origIdx - 1
            while j < destIdx do
                j = j + 1
                idxArr = idxArr + 1
                arr[idxArr] = j
            end
            local op1 = origIdx + 1
            while j > op1 do
                j = j - 1
                idxArr = idxArr + 1
                arr[idxArr] = j
            end
        else
            idxArr = idxArr + 1
            arr[idxArr] = destIdx
        end
    elseif aniDir == AniDir.REVERSE then
        local j = destIdx + 1
        while j > origIdx do
            j = j - 1
            idxArr = idxArr + 1
            arr[idxArr] = j
        end
    else
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
---an array of arrays. It is possible
---for inner arrays to hold duplicate frame
---indices,  as the user may intend for the
---same frame to appear in multiple groups.
---@param tags table tags array
---@return table
function AseUtilities.parseTagsOverlap(tags)
    local tagsLen = #tags
    local arr2 = {}
    local i = 0
    while i < tagsLen do
        i = i + 1
        arr2[i] = AseUtilities.parseTag(tags[i])
    end
    return arr2
end

---Parses an array of Aseprite tags. Returns
---an ordered set of integers.
---@param tags table tags array
---@return table
function AseUtilities.parseTagsUnique(tags)
    local arr2 = AseUtilities.parseTagsOverlap(tags)
    local dict = {}
    local i = 0
    local lenArr2 = #arr2
    while i < lenArr2 do
        i = i + 1
        local arr1 = arr2[i]
        local lenArr1 = #arr1
        local j = 0
        while j < lenArr1 do
            j = j + 1
            dict[arr1[j]] = true
        end
    end

    return Utilities.dictToSortedSet(dict, nil)
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

---Returns a copy of the source image that has
---been rotated 90 degrees counter-clockwise.
---Also returns displaced coordinates for the
---top-left corner.
---@param source userdata source image
---@return userdata
---@return integer
---@return integer
function AseUtilities.rotateImage90(source)
    local px = {}
    local i = 0
    local srcPxItr = source:pixels()
    for elm in srcPxItr do
        i = i + 1
        px[i] = elm()
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

    local j = 0
    local trgPxItr = target:pixels()
    for elm in trgPxItr do
        j = j + 1
        elm(pxRot[j])
    end
    return target, 0, 1 - w
end

---Returns a copy of the source image that has
---been rotated 180 degrees. Also returns
---displaced coordinates for the top-left corner.
---@param source userdata source image
---@return userdata
---@return integer
---@return integer
function AseUtilities.rotateImage180(source)
    local px = {}
    local i = 0
    local srcPxItr = source:pixels()
    for elm in srcPxItr do
        i = i + 1
        px[i] = elm()
    end

    -- Table is reversed in-place.
    Utilities.reverseTable(px)
    local target = Image(source.spec)
    local j = 0
    local trgPxItr = target:pixels()
    for elm in trgPxItr do
        j = j + 1
        elm(px[j])
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
---@return integer
---@return integer
function AseUtilities.rotateImage270(source)
    local px = {}
    local i = 0
    local srcPxItr = source:pixels()
    for elm in srcPxItr do
        i = i + 1
        px[i] = elm()
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

    local j = 0
    local trgPxItr = target:pixels()
    for elm in trgPxItr do
        j = j + 1
        elm(pxRot[j])
    end
    return target, 1 - h, 0
end

---Sets a palette in a sprite at a given index to a table
---of colors represented as hexadecimal integers. The
---palette index defaults to 1.
---@param arr table color array
---@param sprite userdata sprite
---@param paletteIndex integer|nil index
function AseUtilities.setPalette(arr, sprite, paletteIndex)
    local palIdxVerif = paletteIndex or 1
    local palettes = sprite.palettes
    local lenPalettes = #palettes
    local lenHexArr = #arr
    -- This should be consistent behavior with getPalette.
    if palIdxVerif > lenPalettes then palIdxVerif = 1 end
    local palette = palettes[palIdxVerif]
    if lenHexArr > 0 then
        app.transaction(function()
            palette:resize(lenHexArr)
            local i = 0
            while i < lenHexArr do
                i = i + 1
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
---@param sprClrMode integer sprite color mode
---@return userdata
function AseUtilities.tilesToImage(imgSrc, tileSet, sprClrMode)
    local tileDim = tileSet.grid.tileSize
    local tileWidth = tileDim.width
    local tileHeight = tileDim.height

    -- The source image's color mode is 4 if it is a tile map.
    -- Assigning 4 to the target image when the sprite color
    -- mode is 2 (indexed) crashes Aseprite.
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
---number. It defaults to zero. Adapted from the
---implementation by Oleg Mikhailov:
---https://stackoverflow.com/a/36938923 .
---
---Returns a tuple containing the cropped image,
---the top left x and top left y. The top left
---should be added to the position of the cel
---that contained the source image.
---@param image userdata aseprite image
---@param padding integer padding
---@param alphaIndex integer alpha mask index
---@return userdata
---@return integer
---@return integer
function AseUtilities.trimImageAlpha(image, padding, alphaIndex)

    -- getPixel returns white when coordinates are out of
    -- bounds. If extra diagnostics are needed:
    -- if x < 0 then print("x is < 0 in ... ") end
    -- if x >= width then print("x is >= width in ... ") end
    -- if y < 0 then print("y is < 0 in ... ") end
    -- if y >= height then print( "y is >= height in ... ") end

    -- This cannot be extracted to a separate function,
    -- perhaps because alphaIndex needs to remain in scope.
    local colorMode = image.colorMode
    local isNonZero = nil
    if colorMode == ColorMode.RGB then
        isNonZero = function(hex)
            return hex & 0xff000000 ~= 0
        end
    elseif colorMode == ColorMode.GRAY then
        isNonZero = function(hex)
            return hex & 0xff00 ~= 0
        end
    elseif colorMode == ColorMode.INDEXED then
        local valMask = alphaIndex or 0
        isNonZero = function(index)
            return index ~= valMask
        end
    else
        -- This is possible, esp. in Aseprite v1.3 with
        -- tilemap layers, where colorMode = 4.
        return image, 0, 0
    end

    local width = image.width
    local height = image.height
    if width < 2 or height < 2 then
        -- What about padding?
        return image, 0, 0
    end

    local widthn1 = width - 1
    local heightn1 = height - 1
    local minRight = widthn1
    local minBottom = heightn1

    -- Top edge.
    local top = -1
    local goTop = true
    while top < heightn1 and goTop do top = top + 1
        local x = -1
        while x < widthn1 and goTop do x = x + 1
            if isNonZero(image:getPixel(x, top)) then
                minRight = x
                minBottom = top
                goTop = false
            end
        end
    end

    -- Left edge.
    local lft = -1
    local goLft = true
    while lft < minRight and goLft do lft = lft + 1
        local y = height
        while y > top and goLft do y = y - 1
            if isNonZero(image:getPixel(lft, y)) then
                minBottom = y
                goLft = false
            end
        end
    end

    -- Bottom edge.
    local btm = height
    local goBtm = true
    while btm > minBottom and goBtm do btm = btm - 1
        local x = width
        while x > lft and goBtm do x = x - 1
            if isNonZero(image:getPixel(x, btm)) then
                minRight = x
                goBtm = false
            end
        end
    end

    -- Right edge.
    local rgt = width
    local goRgt = true
    while rgt > minRight and goRgt do rgt = rgt - 1
        local y = btm + 1
        while y > top and goRgt do y = y - 1
            if isNonZero(image:getPixel(rgt, y)) then
                goRgt = false
            end
        end
    end

    local wTrg = rgt - lft
    local hTrg = btm - top
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
    target:drawImage(image, Point(valPad - lft, valPad - top))
    return target, lft - valPad, top - valPad
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
---@param x integer x translation
---@param y integer y translation
---@return userdata
function AseUtilities.wrapImage(source, x, y)
    local px = {}
    local i = 0
    local srcPxItr = source:pixels()
    for elm in srcPxItr do
        i = i + 1
        px[i] = elm()
    end

    local sourceSpec = source.spec
    local w = sourceSpec.width
    local h = sourceSpec.height
    local wrp = Utilities.wrapPixels(px, x, y, w, h)

    local target = Image(sourceSpec)
    local j = 0
    local trgPxItr = target:pixels()
    for elm in trgPxItr do
        j = j + 1
        elm(wrp[j])
    end

    return target
end

return AseUtilities
