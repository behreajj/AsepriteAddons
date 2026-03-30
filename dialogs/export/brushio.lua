dofile("../../support/aseutilities.lua")

local imageDataModes <const> = {
    "ALPHA",
    "LIGHT",
    "SHADE",
    "STAMP",
}

local defaults <const> = {
    -- TODO: Show dynamics min and max with number inputs?
    -- TODO: Allow user to set UUID?
    imageDataMode = "STAMP",

    signature = "ASEBRUSH",
    ffVersion = 1,

    fgColorEnabled = false,
    bgColorEnabled = false,
    inkEnabled = false,
    opacityEnabled = false,
    pxPerfectEnabled = false,
    dynamicsEnabled = false,

    -- 0000 0001
    fgColorMask = 1,
    -- 0000 0010
    bgColorMask = 2,
    -- 0000 0100
    inkMask = 4,
    -- 0000 1000
    opacityMask = 8,
    -- 0001 0000
    pxPerfectMask = 16,
    -- 0010 0000
    dynamicsMask = 32,
}

---@param binStr string
---@return Brush brush
---@return integer enabledFlags
---@return integer fgAgbr32
---@return integer bgAbgr32
---@return Ink toolInk
---@return integer toolOpacity
---@return boolean usePixelPerfect
---@return {
--- useStabilizer: boolean,
--- stableFac: number,
--- dynamicSize: integer,
--- dynamicAngle: integer,
--- dynamicColor: integer,
--- minSize: integer,
--- minAngle: integer,
--- colorFromTo: integer,
--- minPressure: number,
--- maxPressure: number,
--- minVelocity: number,
--- maxVelocity: number} toolDynamics
---@nodiscard
local function readBrush(binStr)
    local strbyte <const> = string.byte
    local strsub <const> = string.sub
    local strunpack <const> = string.unpack

    local signature <const> = strsub(binStr, 1, 8)
    if signature ~= defaults.signature then
        -- print(string.format(
        --     "Signature \"%s\" does not match expected \"%s\"",
        --     signature, defaults.signature))
        return Brush { angle = 0, size = 1, type = BrushType.CIRCLE },
            0, 0, 0, Ink.SIMPLE, 255, false, {}
    end

    -- local ffVersion <const> = strunpack("B", strsub(binStr, 9, 9))
    -- print(string.format("ffVersion: %d", ffVersion))

    -- local uuidBytes <const> = {}
    -- local j = 0
    -- while j < 16 do
    --     local uuidByte <const> = string.byte(binStr, 10 + j)
    --     uuidBytes[1 + j] = uuidByte
    --     j = j + 1
    -- end

    -- local uuidHexes <const> = {}
    -- local k = 0
    -- while k < 16 do
    --     k = k + 1
    --     local uuidHex <const> = string.format("%02X", uuidBytes[k])
    --     uuidHexes[k] = uuidHex
    -- end
    -- print(string.format("UUID: %s", tconcat(uuidHexes)))

    local enabledFlags <const> = strunpack("<I2", strsub(binStr, 26, 27))
    -- print(string.format("enabledFlags: %d", enabledFlags))

    local fgAbgr32 <const> = strunpack("<I4", strsub(binStr, 28, 31))
    local bgAbgr32 <const> = strunpack("<I4", strsub(binStr, 32, 35))
    -- print(string.format("fgAbgr32: %08x", fgAbgr32))
    -- print(string.format("bgAbgr32: %08x", bgAbgr32))

    local toolInk <const> = strbyte(binStr, 36, 36)
    local toolOpacity <const> = strbyte(binStr, 37, 37)
    local usePixelPerfect <const> = strbyte(binStr, 38, 38) == 1
    -- print(string.format("toolInk: %d", toolInk))
    -- print(string.format("toolOpacity: %d", toolOpacity))
    -- print(string.format(
    --     "usePixelPerfect: %d %s",
    --     strunpack("B", strsub(binStr, 38, 38)),
    --     usePixelPerfect and "true" or "false"))

    local useStabilizer <const> = strbyte(binStr, 39, 39) ~= 0
    local stableFac <const> = strbyte(binStr, 40, 40)
    local dynamicSize <const> = strbyte(binStr, 41, 41)
    local dynamicAngle <const> = strbyte(binStr, 42, 42)
    local dynamicColor <const> = strbyte(binStr, 43, 43)
    local minSize <const> = strbyte(binStr, 44, 44)

    local minAngle <const> = strunpack("<i2", strsub(binStr, 45, 46))
    local colorFromTo <const> = strbyte(binStr, 47, 47)

    local minPressure <const> = strunpack("<d", strsub(binStr, 48, 55))
    local maxPressure <const> = strunpack("<d", strsub(binStr, 56, 63))
    local minVelocity <const> = strunpack("<d", strsub(binStr, 64, 71))
    local maxVelocity <const> = strunpack("<d", strsub(binStr, 72, 79))

    local brushType <const> = strbyte(binStr, 80, 80)
    local brushSize <const> = strbyte(binStr, 81, 81)
    local brushAngle <const> = strunpack("<i2", strsub(binStr, 82, 83))
    -- print(string.format("brushType: %d", brushType))
    -- print(string.format("brushSize: %d", brushSize))
    -- print(string.format("brushAngle: %d", brushAngle))

    local brushCenterX <const> = strunpack("<i8", strsub(binStr, 84, 91))
    local brushCenterY <const> = strunpack("<i8", strsub(binStr, 92, 99))
    local brushPattern <const> = strbyte(binStr, 100, 100)
    local brushPatternX <const> = strunpack("<i8", strsub(binStr, 101, 108))
    local brushPatternY <const> = strunpack("<i8", strsub(binStr, 109, 116))
    -- print(string.format("brushPattern: %d", brushPattern))

    local wImage <const> = strunpack("<I2", strsub(binStr, 117, 118))
    local hImage <const> = strunpack("<I2", strsub(binStr, 119, 120))
    local lenImageBytes <const> = strunpack("<I8", strsub(binStr, 121, 128))

    -- print(wImage * hImage * 4)
    -- print(lenImageBytes)
    -- print(128 + lenImageBytes)
    -- print(#binStr)

    local imageSpec <const> = AseUtilities.createSpec(wImage, hImage)
    local image = Image(imageSpec)

    local brushTypeIsImage <const> = brushType == BrushType.IMAGE
    local lenBytesIsValid <const> = (wImage * hImage * 4) == lenImageBytes
        and lenImageBytes > 0
    if brushTypeIsImage and lenBytesIsValid then
        local imageBytes <const> = strsub(binStr, 129, 128 + lenImageBytes)
        image.bytes = imageBytes
    end

    -- Providing an image to the brush constructor when the brush
    -- type is not image causes problems.
    local brush <const> = brushTypeIsImage
        and Brush {
            center = Point(brushCenterX, brushCenterY),
            image = image,
            pattern = brushPattern,
            patternOrigin = Point(brushPatternX, brushPatternY),
            type = brushType,
        }
        or Brush {
            angle = brushAngle,
            size = brushSize,
            type = brushType,
        }

    local toolDynamics <const> = {
        useStabilizer = useStabilizer,
        stableFac = stableFac,
        dynamicSize = dynamicSize,
        dynamicAngle = dynamicAngle,
        dynamicColor = dynamicColor,
        minSize = minSize,
        minAngle = minAngle,
        colorFromTo = colorFromTo,
        minPressure = minPressure,
        maxPressure = maxPressure,
        minVelocity = minVelocity,
        maxVelocity = maxVelocity,
    }

    return brush, enabledFlags,
        fgAbgr32, bgAbgr32,
        toolInk, toolOpacity, usePixelPerfect,
        toolDynamics
end

local dlg <const> = Dialog { title = "Brush IO" }

dlg:separator { id = "importSep", text = "Load" }

dlg:file {
    id = "importFilepath",
    label = "Path:",
    filetypes = { "brush" },
    basepath = AseUtilities.defaultFolder(),
    filename = "*.brush",
    title = "Import Brush",
    focus = false
}

-- dlg:newrow { always = false }

-- dlg:canvas {
--     id = "previewCanvas",
--     label = "Preview:",
--     width = 128,
--     height = 128,
--     focus = false,
--     onpaint = function(event)
--         local ctx <const> = event.context
--     end
-- }

dlg:newrow { always = false }

dlg:button {
    id = "importButton",
    text = "&LOAD",
    focus = false,
    onclick = function()
        local args <const> = dlg.data

        local filepath <const> = args.importFilepath --[[@as string]]
        if (not filepath) or (#filepath < 1) then
            app.alert {
                title = "Error",
                text = "Filepath is empty."
            }
            return
        end

        local fileExt <const> = app.fs.fileExtension(filepath)
        if string.lower(fileExt) ~= "brush" then
            app.alert {
                title = "Error",
                text = "Extension is not \"brush\"."
            }
            return
        end

        local binFile <const>, err <const> = io.open(filepath, "rb")
        if err ~= nil then
            if binFile then binFile:close() end
            app.alert { title = "Error", text = err }
            return
        end
        if binFile == nil then return end

        local brushBytes <const> = binFile:read("a")
        binFile:close()

        local brush <const>,
        enabledFlags <const>,
        fgAbgr32 <const>,
        bgAbgr32 <const>,
        toolInk <const>,
        toolOpacity <const>,
        usePixelPerfect <const>,
        toolDynamics <const> = readBrush(brushBytes)

        if brush.type == BrushType.IMAGE
            and brush.image:isEmpty() then
            app.alert {
                text = "Error",
                title = "Brush image is empty."
            }
            return
        end

        -- if app.site.tilemapMode == TilemapMode.TILES then
        --     app.command.ToggleTilesMode()
        -- end

        -- This cannot be entirely replaced with AseUtilities.setBrush
        -- because this uses enabledFlags and sets brush dynamics, does
        -- not set the tool to pencil, etc.
        local appPrefs <const> = app.preferences
        if appPrefs then
            -- As with tool brush properties below, global brush properties
            -- also need to be set from the brush.
            local globalBrushPrefs <const> = appPrefs.brush
            if globalBrushPrefs then
                if globalBrushPrefs.pattern
                    and brush.type == BrushType.IMAGE then
                    globalBrushPrefs.pattern = brush.pattern
                end
            end -- End global brush prefs exists.

            local tool <const> = app.tool
            local toolPrefs <const> = appPrefs.tool(tool)
            if toolPrefs then
                -- Brush properties also need to be assigned to preferences
                -- for the UI to update in the context bar.
                local toolBrushPrefs <const> = toolPrefs.brush
                if toolBrushPrefs then
                    local brushType <const> = brush.type
                    local brushSize <const> = brush.size
                    local isNotImage <const> = brushType ~= BrushType.IMAGE

                    if toolBrushPrefs.type and isNotImage then
                        toolBrushPrefs.type = brushType
                    end

                    if toolBrushPrefs.size and isNotImage then
                        toolBrushPrefs.size = brushSize
                    end

                    if toolBrushPrefs.angle and isNotImage
                        and brushType ~= BrushType.CIRCLE
                        and brushSize > 1 then
                        toolBrushPrefs.angle = brush.angle
                    end
                end -- End tool brush prefs exists.

                if toolPrefs.ink
                    and (enabledFlags & defaults.inkMask ~= 0) then
                    toolPrefs.ink = toolInk
                end

                if toolPrefs.opacity
                    and (enabledFlags & defaults.opacityMask ~= 0) then
                    toolPrefs.opacity = toolOpacity
                end

                if toolPrefs.freehand_algorithm
                    and (enabledFlags & defaults.pxPerfectMask ~= 0) then
                    toolPrefs.freehand_algorithm = usePixelPerfect
                        and 1
                        or 0
                end

                local dynamicsPrefs <const> = toolPrefs.dynamics
                if dynamicsPrefs
                    and (enabledFlags & defaults.dynamicsMask ~= 0) then
                    if dynamicsPrefs.stabilizer ~= nil then
                        dynamicsPrefs.stabilizer = toolDynamics.useStabilizer
                    end

                    if dynamicsPrefs.stabilizer_factor then
                        dynamicsPrefs.stabilizer_factor = toolDynamics.stableFac
                    end

                    if dynamicsPrefs.size then
                        dynamicsPrefs.size = toolDynamics.dynamicSize
                    end

                    if dynamicsPrefs.angle then
                        dynamicsPrefs.angle = toolDynamics.dynamicAngle
                    end

                    if dynamicsPrefs.gradient then
                        dynamicsPrefs.gradient = toolDynamics.dynamicColor
                    end

                    if dynamicsPrefs.min_size then
                        dynamicsPrefs.min_size = toolDynamics.minSize
                    end

                    if dynamicsPrefs.min_angle then
                        dynamicsPrefs.min_angle = toolDynamics.minAngle
                    end

                    if dynamicsPrefs.color_from_to then
                        dynamicsPrefs.color_from_to = toolDynamics.colorFromTo
                    end

                    -- dynamicsPrefs.matrix_name is skipped.

                    if dynamicsPrefs.min_pressure_threshold then
                        dynamicsPrefs.min_pressure_threshold = toolDynamics.minPressure
                    end

                    if dynamicsPrefs.max_pressure_threshold then
                        dynamicsPrefs.max_pressure_threshold = toolDynamics.maxPressure
                    end

                    if dynamicsPrefs.min_velocity_threshold then
                        dynamicsPrefs.min_velocity_threshold = toolDynamics.minVelocity
                    end

                    if dynamicsPrefs.max_velocity_threshold then
                        dynamicsPrefs.max_velocity_threshold = toolDynamics.maxVelocity
                    end
                end -- End dynamics prefs exists.
            end     -- End tool prefs exists.

            local colorBarPrefs <const> = appPrefs.color_bar
            if colorBarPrefs then
                if colorBarPrefs.fg_color
                    and enabledFlags & defaults.fgColorMask ~= 0 then
                    colorBarPrefs.fg_color = AseUtilities.hexToAseColor(fgAbgr32)
                end

                if colorBarPrefs.bg_color
                    and enabledFlags & defaults.bgColorMask ~= 0 then
                    colorBarPrefs.bg_color = AseUtilities.hexToAseColor(bgAbgr32)
                end
            end -- End color bar prefs exists.
        end     -- End app prefs exists.

        -- -- Alternate way to set fore and back color:
        -- if enabledFlags & defaults.fgColorMask ~= 0 then
        -- app.fgColor = AseUtilities.hexToAseColor(fgAbgr32)
        -- end

        -- if enabledFlags & defaults.bgColorMask ~= 0 then
        -- app.command.SwitchColors()
        -- app.fgColor = AseUtilities.hexToAseColor(bgAbgr32)
        -- app.command.SwitchColors()
        -- end

        app.brush = brush
        app.refresh()
    end
}

dlg:separator { id = "exportSep", text = "Save" }

dlg:combobox {
    id = "imageDataMode",
    label = "Data:",
    option = defaults.imageDataMode,
    options = imageDataModes,
    hexpand = false,
    onchange = function()
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "fgColorEnabled",
    label = "Color:",
    text = "Fore",
    selected = defaults.fgColorEnabled,
    hexpand = false,
}

dlg:check {
    id = "bgColorEnabled",
    text = "Back",
    selected = defaults.fgColorEnabled,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:check {
    id = "inkEnabled",
    label = "Tool:",
    text = "Ink",
    selected = defaults.inkEnabled,
    hexpand = false,
}

dlg:check {
    id = "opacityEnabled",
    text = "Opacity",
    selected = defaults.opacityEnabled,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:check {
    id = "dynamicsEnabled",
    text = "Dynamics",
    selected = defaults.dynamicsEnabled,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:check {
    id = "pxPerfectEnabled",
    text = "Pixel Perfect",
    selected = defaults.pxPerfectEnabled,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:file {
    id = "exportFilepath",
    label = "Path:",
    filetypes = { "brush" },
    basepath = AseUtilities.defaultFolder(),
    filename = "*.brush",
    title = "Export Brush",
    save = true,
    focus = true
}

dlg:newrow { always = false }

dlg:button {
    id = "exportButton",
    text = "&SAVE",
    focus = false,
    onclick = function()
        local args <const> = dlg.data

        -- Handle early returns.
        local filepath <const> = args.exportFilepath --[[@as string]]
        if (not filepath) or (#filepath < 1) then
            app.alert {
                title = "Error",
                text = "Filepath is empty."
            }
            return
        end

        local fileExt <const> = app.fs.fileExtension(filepath)
        if string.lower(fileExt) ~= "brush" then
            app.alert {
                title = "Error",
                text = "Extension is not \"brush\"."
            }
            return
        end

        -- Cache commonly used functions.
        local floor <const> = math.floor
        local max <const> = math.max
        local min <const> = math.min
        local strbyte <const> = string.byte
        local strchar <const> = string.char
        local strpack <const> = string.pack
        local tconcat <const> = table.concat

        -- Create a unique identifier for brush and write it
        -- to a string array.
        local uuid <const> = Uuid()
        ---@type string[]
        local uuidStrArr <const> = {}
        local j = 0
        while j < 16 do
            j = j + 1
            uuidStrArr[j] = strchar(uuid[j])
        end
        local uuidStr <const> = tconcat(uuidStrArr)
        -- print("UUID: " .. tostring(uuid))

        -- Unpack arguments.
        local imageDataMode <const> = args.imageDataMode
            or defaults.imageDataMode --[[@as string]]
        local fgColorEnabled <const> = args.fgColorEnabled --[[@as boolean]]
        local bgColorEnabled <const> = args.bgColorEnabled --[[@as boolean]]
        local inkEnabled <const> = args.inkEnabled --[[@as boolean]]
        local opacityEnabled <const> = args.opacityEnabled --[[@as boolean]]
        local pxPerfectEnabled <const> = args.pxPerfectEnabled --[[@as boolean]]
        local dynamicsEnabled <const> = args.dynamicsEnabled --[[@as boolean]]

        -- Concatenate booleans into a single 16 bit integer.
        local enabledFlags = 0
        if fgColorEnabled then
            enabledFlags = enabledFlags | defaults.fgColorMask
        end
        if bgColorEnabled then
            enabledFlags = enabledFlags | defaults.bgColorMask
        end
        if inkEnabled then
            enabledFlags = enabledFlags | defaults.inkMask
        end
        if opacityEnabled then
            enabledFlags = enabledFlags | defaults.opacityMask
        end
        if pxPerfectEnabled then
            enabledFlags = enabledFlags | defaults.pxPerfectMask
        end
        if dynamicsEnabled then
            enabledFlags = enabledFlags | defaults.dynamicsMask
        end

        local enabledFlagsStr <const> = strpack("<I2", enabledFlags)

        -- Write brush properties.
        local brush <const> = app.brush
        local brushType <const> = brush.type
        local brushSize <const> = min(max(brush.size, 0), 255)
        local brushAngle <const> = min(max(brush.angle, -32768), 32767)
        -- print(string.format("brushType: %d", brushType))
        -- print(string.format("brushSize: %d", brushSize))
        -- print(string.format("brushAngle: %d", brushAngle))

        local brushCenter <const> = brush.center
        local brushPattern <const> = brush.pattern
        local brushPatternOrigin <const> = brush.patternOrigin
        local brushImage <const> = brush.image

        local brushTypeStr <const> = strchar(brushType)
        local brushSizeStr <const> = strchar(brushSize)
        local brushAngleStr <const> = strpack("<i2", brushAngle)
        local brushCenterXStr <const> = strpack("<i8", brushCenter.x)
        local brushCenterYStr <const> = strpack("<i8", brushCenter.y)
        local brushPatternStr <const> = strchar(brushPattern)
        local brushPatternXStr <const> = strpack("<i8", brushPatternOrigin.x)
        local brushPatternYStr <const> = strpack("<i8", brushPatternOrigin.y)

        local brushImageStr = ""
        local wImage = 0
        local hImage = 0
        if brushType == BrushType.IMAGE
            and brushImage ~= nil then
            if brushImage:isEmpty() then
                app.alert {
                    text = "Error",
                    title = "Brush image is empty."
                }
                return
            end

            local imageSpec <const> = brushImage.spec
            wImage = min(max(imageSpec.width, 0), 65535)
            hImage = min(max(imageSpec.height, 0), 65535)
            local imageColorMode <const> = imageSpec.colorMode

            if imageColorMode == ColorMode.RGB then
                brushImageStr = brushImage.bytes
            elseif imageColorMode == ColorMode.GRAY then
                ---@type string[]
                local rgbArr <const> = {}
                local grayBytes <const> = brushImage.bytes
                local areaImage <const> = wImage * hImage

                local i = 0
                while i < areaImage do
                    local i2 <const> = i + i
                    local a8 <const> = strbyte(grayBytes, 2 + i2)
                    local r8, g8, b8 = 0, 0, 0
                    if a8 > 0 then
                        local v8 <const> = strbyte(grayBytes, 1 + i2)
                        r8, g8, b8 = v8, v8, v8
                    end

                    local i4 <const> = i2 + i2
                    rgbArr[1 + i4] = strchar(r8)
                    rgbArr[2 + i4] = strchar(g8)
                    rgbArr[3 + i4] = strchar(b8)
                    rgbArr[4 + i4] = strchar(a8)

                    i = i + 1
                end

                brushImageStr = tconcat(rgbArr)
            elseif imageColorMode == ColorMode.INDEXED then
                ---@type string[]
                local rgbArr <const> = {}
                local idxBytes <const> = brushImage.bytes
                local areaImage <const> = wImage * hImage

                local site <const> = app.site
                local sprite <const> = site.sprite
                local palettes <const> = sprite and sprite.palettes or {}
                local frIdx <const> = site.frame and site.frame.frameNumber or 1
                local palette <const> = AseUtilities.getPalette(frIdx, palettes)
                local lenPalette <const> = #palette
                local imageAlphaIndex <const> = imageSpec.transparentColor
                local hasBkg <const> = sprite and sprite.backgroundLayer

                local i = 0
                while i < areaImage do
                    local idxByte <const> = strbyte(idxBytes, 1 + i)
                    local r8, g8, b8, a8 = 0, 0, 0, 0
                    if idxByte < lenPalette
                        and (hasBkg
                            or idxByte ~= imageAlphaIndex) then
                        local aseColor <const> = palette:getColor(idxByte)
                        a8 = aseColor.alpha
                        if a8 > 0 then
                            r8 = aseColor.red
                            g8 = aseColor.green
                            b8 = aseColor.blue
                        end
                    end

                    local i4 <const> = i * 4
                    rgbArr[1 + i4] = strchar(r8)
                    rgbArr[2 + i4] = strchar(g8)
                    rgbArr[3 + i4] = strchar(b8)
                    rgbArr[4 + i4] = strchar(a8)

                    i = i + 1
                end

                brushImageStr = tconcat(rgbArr)
            else
                app.alert {
                    title = "Error",
                    text = { "Unexpected brush image color mode." }
                }
                return
            end
        end

        local lenBrushImage <const> = #brushImageStr
        local lenBrushImageStr <const> = strpack("<I8", lenBrushImage)
        local wImageStr <const> = strpack("<I2", wImage)
        local hImageStr <const> = strpack("<I2", hImage)

        -- Foreground and background colors must be written
        -- after the image data! Otherwise Aseprite will fill
        -- the brush with the foreground color.
        local fgColor = Color { r = 0, g = 0, b = 0, a = 0 }
        local bgColor = Color { r = 0, g = 0, b = 0, a = 0 }

        -- Write tool properties.
        local toolInk = Ink.SIMPLE
        local toolOpacity = 255
        local usePixelPerfect = false

        -- Dynamics properties within tool.
        local useStabilizer = false
        -- In the range 0 to 64.
        local stableFac = 0
        -- DynamicSensor:
        -- 0 Static
        -- 1 Pressure
        -- 2 Velocity
        local dynamicSize = 0
        local dynamicAngle = 0
        local dynamicColor = 0
        -- For both size and angle, the max is the tool's
        -- size and angle, outside of dynamics.
        local minSize = 1
        local minAngle = 0
        -- ColorFromTo:
        -- 0 BgToFg
        -- 1 FgToBg
        local colorFromTo = 0
        local minPressure = 0.1
        local maxPressure = 0.9
        local minVelocity = 0.1
        local maxVelocity = 0.9

        local appPrefs <const> = app.preferences
        if appPrefs then
            local tool <const> = app.tool
            local toolPrefs <const> = appPrefs.tool(tool)
            if toolPrefs then
                if toolPrefs.ink then
                    toolInk = toolPrefs.ink --[[@as Ink]]
                end

                if toolPrefs.opacity then
                    toolOpacity = toolPrefs.opacity --[[@as integer]]
                end

                if toolPrefs.freehand_algorithm then
                    usePixelPerfect = toolPrefs.freehand_algorithm == 1
                end

                local dynamicsPrefs <const> = toolPrefs.dynamics
                if dynamicsPrefs then
                    if dynamicsPrefs.stabilizer then
                        useStabilizer = dynamicsPrefs.stabilizer --[[@as boolean]]
                    end

                    if dynamicsPrefs.stabilizer_factor then
                        stableFac = dynamicsPrefs.stabilizer_factor --[[@as integer]]
                    end

                    if dynamicsPrefs.size then
                        dynamicSize = dynamicsPrefs.size --[[@as integer]]
                    end

                    if dynamicsPrefs.angle then
                        dynamicAngle = dynamicsPrefs.angle --[[@as integer]]
                    end

                    if dynamicsPrefs.gradient then
                        dynamicColor = dynamicsPrefs.gradient --[[@as integer]]
                    end

                    if dynamicsPrefs.min_size then
                        minSize = dynamicsPrefs.min_size --[[@as integer]]
                    end

                    if dynamicsPrefs.min_angle then
                        minAngle = dynamicsPrefs.min_angle --[[@as integer]]
                    end

                    if dynamicsPrefs.color_from_to then
                        colorFromTo = dynamicsPrefs.color_from_to --[[@as integer]]
                    end

                    -- dynamicsPrefs.matrix_name is skipped.

                    if dynamicsPrefs.min_pressure_threshold then
                        minPressure = dynamicsPrefs.min_pressure_threshold --[[@as number]]
                    end

                    if dynamicsPrefs.max_pressure_threshold then
                        maxPressure = dynamicsPrefs.max_pressure_threshold --[[@as number]]
                    end

                    if dynamicsPrefs.min_velocity_threshold then
                        minVelocity = dynamicsPrefs.min_velocity_threshold --[[@as number]]
                    end

                    if dynamicsPrefs.max_velocity_threshold then
                        maxVelocity = dynamicsPrefs.max_velocity_threshold --[[@as number]]
                    end
                end -- Dynamics prefs exists.
            end     -- Tool prefs exists.

            local colorBarPrefs <const> = appPrefs.color_bar
            if colorBarPrefs then
                local fgColorPrefs <const> = colorBarPrefs.fg_color --[[@as Color]]
                if fgColorPrefs then
                    fgColor = AseUtilities.aseColorCopy(fgColorPrefs, "")
                end

                local bgColorPrefs <const> = colorBarPrefs.bg_color --[[@as Color]]
                if bgColorPrefs then
                    bgColor = AseUtilities.aseColorCopy(bgColorPrefs, "")
                end
            end -- Color bar prefs exists.
        end     -- App prefs exists.

        -- local fgColor <const> = AseUtilities.aseColorCopy(app.fgColor, "UNBOUNDED")
        -- app.command.SwitchColors()
        -- local bgColor <const> = AseUtilities.aseColorCopy(app.fgColor, "UNBOUNDED")
        -- app.command.SwitchColors()

        local toolInkStr <const> = strchar(toolInk)
        local toolOpacityStr <const> = strchar(min(max(toolOpacity, 0), 255))
        local usePixelPerfectStr <const> = strchar(usePixelPerfect and 1 or 0)
        local useStabilizerStr <const> = strchar(useStabilizer and 1 or 0)
        local stableFacStr <const> = strchar(stableFac)
        local dynamicSizeStr <const> = strchar(dynamicSize)
        local dynamicAngleStr <const> = strchar(dynamicAngle)
        local dynamicColorStr <const> = strchar(dynamicColor)
        local minSizeStr <const> = strchar(minSize)
        local minAngleStr <const> = strpack("<i2", minAngle)
        local colorFromToStr <const> = strchar(colorFromTo)
        local minPressureStr <const> = strpack("<d", minPressure)
        local maxPressureStr <const> = strpack("<d", maxPressure)
        local minVelocityStr <const> = strpack("<d", minVelocity)
        local maxVelocityStr <const> = strpack("<d", maxVelocity)

        -- These do not need to be validated for min and max because
        -- aseColorCopy above has already done so.
        local r8Fore <const> = fgColor.red
        local g8Fore <const> = fgColor.green
        local b8Fore <const> = fgColor.blue
        local a8Fore <const> = fgColor.alpha

        local r8Back <const> = bgColor.red
        local g8Back <const> = bgColor.green
        local b8Back <const> = bgColor.blue
        local a8Back <const> = bgColor.alpha

        local fgStr <const> = strpack(
            "B B B B",
            r8Fore, g8Fore, b8Fore, a8Fore)
        local bgStr <const> = strpack(
            "B B B B",
            r8Back, g8Back, b8Back, a8Back)

        -- Redo image data if mode requires it.
        local charZero <const> = strchar(0)
        local char255 <const> = strchar(255)
        local foreIsValid <const> = a8Fore > 0
        local charDefault <const> = imageDataMode == "SHADE"
            and charZero
            or char255
        local r8Char <const> = foreIsValid and strchar(r8Fore) or charDefault
        local g8Char <const> = foreIsValid and strchar(g8Fore) or charDefault
        local b8Char <const> = foreIsValid and strchar(b8Fore) or charDefault

        if imageDataMode == "ALPHA" then
            ---@type string[]
            local alphaStrs <const> = {}
            local areaImage <const> = wImage * hImage
            local i = 0
            while i < areaImage do
                local i4 <const> = i * 4

                alphaStrs[1 + i4] = charZero
                alphaStrs[2 + i4] = charZero
                alphaStrs[3 + i4] = charZero
                alphaStrs[4 + i4] = charZero

                local a8 <const> = strbyte(brushImageStr, 4 + i4)
                if a8 > 0 then
                    alphaStrs[1 + i4] = r8Char
                    alphaStrs[2 + i4] = g8Char
                    alphaStrs[3 + i4] = b8Char
                    alphaStrs[4 + i4] = strchar(a8)
                end

                i = i + 1
            end -- End pixels loop.

            brushImageStr = tconcat(alphaStrs)
        elseif imageDataMode == "LIGHT"
            or imageDataMode == "SHADE" then
            local rgbnew <const> = Rgb.new
            local sRgbToLab <const> = ColorUtilities.sRgbToSrLab2Internal

            ---@type number[]
            local factors <const> = {}
            local facMin = 2147483647
            local facMax = -2147483648
            local isShade <const> = imageDataMode == "SHADE"

            local areaImage <const> = wImage * hImage
            local h = 0
            while h < areaImage do
                local h4 <const> = h * 4
                local a8 <const> = strbyte(brushImageStr, 4 + h4)
                local fac = 0.0
                if a8 > 0 then
                    local r8 <const> = strbyte(brushImageStr, 1 + h4)
                    local g8 <const> = strbyte(brushImageStr, 2 + h4)
                    local b8 <const> = strbyte(brushImageStr, 3 + h4)

                    local srgb <const> = rgbnew(
                        r8 / 255.0,
                        g8 / 255.0,
                        b8 / 255.0,
                        a8 / 255.0)
                    local lab <const> = sRgbToLab(srgb)
                    fac = isShade and 1.0 - lab.l * 0.01 or lab.l * 0.01

                    if fac < facMin then facMin = fac end
                    if fac > facMax then facMax = fac end
                end

                factors[1 + h] = fac
                h = h + 1
            end -- End factors loop.

            ---@type string[]
            local lightStrs <const> = {}
            local diff <const> = facMax - facMin
            local diffIsValid <const> = diff ~= 0.0
            if not diffIsValid then
                app.alert {
                    title = "Error",
                    text = {
                        "Brush image does not have enough contrast",
                        "for this image data mode."
                    }
                }
                return
            end
            local scalar <const> = diffIsValid and 1.0 / diff or 0.0

            local i = 0
            while i < areaImage do
                local i4 <const> = i * 4

                lightStrs[1 + i4] = charZero
                lightStrs[2 + i4] = charZero
                lightStrs[3 + i4] = charZero
                lightStrs[4 + i4] = charZero

                local a8 <const> = strbyte(brushImageStr, 4 + i4)
                if a8 > 0 then
                    local fac <const> = diffIsValid
                        and (factors[1 + i] - facMin) * scalar
                        or 1.0
                    if fac > 0.0 then
                        local f8 <const> = floor(fac * 255 + 0.5)
                        local aComp <const> = (a8 * f8) // 255

                        lightStrs[1 + i4] = r8Char
                        lightStrs[2 + i4] = g8Char
                        lightStrs[3 + i4] = b8Char
                        lightStrs[4 + i4] = strchar(aComp)
                        -- lightStrs[4 + i4] = strchar(f8)
                    end
                end

                i = i + 1
            end -- End pixels loop.

            brushImageStr = tconcat(lightStrs)
        end

        -- Do the final write.
        local binStr <const> = table.concat({
            defaults.signature,          -- 08 bytes, 000 offset
            strchar(defaults.ffVersion), -- 01 bytes, 008 offset
            uuidStr,                     -- 16 bytes, 009 offset
            enabledFlagsStr,             -- 02 bytes, 025 offset
            fgStr,                       -- 04 bytes, 027 offset
            bgStr,                       -- 04 bytes, 031 offset
            toolInkStr,                  -- 01 bytes, 035 offset
            toolOpacityStr,              -- 01 bytes, 036 offset
            usePixelPerfectStr,          -- 01 bytes, 037 offset
            useStabilizerStr,            -- 01 bytes, 038 offset
            stableFacStr,                -- 01 bytes, 039 offset
            dynamicSizeStr,              -- 01 bytes, 040 offset
            dynamicAngleStr,             -- 01 bytes, 041 offset
            dynamicColorStr,             -- 01 bytes, 042 offset
            minSizeStr,                  -- 01 bytes, 043 offset
            minAngleStr,                 -- 02 bytes, 044 offset
            colorFromToStr,              -- 01 bytes, 046 offset
            minPressureStr,              -- 08 bytes, 047 offset
            maxPressureStr,              -- 08 bytes, 055 offset
            minVelocityStr,              -- 08 bytes, 063 offset
            maxVelocityStr,              -- 08 bytes, 071 offset
            brushTypeStr,                -- 01 bytes, 079 offset
            brushSizeStr,                -- 01 bytes, 080 offset
            brushAngleStr,               -- 02 bytes, 081 offset
            brushCenterXStr,             -- 08 bytes, 083 offset
            brushCenterYStr,             -- 08 bytes, 091 offset
            brushPatternStr,             -- 01 bytes, 099 offset
            brushPatternXStr,            -- 08 bytes, 100 offset
            brushPatternYStr,            -- 08 bytes, 108 offset
            wImageStr,                   -- 02 bytes, 116 offset
            hImageStr,                   -- 02 bytes, 118 offset
            lenBrushImageStr,            -- 08 bytes, 120 offset
            brushImageStr,               -- variable, 128 offset
        })

        local binFile <const>, err <const> = io.open(filepath, "wb")
        if err ~= nil then
            if binFile then binFile:close() end
            app.alert { title = "Error", text = err }
            return
        end
        if binFile == nil then return end

        local _ <const>,
        writeErr <const> = binFile:write(binStr)
        binFile:close()

        -- Switching the color above will trigger Aseprite to
        -- reset the brush's image data to a color.
        if brushType == BrushType.IMAGE
            and brushImage ~= nil
            and brushImage.colorMode == ColorMode.RGB then
            local resetImage <const> = Image(brushImage.spec)
            -- TODO: This only works for RGB color mode brush images.
            -- To support indexed and gray, you'd need to re-convert.
            resetImage.bytes = brushImageStr
            app.brush = Brush {
                center = brushCenter,
                image = resetImage,
                pattern = brushPattern,
                patternOrigin = brushPatternOrigin,
                type = BrushType.IMAGE,
            }
        end

        if not writeErr then
            app.alert { title = "Success", text = "File exported." }
        end
    end
}

dlg:separator { id = "cancelSep" }

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show {
    autoscrollbars = true,
    wait = false
}