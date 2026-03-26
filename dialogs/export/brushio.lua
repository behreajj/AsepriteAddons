dofile("../../support/aseutilities.lua")

local defaults <const> = {
    -- For brush dynamics, see
    -- https://github.com/aseprite/aseprite/blob/main/src/app/tools/dynamics.h

    signature = "ASEBRUSH",
    fgColorEnabled = false,
    bgColorEnabled = false,
    inkEnabled = false,
    opacityEnabled = false,
    pxPerfectEnabled = false,

    -- 0000 0001
    fgColorMask = 1,
    -- 0000 0010
    bgColorMask = 2,
    -- 0000 0100
    inkMask = 4,
    -- 0000 1000
    opacityMask = 8,
    -- 0001 0000
    pxPerfectMask = 16
}

---@param binStr string
---@return Brush brush
---@return integer enabledFlags
---@return integer fgAgbr32
---@return integer bgAbgr32
---@return Ink toolInk
---@return integer toolOpacity
---@return boolean usePixelPerfect
local function readBrush(binStr)
    local strfmt <const> = string.format
    local strbyte <const> = string.byte
    local strsub <const> = string.sub
    local strunpack <const> = string.unpack
    local tconcat <const> = table.concat

    local signature <const> = strsub(binStr, 1, 8)
    if signature ~= defaults.signature then
        -- app.alert {
        --     title = "Error",
        --     text = string.format(
        --         "Signature \"%s\" does not match expected \"%s\"",
        --         signature, defaults.signature)
        -- }
        return Brush { angle = 0, size = 1, type = BrushType.CIRCLE },
            0, 0, 0, Ink.SIMPLE, 255, false
    end

    -- local uuidBytes <const> = {}
    -- local j = 0
    -- while j < 16 do
    --     local uuidByte <const> = strbyte(binStr, 9 + j)
    --     uuidBytes[1 + j] = uuidByte
    --     j = j + 1
    -- end

    -- local uuidHexes <const> = {}
    -- local k = 0
    -- while k < 16 do
    --     k = k + 1
    --     local uuidHex <const> = strfmt("%02X", uuidBytes[k])
    --     uuidHexes[k] = uuidHex
    -- end

    -- print(string.format("UUID: %s", tconcat(uuidHexes)))

    local enabledFlags <const> = strunpack("<I2", strsub(binStr, 25, 26))

    local fgAbgr32 <const> = strunpack("<I4", strsub(binStr, 27, 30))
    local bgAbgr32 <const> = strunpack("<I4", strsub(binStr, 31, 34))

    local toolInk <const> = strunpack("B", strsub(binStr, 35, 35))
    local toolOpacity <const> = strunpack("B", strsub(binStr, 36, 36))
    local usePixelPerfect <const> = strunpack("B", strsub(binStr, 37, 37))

    local brushType <const> = strunpack("B", strsub(binStr, 38, 38))
    local brushSize <const> = strunpack("B", strsub(binStr, 39, 39))
    local brushAngle <const> = strunpack("<i2", strsub(binStr, 40, 41))
    local brushCenterX <const> = strunpack("<i8", strsub(binStr, 42, 49))
    local brushCenterY <const> = strunpack("<i8", strsub(binStr, 50, 57))
    local brushPattern <const> = strunpack("B", strsub(binStr, 58, 58))
    local brushPatternX <const> = strunpack("<i8", strsub(binStr, 59, 66))
    local brushPatternY <const> = strunpack("<i8", strsub(binStr, 67, 74))

    local wImage <const> = strunpack("<I2", strsub(binStr, 75, 76))
    local hImage <const> = strunpack("<I2", strsub(binStr, 77, 78))
    local lenImageBytes <const> = strunpack("<I8", strsub(binStr, 79, 86))

    -- print(wImage * hImage * 4)
    -- print(lenImageBytes)
    -- print(86 + lenImageBytes)
    -- print(#binStr)

    local imageSpec <const> = AseUtilities.createSpec(wImage, hImage)
    local image = Image(imageSpec)

    local brushTypeIsImage <const> = brushType == BrushType.IMAGE
    local lenBytesIsValid <const> = (wImage * hImage * 4) == lenImageBytes
        and lenImageBytes > 0
    if brushTypeIsImage and lenBytesIsValid then
        local imageBytes <const> = strsub(binStr, 87, 86 + lenImageBytes)
        image.bytes = imageBytes
    end

    -- Providing an image to the brush constructor when the brush
    -- type is not image seems to cause problems.
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

    return brush, enabledFlags,
        fgAbgr32, bgAbgr32,
        toolInk, toolOpacity, usePixelPerfect
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
        usePixelPerfect <const> = readBrush(brushBytes)

        local tool <const> = app.tool
        local toolPrefs <const> = app.preferences.tool(tool)
        if toolPrefs then
            if toolPrefs.ink then
                if enabledFlags & defaults.inkMask ~= 0 then
                    toolPrefs.ink = toolInk
                end
            end

            if toolPrefs.opacity then
                if enabledFlags & defaults.opacityMask ~= 0 then
                    toolPrefs.opacity = toolOpacity
                end
            end

            if toolPrefs.freehand_algorithm then
                if enabledFlags & defaults.pxPerfectMask ~= 0 then
                    toolPrefs.freehand_algorithm = usePixelPerfect
                        and 1
                        or 0
                end
            end
        end

        if enabledFlags & defaults.fgColorMask ~= 0 then
            app.fgColor = AseUtilities.hexToAseColor(fgAbgr32)
        end

        if enabledFlags & defaults.bgColorMask ~= 0 then
            app.command.SwitchColors()
            app.fgColor = AseUtilities.hexToAseColor(bgAbgr32)
            app.command.SwitchColors()
        end

        app.brush = brush
        app.refresh()
    end
}

dlg:separator { id = "exportSep", text = "Save" }

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
    -- TODO: Redo all file widgets where save is true
    -- to include filename field for better compatibility
    -- with macs?
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

        local binFile <const>, err <const> = io.open(filepath, "wb")
        if err ~= nil then
            if binFile then binFile:close() end
            app.alert { title = "Error", text = err }
            return
        end
        if binFile == nil then return end

        -- Cache commonly used functions.
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
        -- print(tostring(uuid))

        -- Unpack arguments.
        local fgColorEnabled <const> = args.fgColorEnabled --[[@as boolean]]
        local bgColorEnabled <const> = args.bgColorEnabled --[[@as boolean]]
        local inkEnabled <const> = args.inkEnabled --[[@as boolean]]
        local opacityEnabled <const> = args.opacityEnabled --[[@as boolean]]
        local pxPerfectEnabled <const> = args.pxPerfectEnabled --[[@as boolean]]

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

        local enabledFlagsStr <const> = strpack("<I2", enabledFlags)

        -- Write brush properties.
        local brush <const> = app.brush
        local brushType <const> = brush.type
        local brushSize <const> = min(max(brush.size, 0), 255)
        local brushAngle <const> = min(max(brush.angle, -32768), 32767)
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
            local imageSpec <const> = brushImage.spec
            wImage = min(max(imageSpec.width, 0), 65535)
            hImage = min(max(imageSpec.height, 0), 65535)
            local imageColorMode <const> = imageSpec.colorMode

            if imageColorMode == ColorMode.RGB then
                brushImageStr = brushImage.bytes
            elseif imageColorMode == ColorMode.GRAY then
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
                binFile:close()
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

        -- Write tool properties.
        local toolInk = Ink.SIMPLE
        local toolOpacity = 255
        local usePixelPerfect = false

        local tool <const> = app.tool
        local toolPrefs <const> = app.preferences.tool(tool)
        if toolPrefs then
            if toolPrefs.ink then
                toolInk = toolPrefs.ink
            end

            if toolPrefs.opacity then
                toolOpacity = toolPrefs.opacity
            end

            if toolPrefs.freehand_algorithm then
                usePixelPerfect = toolPrefs.freehand_algorithm == 1
            end
        end

        local toolInkStr <const> = strchar(toolInk)
        local toolOpacityStr <const> = strchar(min(max(toolOpacity, 0), 255))
        local usePixelPerfectStr <const> = strchar(usePixelPerfect and 1 or 0)

        -- Foreground and background colors must be written
        -- after the image data! Otherwise Aseprite will fill
        -- the brush with the foreground color.
        local fgColor <const> = AseUtilities.aseColorCopy(app.fgColor, "UNBOUNDED")
        app.command.SwitchColors()
        local bgColor <const> = AseUtilities.aseColorCopy(app.fgColor, "UNBOUNDED")
        app.command.SwitchColors()

        local fgStr <const> = strpack(
            "B B B B",
            min(max(fgColor.red, 0), 255),
            min(max(fgColor.green, 0), 255),
            min(max(fgColor.blue, 0), 255),
            min(max(fgColor.alpha, 0), 255))
        local bgStr <const> = strpack(
            "B B B B",
            min(max(bgColor.red, 0), 255),
            min(max(bgColor.green, 0), 255),
            min(max(bgColor.blue, 0), 255),
            min(max(bgColor.alpha, 0), 255))

        -- Do the final write.
        local binStr <const> = table.concat({
            defaults.signature, -- 08 bytes, 000 offset
            uuidStr,            -- 16 bytes, 008 offset
            enabledFlagsStr,    -- 02 bytes, 024 offset

            fgStr,              -- 04 bytes, 026 offset
            bgStr,              -- 04 bytes, 030 offset

            toolInkStr,         -- 01 bytes, 034 offset
            toolOpacityStr,     -- 01 bytes, 035 offset
            usePixelPerfectStr, -- 01 bytes, 036 offset

            brushTypeStr,       -- 01 bytes, 037 offset
            brushSizeStr,       -- 01 bytes, 038 offset
            brushAngleStr,      -- 02 bytes, 039 offset
            brushCenterXStr,    -- 08 bytes, 041 offset
            brushCenterYStr,    -- 08 bytes, 049 offset
            brushPatternStr,    -- 01 bytes, 057 offset
            brushPatternXStr,   -- 08 bytes, 058 offset
            brushPatternYStr,   -- 08 bytes, 066 offset

            wImageStr,          -- 02 bytes, 074 offset
            hImageStr,          -- 02 bytes, 076 offset
            lenBrushImageStr,   -- 08 bytes, 078 offset
            brushImageStr,      -- variable, 086 offset
        })
        binFile:write(binStr)
        binFile:close()
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