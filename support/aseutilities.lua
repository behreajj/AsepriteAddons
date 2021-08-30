dofile("./clr.lua")
dofile("./curve2.lua")
dofile("./mesh2.lua")
dofile("./utilities.lua")
dofile("./vec2.lua")

AseUtilities = {}
AseUtilities.__index = AseUtilities

setmetatable(AseUtilities, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

-- Maximum number of a cels a script may
-- request to create before the user is
-- prompted to confirm.
AseUtilities.CEL_COUNT_LIMIT = 256

-- Maximum number of frames a script may
-- request to create before the user is
-- prompted to confirm.
AseUtilities.FRAME_COUNT_LIMIT = 256

-- Maximum number of layers a script may
-- request to create before the user is
-- prompted to confirm.
AseUtilities.LAYER_COUNT_LIMIT = 96

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
---@param aseClr table Aseprite color
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
        return Color(aseClr.rgbaPixel)
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
---@param aseClr table Aseprite color
---@return table
function AseUtilities.aseColorToClr(aseClr)
    return Clr.new(
        0.00392156862745098 * aseClr.red,
        0.00392156862745098 * aseClr.green,
        0.00392156862745098 * aseClr.blue,
        0.00392156862745098 * aseClr.alpha)
end

---Returns a string containing diagnostic information
---about an Aseprite Color object. Format lists the
---nearest palette index, the red, green, blue and
---alpha in unsigned byte range [0, 255], and a web
---friendly hexadecimal representation.
---@param aseColor table Aseprite color
---@return string
function AseUtilities.aseColorToString(aseColor)
    local r = aseColor.red
    local g = aseColor.green
    local b = aseColor.blue
    -- Index is meaningless, as it seems to include
    -- nearest color in palette index, is a real number,
    -- and it's not clear when it could be mutated or
    -- by whom.
    -- local idx = math.tointeger(aseColor.index)
    return string.format(
        "(%03d, %03d, %03d, %03d) #%06X",
        r, g, b,
        aseColor.alpha,
        r << 0x10 | g << 0x08 | b)
end

---Returns a string containing diagnostic information
---about an Aseprite Color object.
---@param pal table Aseprite palette
---@param startIndex number start index
---@param count number sample count
---@return string
function AseUtilities.asePaletteToString(pal, startIndex, count)
    local palLen = #pal

    local si = startIndex or 0
    si = math.min(palLen - 1, math.max(0, si))
    local vc = count or 256
    vc = math.min(palLen - si, math.max(2, vc)) - 1

    -- Using \r for carriage returns causes formatting bug.
    local str = ""
    for i = 0, vc, 1 do
        local palIdx = si + i
        str = str
            .. string.format("%03d. ", palIdx)
            .. AseUtilities.aseColorToString(
                pal:getColor(palIdx))
        if i < vc then
            str = str .. ",\n"
        end
    end

    return str
end

---Loads a palette based on a string. The string is
---expected to be either "FILE", "PRESET" or "ACTIVE".
---Returns a tuple of tables. The first table is an
---array of hexadecimals according to the profile; the
---second is a copy of the first converted to SRGB.
---If a palette is loaded from a filepath or a preset the
---two tables should match, as Aseprite does not support
---color management for palettes. The correctNoAlpha
---flag checks for colors with zero alpha that are not
---black and replaces them with 0x00000000.
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

    local errorHandler = function ( err )
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
            local palAct = palActSpr.palettes[1]
            if palAct then
                local modeAct = palActSpr.colorMode
                if modeAct == ColorMode.GRAY then
                    hexesProfile = {}
                    for i = 0, 255, 1 do
                        -- Add opacity or no?
                        -- hexesProfile[1 + i] = (i << 0x18)
                        hexesProfile[1 + i] = 0xff000000
                            | (i << 0x10)
                            | (i << 0x08)
                            | i
                    end
                else
                    hexesProfile = AseUtilities.asePaletteToHexArr(
                        palAct, siVal, cntVal)
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
                            hexesSrgb = AseUtilities.asePaletteToHexArr(
                                palAct, siVal, cntVal)
                            palActSpr:convertColorSpace(profileAct)
                        end
                    end
                end
            end
        end
    end

    -- Malformed file path could lead to nil.
    if hexesProfile == nil then
        hexesProfile = {}
        local src = AseUtilities.DEFAULT_PAL_ARR
        local srcLen = #src
        for i = 1, srcLen, 1 do
            hexesProfile[i] = src[i]
        end
    end

    -- Replace colors, e.g., 0x00ff0000 (clear red),
    -- so that all are clear black.
    if correctZeroAlpha then
        for i = 1, #hexesProfile, 1 do
            local hex = hexesProfile[i]
            local alpha = (hex >> 0x18) & 0xff
            if alpha < 1 then
                hexesProfile[i] = 0x0
            end
        end
    end

    -- Copy by value as a precaution.
    if hexesSrgb == nil then
        hexesSrgb = {}
        for j = 1, #hexesProfile, 1 do
            hexesSrgb[j] = hexesProfile[j]
        end
    end

    return hexesProfile, hexesSrgb
end

---Converts an Aseprite palette to a table
---of Aseprite Colors. If the palette is nil
---returns a default table. Assumes palette
---is in sRGB.
---@param pal table Aseprite palette
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

---Converts an Aseprite palette to a table of
---hex color integers. If the palette is nil
---returns a default table. Assumes palette
---is in sRGB.
---@param pal table Aseprite palette
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

---Blends together two hexadecimal colors.
---Premultiplies each color by its alpha prior
---to blending. Unpremultiplies the result.
---For more information,
---see https://www.w3.org/TR/compositing-1/ .
---@param a number backdrop color
---@param b number overlay color
---@return number
function AseUtilities.blend(a, b)

    -- TODO: Still getting overflow here
    -- in cases where alpha is <255
    local t = b >> 0x18 & 0xff
    if t > 0xfe then return b end
    local v = a >> 0x18 & 0xff
    if v < 0x01 then return b end

    local bb = b >> 0x10 & 0xff
    local bg = b >> 0x08 & 0xff
    local br = b & 0xff

    local ab = a >> 0x10 & 0xff
    local ag = a >> 0x08 & 0xff
    local ar = a & 0xff

    -- Experimented with subtracting
    -- from 0x100 instead of 0xff, due to 255//2
    -- not having a whole number middle, but 0xff
    -- lead to more accurate results.
    local u = 0xff - t
    if t > 0x7e then t = t + 1 end

    local uv = (v * u) // 0xff
    local tuv = t + uv

    if tuv > 0xfe then
        local cr = (bb * t + ab * uv) // 0xff
        local cg = (bg * t + ag * uv) // 0xff
        local cb = (br * t + ar * uv) // 0xff

        if cr > 0xff then cr = 0xff end
        if cg > 0xff then cg = 0xff end
        if cb > 0xff then cb = 0xff end
        return 0xff000000
            | cr << 0x10
            | cg << 0x08
            | cb
    elseif tuv > 0x1 then
        local tuvn1 = tuv
        if tuv > 0x7e then tuvn1 = tuv - 1 end
        return tuv << 0x18
            | ((bb * t + ab * uv) // tuvn1) << 0x10
            | ((bg * t + ag * uv) // tuvn1) << 0x08
            | ((br * t + ar * uv) // tuvn1)
    else
        return 0x00000000
    end
end

---Converts a Clr to an Aseprite Color.
---Assumes that source and target are in sRGB.
---Clamps the Clr's channels to [0.0, 1.0] before
---they are converted. Beware that this could return
---(255, 0, 0, 0) or (0, 255, 0, 0), which may be
---visually indistinguishable from - and confused
--- with - an alpha mask, (0, 0, 0, 0).
---@param clr table clr
---@return table
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

---Draws a filled circle. Uses the Aseprite image
---instance method drawPixel. This means that the
---pixel changes will not be tracked as a transaction.
---@param image table Aseprite image
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
---@param fillClr table fill color
---@param useStroke boolean use stroke
---@param strokeClr table stroke color
---@param brsh table brush
---@param cel table cel
---@param layer table layer
function AseUtilities.drawCurve2(
    curve, resolution,
    useFill, fillClr,
    useStroke, strokeClr,
    brsh, cel, layer)

    local vres = 2
    if resolution > 2 then vres = resolution end

    local isLoop = curve.closedLoop
    local kns = curve.knots
    local knsLen = #kns
    local toPercent = 1.0 / vres
    local toPoint = AseUtilities.vec2ToPoint
    local bezier = Vec2.bezierPoint
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

        table.insert(pts, toPoint(coPrev))
        for j = 1, vres, 1 do
            table.insert(pts,
                toPoint(bezier(
                    coPrev, fhPrev,
                    rhNext,coNext,
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

---Creates new cels in a sprite. Prompts users to
---confirm if requested count exceeds a limit. The
---count is derived from frameCount x layerCount.
---Returns a one-dimensional table of cels, where
---layers are treated as rows, frames are treated
---as columns and the flat ordering is row-major.
---To assign a GUI color, use a hexadecimal integer
---as an argument.
---Returns a table of layers.
---@param sprite table
---@param frameStartIndex number frame start index
---@param frameCount number frame count
---@param layerStartIndex number layer start index
---@param layerCount number layer count
---@param image table cel image
---@param position table cel position
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
    local valLyrIdx = layerStartIndex or 1
    if valLyrIdx == 0 then
        valLyrIdx = 1
    else
        valLyrIdx = 1 + ((valLyrIdx - 1) % (sprLyrCt + 1))
    end
    -- print("valLyrIdx: " .. valLyrIdx)

    -- Validate frame start index.
    local valFrmIdx = frameStartIndex or 1
    if valFrmIdx == 0 then
        valFrmIdx = 1
    else
        valFrmIdx = 1 + ((valFrmIdx - 1) % (sprFrmCt + 1))
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
                "Do you wish to proceed?"
            },
            buttons = { "&YES", "&NO" }
        }

        if response == 2 then
            return {}
        end
    end

    local valPos = position or Point(0, 0)
    local valImg = image or Image(1, 1)

    -- Layers = y = rows
    -- Frames = x = columns
    local cels = {}
    app.transaction(function()
        for i = 0, flatCount - 1, 1 do
            local frameIndex = valFrmIdx + (i % valFrmCt)
            local frame = sprFrames[frameIndex]

            local layerIndex = valLyrIdx + (i // valFrmCt)
            local layer = sprLayers[layerIndex]

            -- print(string.format("Frame Index %d", frameIndex))
            -- print(string.format("Layer Index %d", layerIndex))

            -- Doesn't work when trying to access existing cels.
            cels[1 + i] = sprite:newCel(
                layer, frame, valImg, valPos)

        end
    end)

    local useGuiClr = guiClr and guiClr ~= 0x0
    if useGuiClr then
        local aseColor = Color(guiClr)
        for i = 1, flatCount, 1 do
            cels[i].color = aseColor
        end
    end

    return cels
end

---Creates new empty frames in a sprite. Prompts user
---to confirm if requested count exceeds a limit. Wraps
---the process in an app.transaction. Returns a table
---of frames. Frame duration is assumed to have been
---divided by 1000.0, and ready to be assigned as is.
---@param sprite table sprite
---@param count number frames to create
---@param duration number frame duration
---@return table
function AseUtilities.createNewFrames(sprite, count, duration)
    -- TODO: Replace all cases of creating new frames with this.
    if not sprite then
        app.alert("Sprite could not be found.")
        return {}
    end

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
                "Do you wish to proceed?"
            },
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
        for i = 1, valCount, 1 do
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
---@param sprite table sprite
---@param count number number of layers to create
---@param blendMode number blend mode
---@param opacity number layer opacity
---@param guiClr number hexadecimal color
---@return table
function AseUtilities.createNewLayers(
    sprite,
    count,
    blendMode,
    opacity,
    guiClr)

    -- TODO: Replace cases of creating new frames with this.
    if not sprite then
        app.alert("Sprite could not be found.")
        return {}
    end

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
                "Do you wish to proceed?"
            },
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

    local oldLayerCount = #sprite.layers
    local layers = {}
    for i = 1, valCount, 1 do
        local layer = sprite:newLayer()
        layer.blendMode = valBlendMode
        layer.opacity = valOpac
        layer.name = string.format(
            "Layer %d",
            oldLayerCount + i)
        layers[i] = layer
    end

    local useGuiClr = guiClr and guiClr ~= 0x0
    if useGuiClr then
        local aseColor = Color(guiClr)
        for i = 1, valCount, 1 do
            layers[i].color = aseColor
        end
    end

    return layers
end

---Draws a glyph at its native scale to an image.
---The color is to be represented in hexadecimal
---with AABBGGR order.
---Operates on pixels. This should not be used
---with app.useTool.
---@param image table image
---@param glyph table glyph
---@param hex number hexadecimal color
---@param x number x top left corner
---@param y number y top left corner
---@param gw number glyph width
---@param gh number glyph height
function AseUtilities.drawGlyph(
    image, glyph, hex,
    x, y, gw, gh)

    -- TODO: Return xCaret position?

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

---Draws a glyph to an image at a pixel scale;
---resizes the glyph according to nearest neighbor.
---The color is to be represented in hexadecimal
---with AABBGGR order.
---Operates on pixels. This should not be used
---with app.useTool.
---@param image table image
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

    -- TODO: Return xCaret position?

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
---@param cel table cel
---@param layer table layer
---@param lnClr table line color
---@param coClr table coordinate color
---@param fhClr table fore handle color
---@param rhClr table rear handle color
function AseUtilities.drawHandles2(
    curve, cel, layer,
    lnClr, coClr, fhClr, rhClr)

    local kns = curve.knots
    local knsLen = #kns
    app.transaction(function()
        for i = 1, knsLen, 1 do
            AseUtilities.drawKnot2(
                kns[i], cel, layer,
                lnClr, coClr,
                fhClr, rhClr)
        end
    end)
end

---Draws a knot for diagnostic purposes.
---Color arguments are optional.
---@param knot table knot
---@param cel table cel
---@param layer table layer
---@param lnClr table line color
---@param coClr table coordinate color
---@param fhClr table fore handle color
---@param rhClr table rear handle color
function AseUtilities.drawKnot2(
    knot, cel, layer,
    lnClr, coClr, fhClr, rhClr)

    -- #02A7EB, #EBE128, #EB1A40
    local lnClrVal = lnClr or Color(0xffafafaf)
    local rhClrVal = rhClr or Color(0xffeba702)
    local coClrVal = coClr or Color(0xff28e1eb)
    local fhClrVal = fhClr or Color(0xff401aeb)

    local lnBrush = Brush { size = 1 }
    local rhBrush = Brush { size = 4 }
    local coBrush = Brush { size = 6 }
    local fhBrush = Brush { size = 5 }

    local coPt = AseUtilities.vec2ToPoint(knot.co)
    local fhPt = AseUtilities.vec2ToPoint(knot.fh)
    local rhPt = AseUtilities.vec2ToPoint(knot.rh)

    app.transaction(function()
        app.useTool {
            tool = "line",
            color = lnClrVal,
            brush = lnBrush,
            points = { rhPt, coPt },
            cel = cel,
            layer = layer }

        app.useTool {
            tool = "line",
            color = lnClrVal,
            brush = lnBrush,
            points = { coPt, fhPt },
            cel = cel,
            layer = layer }

        app.useTool {
            tool = "pencil",
            color = rhClrVal,
            brush = rhBrush,
            points = { rhPt },
            cel = cel,
            layer = layer }

        app.useTool {
            tool = "pencil",
            color = coClrVal,
            brush = coBrush,
            points = { coPt },
            cel = cel,
            layer = layer }

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
---@param fillClr table fill color
---@param useStroke boolean use stroke
---@param strokeClr table stroke color
---@param brsh table brush
---@param cel table cel
---@param layer table layer
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
---@param image table image
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
---@param image table image
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

---Creates an Aseprite palette from a table of
---hex color integers. Assumes the hex colors
---are belong to the same color profile as the
---sprite to which the palette will be assigned.
---If the first color in the table is not clear
---black (0x0), then one will be prepended.
---@param arr table
---@return table
function AseUtilities.hexArrToAsePalette(arr)
    local arrLen = #arr
    local palLen = arrLen
    local pal = Palette(palLen)
    for i = 1, arrLen, 1 do
        local hex = arr[i]
        local aseColor = Color(hex)
        pal:setColor(i - 1, aseColor)
    end
    return pal
end

---Initializes a sprite and layer.
---Sets palette to the colors provided,
---or, if nil, a default set. Colors should
---be hexadecimal integers.
---@param wDefault number default width
---@param hDefault number default height
---@param layerName string layer name
---@param colors table array of hexes
---@param colorSpace table color space
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

    if sprite == nil then
        local wVal = 32
        local hVal = 32
        if wDefault and wDefault > 0 then wVal = wDefault end
        if hDefault and hDefault > 0 then hVal = hDefault end

        sprite = Sprite(wVal, hVal)
        app.activeSprite = sprite

        if colorSpace
            and colorSpace ~= ColorSpace { sRGB = true } then
            sprite:assignColorSpace(colorSpace)
        end

        layer = sprite.layers[1]

        sprite:setPalette(
            AseUtilities.hexArrToAsePalette(clrsVal))
    else
        layer = sprite:newLayer()
    end

    layer.name = layerName or "Layer"
    return sprite
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

---Converts a Vec2 to an Aseprite Point.
---@param a table vector
---@return table
function AseUtilities.vec2ToPoint(a)
    local cx = 0
    if a.x < -0.0 then
        cx = math.tointeger(a.x - 0.5)
    elseif a.x > 0.0 then
        cx = math.tointeger(a.x + 0.5)
    end

    local cy = 0
    if a.y < -0.0 then
        cy = math.tointeger(a.y - 0.5)
    elseif a.y > 0.0 then
        cy = math.tointeger(a.y + 0.5)
    end

    return Point(cx, cy)
end

return AseUtilities