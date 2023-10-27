dofile("../../support/aseutilities.lua")

local frameTargetOptions <const> = { "ACTIVE", "ALL", "MANUAL", "RANGE" }

local defaults <const> = {
    -- https://github.com/aseprite/aseprite/issues/2834
    -- https://www.wikiwand.com/en/Netpbm#PPM_example
    frameTarget = "ACTIVE",
    rangeStr = "",
    strExample = "4,6:9,13",
    scale = 1,
    usePixelAspect = true
}

local dlg <const> = Dialog { title = "Export Netpbm" }

dlg:combobox {
    id = "frameTarget",
    label = "Frames:",
    option = defaults.frameTarget,
    options = frameTargetOptions,
    onchange = function()
        local args <const> = dlg.data
        local state <const> = args.frameTarget --[[@as string]]
        local isManual <const> = state == "MANUAL"

        dlg:modify { id = "rangeStr", visible = isManual }
        dlg:modify { id = "strExample", visible = false }
    end
}

dlg:newrow { always = false }

dlg:entry {
    id = "rangeStr",
    label = "Entry:",
    text = defaults.rangeStr,
    focus = false,
    visible = defaults.frameTarget == "MANUAL",
    onchange = function()
        dlg:modify { id = "strExample", visible = true }
    end
}

dlg:newrow { always = false }

dlg:label {
    id = "strExample",
    label = "Example:",
    text = defaults.strExample,
    visible = false
}

dlg:newrow { always = false }

dlg:slider {
    id = "scale",
    label = "Scale:",
    min = 1,
    max = 10,
    value = defaults.scale
}

dlg:newrow { always = false }

dlg:check {
    id = "usePixelAspect",
    label = "Apply:",
    text = "Pi&xel Aspect",
    selected = defaults.usePixelAspect,
    visible = true
}

dlg:newrow { always = false }

dlg:file {
    id = "filename",
    label = "File:",
    filetypes = AseUtilities.FILE_FORMATS,
    save = true,
    focus = true
}

dlg:newrow { always = false }

dlg:label {
    id = "alphaWarning",
    label = "Note:",
    text = "Alpha is ignored."
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    onclick = function()
        local activeSprite <const> = app.site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        -- Unpack arguments.
        local args <const> = dlg.data
        local filename = args.filename --[[@as string]]
        local frameTarget <const> = args.frameTarget
            or defaults.frameTarget --[[@as string]]
        local rangeStr <const> = args.rangeStr
            or defaults.rangeStr --[[@as string]]
        local scale <const> = args.scale
            or defaults.scale --[[@as integer]]
        local usePixelAspect <const> = args.usePixelAspect --[[@as boolean]]

        local fileExt <const> = app.fs.fileExtension(filename)
        local fileExtLower <const> = string.lower(fileExt)
        local extIsPbm <const> = fileExtLower == "pbm"
        local extIsPgm <const> = fileExtLower == "pgm"
        local extIsPpm <const> = fileExtLower == "ppm"
        if not (extIsPbm or extIsPgm or extIsPpm) then
            app.alert {
                title = "Error",
                text = "File extension must be pbm, pgm or ppm."
            }
            return
        end

        local filePath = app.fs.filePath(filename)
        if filePath == nil or #filePath < 1 then
            app.alert {
                title = "Error",
                text = "Empty file path."
            }
            return
        end
        filePath = string.gsub(filePath, "\\", "\\\\")

        local pathSep = app.fs.pathSeparator
        pathSep = string.gsub(pathSep, "\\", "\\\\")

        local fileTitle = app.fs.fileTitle(filename)
        if #fileTitle < 1 then
            fileTitle = app.fs.fileTitle(activeSprite.filename)
        end
        fileTitle = Utilities.validateFilename(fileTitle)

        filePath = filePath .. pathSep
        local filePrefix <const> = filePath .. fileTitle

        -- Unpack sprite spec.
        local spriteSpec <const> = activeSprite.spec
        local wSprite <const> = spriteSpec.width
        local hSprite <const> = spriteSpec.height
        local colorMode <const> = spriteSpec.colorMode

        -- Process scale.
        local wScale = scale
        local hScale = scale
        if usePixelAspect then
            local pxRatio <const> = activeSprite.pixelRatio
            local pxw <const> = math.max(1, math.abs(pxRatio.width))
            local pxh <const> = math.max(1, math.abs(pxRatio.height))
            wScale = wScale * pxw
            hScale = hScale * pxh
        end
        local useResize <const> = wScale ~= 1 or hScale ~= 1
        local wSpriteScld <const> = wSprite * wScale
        local hSpriteScld <const> = hSprite * hScale
        local rowRect <const> = Rectangle(0, 0, wSpriteScld, 1)

        -- Get frames.
        local frIdcs <const> = Utilities.flatArr2(AseUtilities.getFrames(
            activeSprite, frameTarget, true, rangeStr))
        local lenFrIdcs <const> = #frIdcs
        local frObjs <const> = activeSprite.frames
        local palettes <const> = activeSprite.palettes

        -- Cache global methods to local.
        local resizeImage <const> = AseUtilities.resizeImageNearest
        local getPalette <const> = AseUtilities.getPalette
        local strfmt <const> = string.format
        local tconcat <const> = table.concat

        -- Handle color mode.
        local cmIsRgb <const> = colorMode == ColorMode.RGB
        local cmIsGry <const> = colorMode == ColorMode.GRAY
        local cmIsIdx <const> = colorMode == ColorMode.INDEXED

        local headerStr = ""
        local sizeStr <const> = strfmt("%d %d", wSpriteScld, hSpriteScld)
        local channelSzStr = ""
        local writePixel = nil

        -- TODO: Customizable channel depth for ppm and pgm?
        local channelSize <const> = 255
        local frmtrStr = "%03d"
        if channelSize < 10 then
            frmtrStr = "%01d"
        elseif channelSize < 100 then
            frmtrStr = "%02d"
        end

        if extIsPpm then
            -- File extension supports RGB.
            headerStr = "P3"
            channelSzStr = strfmt("%d", channelSize)

            local rgbFrmtrStr <const> = strfmt(
                "%s %s %s",
                frmtrStr, frmtrStr, frmtrStr)

            if cmIsIdx then
                writePixel = function(h, p)
                    local c <const> = p:getColor(h)
                    return strfmt(rgbFrmtrStr, c.red, c.green, c.blue)
                end
            elseif cmIsGry then
                writePixel = function(h)
                    local gray <const> = h & 0xff
                    return strfmt(rgbFrmtrStr, gray, gray, gray)
                end
            else
                -- Default to RGB color mode.
                writePixel = function(h)
                    return strfmt(
                        rgbFrmtrStr,
                        h & 0xff,
                        (h >> 0x08) & 0xff,
                        (h >> 0x10) & 0xff)
                end
            end
        elseif extIsPgm then
            -- File extension supports grayscale.
            -- Use Aseprite's definition of relative luma.
            -- From Wikipedia: "Conventionally PGM stores values in linear
            -- color space, but depending on the application, it can often use
            -- either sRGB or a simplified gamma representation."

            headerStr = "P2"
            channelSzStr = strfmt("%d", channelSize)

            if cmIsIdx then
                writePixel = function(h, p)
                    local c <const> = p:getColor(h)
                    local sr <const> = c.red
                    local sg <const> = c.green
                    local sb <const> = c.blue
                    local gray <const> = (sr * 2126 + sg * 7152 + sb * 722) // 10000
                    return strfmt(frmtrStr, gray)
                end
            elseif cmIsRgb then
                writePixel = function(h)
                    local sr <const> = h & 0xff
                    local sg <const> = (h >> 0x08) & 0xff
                    local sb <const> = (h >> 0x10) & 0xff
                    local gray <const> = (sr * 2126 + sg * 7152 + sb * 722) // 10000
                    return strfmt(frmtrStr, gray)
                end
            else
                -- Default to grayscale color mode.
                writePixel = function(h)
                    return strfmt(frmtrStr, h & 0xff)
                end
            end
        else
            -- Default to extIsPbm (1 or 0).
            -- The channelSzStr cannot be nil. As an empty string it causes
            -- an extra blank line which could throw a parser off.
            headerStr = "P1"
            channelSzStr = ""

            if cmIsGry then
                writePixel = function(h)
                    local gray <const> = h & 0xff
                    if gray < 128 then return "1" end
                    return "0"
                end
            elseif cmIsRgb then
                writePixel = function(h)
                    local sr <const> = h & 0xff
                    local sg <const> = (h >> 0x08) & 0xff
                    local sb <const> = (h >> 0x10) & 0xff
                    local gray <const> = (sr * 2126 + sg * 7152 + sb * 722) // 10000
                    if gray < 128 then return "1" end
                    return "0"
                end
            else
                writePixel = function(h, p)
                    local c <const> = p:getColor(h)
                    local sr <const> = c.red
                    local sg <const> = c.green
                    local sb <const> = c.blue
                    local gray <const> = (sr * 2126 + sg * 7152 + sb * 722) // 10000
                    if gray < 128 then return "1" end
                    return "0"
                end
            end
        end

        local i = 0
        while i < lenFrIdcs do
            i = i + 1
            local frIdx <const> = frIdcs[i]
            local frObj <const> = frObjs[frIdx]
            local palette <const> = getPalette(frIdx, palettes)

            local trgImage = Image(spriteSpec)
            trgImage:drawSprite(activeSprite, frObj)
            local trgPxItr <const> = trgImage:pixels()

            ---@type table<integer, string>
            local hexToStr <const> = {}
            for pixel in trgPxItr do
                local hex <const> = pixel()
                if not hexToStr[hex] then
                    hexToStr[hex] = writePixel(hex, palette)
                end
            end

            if useResize then
                trgImage = resizeImage(
                    trgImage, wSpriteScld, hSpriteScld)
            end

            ---@type string[]
            local rowStrs <const> = {}
            local j = 0
            while j < hSpriteScld do
                ---@type string[]
                local colStrs <const> = {}
                rowRect.y = j
                local rowItr <const> = trgImage:pixels(rowRect)
                for rowPixel in rowItr do
                    colStrs[#colStrs + 1] = hexToStr[rowPixel()]
                end

                j = j + 1
                rowStrs[j] = tconcat(colStrs, " ")
            end

            -- Exports ignore frame UI offset and begin at zero.
            -- TODO: Ignore frame number if there is only one
            -- (change formatter string)?
            local frFilepath <const> = strfmt(
                "%s_%03d.%s",
                filePrefix, frIdx - 1, fileExt)
            local file <const>, err <const> = io.open(frFilepath, "w")
            if file then
                local netString <const> = tconcat({
                    headerStr,
                    sizeStr,
                    channelSzStr,
                    tconcat(rowStrs, "\n")
                }, "\n")
                file:write(netString)
                file:close()
            end
        end

        app.alert {
            title = "Success",
            text = "File(s) exported."
        }
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }