dofile("../../support/aseutilities.lua")

local frameTargetOptions <const> = { "ACTIVE", "ALL", "MANUAL", "RANGE" }
local formatOptions <const> = { "ASCII", "BINARY" }

local defaults <const> = {
    -- https://github.com/aseprite/aseprite/issues/2834
    -- https://www.wikiwand.com/en/Netpbm
    frameTarget = "ACTIVE",
    rangeStr = "",
    strExample = "4,6:9,13",
    scale = 1,
    usePixelAspect = true,
    channelSize = 255,
    format = "ASCII",
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

dlg:slider {
    id = "channelSize",
    label = "Channel:",
    min = 1,
    max = 255,
    value = defaults.channelSize
}

dlg:newrow { always = false }

dlg:combobox {
    id = "format",
    label = "Format:",
    option = defaults.format,
    options = formatOptions
}

dlg:newrow { always = false }

dlg:file {
    id = "filename",
    label = "File:",
    filetypes = { "pbm", "pgm", "ppm" },
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
        local channelSize <const> = args.channelSize
            or defaults.channelSize --[[@as integer]]
        local format <const> = args.format
            or defaults.format --[[@as string]]

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
        local floor <const> = math.floor
        local ceil <const> = math.ceil
        local strfmt <const> = string.format
        local strpack <const> = string.pack
        local strsub <const> = string.sub
        local tconcat <const> = table.concat
        local tinsert <const> = table.insert
        local resizeImage <const> = AseUtilities.resizeImageNearest
        local getPalette <const> = AseUtilities.getPalette

        -- Use Aseprite's definition of relative luma.
        ---@type fun(r: integer, g: integer, b: integer): integer
        local lum <const> = function(r, g, b)
            return (r * 2126 + g * 7152 + b * 722) // 10000
        end

        -- Handle color mode.
        local cmIsRgb <const> = colorMode == ColorMode.RGB
        local cmIsGry <const> = colorMode == ColorMode.GRAY
        local cmIsIdx <const> = colorMode == ColorMode.INDEXED

        local headerStr = ""
        local sizeStr <const> = strfmt("%d %d", wSpriteScld, hSpriteScld)
        local channelSzStr = ""
        local writePixel = nil

        -- Handle ASCII vs. binary format.
        local fmtIsBinary <const> = format == "BINARY"
        local fmtIsAscii <const> = format == "ASCII"
        local cSzVerif <const> = math.min(math.max(channelSize, 1), 255)
        local writerType = "w"
        local chunkSep <const> = "\n"
        local colSep = " "
        local rowSep = "\n"
        local isBinPbm = false
        local offTok <const> = "1"
        local onTok <const> = "0"
        if fmtIsBinary then
            writerType = "wb"
            colSep = ""
            rowSep = ""
        end

        -- Change number of digits in print display based on channel size
        -- for .pgm and .ppm.
        local toChnlSz <const> = cSzVerif / 255.0
        local frmtrStr = "%d"
        if fmtIsAscii then
            if cSzVerif < 10 then
                frmtrStr = "%01d"
            elseif cSzVerif < 100 then
                frmtrStr = "%02d"
            elseif cSzVerif < 1000 then
                frmtrStr = "%03d"
            end
        end

        if extIsPpm then
            -- File extension supports RGB.
            headerStr = "P3"
            channelSzStr = strfmt("%d", cSzVerif)
            local rgbFrmtrStr = strfmt(
                "%s %s %s",
                frmtrStr, frmtrStr, frmtrStr)
            if fmtIsBinary then
                headerStr = "P6"
                rgbFrmtrStr = "%s%s%s"
            end

            if cmIsIdx then
                if fmtIsBinary then
                    writePixel = function(h, p)
                        local c <const> = p:getColor(h)
                        return strfmt(rgbFrmtrStr,
                            strpack("B", floor(c.red * toChnlSz + 0.5)),
                            strpack("B", floor(c.green * toChnlSz + 0.5)),
                            strpack("B", floor(c.blue * toChnlSz + 0.5)))
                    end
                else
                    writePixel = function(h, p)
                        local c <const> = p:getColor(h)
                        return strfmt(rgbFrmtrStr,
                            floor(c.red * toChnlSz + 0.5),
                            floor(c.green * toChnlSz + 0.5),
                            floor(c.blue * toChnlSz + 0.5))
                    end
                end
            elseif cmIsGry then
                if fmtIsBinary then
                    writePixel = function(h)
                        local vc <const> = strpack("B", floor(
                            (h & 0xff) * toChnlSz + 0.5))
                        return strfmt(rgbFrmtrStr, vc, vc, vc)
                    end
                else
                    writePixel = function(h)
                        local v <const> = floor((h & 0xff) * toChnlSz + 0.5)
                        return strfmt(rgbFrmtrStr, v, v, v)
                    end
                end
            else
                -- Default to RGB color mode.
                if fmtIsBinary then
                    writePixel = function(h)
                        local r255 <const> = h & 0xff
                        local g255 <const> = (h >> 0x08) & 0xff
                        local b255 <const> = (h >> 0x10) & 0xff

                        local rCmp <const> = floor(r255 * toChnlSz + 0.5)
                        local gCmp <const> = floor(g255 * toChnlSz + 0.5)
                        local bCmp <const> = floor(b255 * toChnlSz + 0.5)

                        local rChar <const> = strpack("B", rCmp)
                        local gChar <const> = strpack("B", gCmp)
                        local bChar <const> = strpack("B", bCmp)

                        return strfmt(rgbFrmtrStr, rChar, gChar, bChar)
                    end
                else
                    writePixel = function(h)
                        return strfmt(rgbFrmtrStr,
                            floor((h & 0xff) * toChnlSz + 0.5),
                            floor((h >> 0x08 & 0xff) * toChnlSz + 0.5),
                            floor((h >> 0x10 & 0xff) * toChnlSz + 0.5))
                    end
                end
            end
        elseif extIsPgm then
            -- File extension supports grayscale.
            -- From Wikipedia:
            -- "Conventionally PGM stores values in linear color space, but
            -- depending on the application, it can often use either sRGB or a
            -- simplified gamma representation."

            headerStr = "P2"
            channelSzStr = strfmt("%d", cSzVerif)
            if fmtIsBinary then
                headerStr = "P5"
            end

            if cmIsIdx then
                if fmtIsBinary then
                    writePixel = function(h, p)
                        local c <const> = p:getColor(h)
                        return strpack("B", floor(lum(
                            c.red, c.green, c.blue) * toChnlSz + 0.5))
                    end
                else
                    writePixel = function(h, p)
                        local c <const> = p:getColor(h)
                        return strfmt(frmtrStr, floor(lum(
                            c.red, c.green, c.blue) * toChnlSz + 0.5))
                    end
                end
            elseif cmIsRgb then
                if fmtIsBinary then
                    writePixel = function(h)
                        return strpack("B", floor(lum(
                            h & 0xff,
                            h >> 0x08 & 0xff,
                            h >> 0x10 & 0xff) * toChnlSz + 0.5))
                    end
                else
                    writePixel = function(h)
                        return strfmt(frmtrStr, floor(lum(
                            h & 0xff,
                            h >> 0x08 & 0xff,
                            h >> 0x10 & 0xff) * toChnlSz + 0.5))
                    end
                end
            else
                -- Default to grayscale color mode.
                if fmtIsBinary then
                    writePixel = function(h)
                        return strpack("B", floor((h & 0xff) * toChnlSz + 0.5))
                    end
                else
                    writePixel = function(h)
                        return strfmt(frmtrStr, floor((h & 0xff) * toChnlSz + 0.5))
                    end
                end
            end
        else
            -- Default to extIsPbm (1 or 0).
            -- The channelSzStr cannot be nil. As an empty string it causes
            -- an extra blank line which could throw a parser off.
            headerStr = "P1"
            channelSzStr = ""
            if fmtIsBinary then
                headerStr = "P4"
                isBinPbm = true
            end

            if cmIsGry then
                writePixel = function(h)
                    if (h & 0xff) < 128 then return offTok end
                    return onTok
                end
            elseif cmIsRgb then
                writePixel = function(h)
                    if lum(h & 0xff, h >> 0x08 & 0xff,
                            h >> 0x10 & 0xff) < 128 then
                        return offTok
                    end
                    return onTok
                end
            else
                writePixel = function(h, p)
                    local c <const> = p:getColor(h)
                    if lum(c.red, c.green, c.blue) < 128 then return offTok end
                    return onTok
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
                rowStrs[j] = tconcat(colStrs, colSep)
            end

            local frFilepath = filename
            if lenFrIdcs > 1 then
                -- Exports ignore frame UI offset and begin at zero.
                frFilepath = strfmt(
                    "%s_%03d.%s",
                    filePrefix, frIdx - 1, fileExt)
            end

            local file <const>, err <const> = io.open(frFilepath, writerType)
            if file then
                local imgDataStr = ""
                if isBinPbm then
                    -- From Wikipedia:
                    -- "The P4 binary format of the same image represents each
                    -- pixel with a single bit, packing 8 pixels per byte, with
                    -- the first pixel as the most significant bit. Extra bits
                    -- are added at the end of each row to fill a whole byte."

                    ---@type string[]
                    local charStrs <const> = {}
                    local lenRows <const> = #rowStrs
                    local k = 0
                    while k < lenRows do
                        k = k + 1
                        local rowStr <const> = rowStrs[k]
                        local lenRowStr <const> = #rowStr
                        local lenRowChars <const> = ceil(lenRowStr / 8)

                        local m = 0
                        while m < lenRowChars do
                            local idxOrig <const> = 1 + m * 8
                            local idxDest <const> = idxOrig + 7
                            local strSeg = strsub(rowStr, idxOrig, idxDest)
                            while #strSeg < 8 do strSeg = strSeg .. offTok end
                            local numSeg <const> = tonumber(strSeg, 2)
                            charStrs[#charStrs + 1] = strpack("B", numSeg)
                            m = m + 1
                        end
                    end

                    imgDataStr = tconcat(charStrs)
                else
                    imgDataStr = tconcat(rowStrs, rowSep)
                end

                ---@type string[]
                local chunks <const> = { headerStr, sizeStr, imgDataStr }
                if not extIsPbm then
                    tinsert(chunks, 3, channelSzStr)
                end
                file:write(tconcat(chunks, chunkSep))
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