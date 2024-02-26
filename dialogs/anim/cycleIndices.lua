dofile("../../support/aseutilities.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE" }
local incrTypes <const> = { "CONSTANT", "PER_FRAME" }
local incrDirs <const> = { "LEFT", "RIGHT" }
local delOptions <const> = { "DELETE_CELS", "DELETE_LAYER", "HIDE", "NONE" }

local defaults <const> = {
    target = "ALL",
    rangeStr = "",
    strExample = "4,6:9,13",
    delSrc = "NONE",
    incrType = "PER_FRAME",
    incrDir = "RIGHT",
    incrAmt = 1,
}

local dlg <const> = Dialog { title = "Cycle Indices" }

dlg:combobox {
    id = "target",
    label = "Frames:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:entry {
    id = "rangeStr",
    label = "Indices:",
    text = defaults.rangeStr,
    focus = false,
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

dlg:combobox {
    id = "incrType",
    label = "Step:",
    option = defaults.incrType,
    options = incrTypes
}

dlg:newrow { always = false }

dlg:combobox {
    id = "incrDir",
    label = "Direction:",
    option = defaults.incrDir,
    options = incrDirs
}

dlg:newrow { always = false }

dlg:slider {
    id = "incrAmt",
    label = "Step:",
    min = 1,
    max = 32,
    value = defaults.incrAmt
}

dlg:newrow { always = false }

dlg:combobox {
    id = "delSrc",
    label = "Source:",
    option = defaults.delSrc,
    options = delOptions
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    onclick = function()
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local srcLayer <const> = site.layer
        if not srcLayer then
            app.alert {
                title = "Error",
                text = "There is no active layer."
            }
            return
        end

        if srcLayer.isGroup then
            app.alert {
                title = "Error",
                text = "Group layers are not supported."
            }
            return
        end

        if srcLayer.isReference then
            app.alert {
                title = "Error",
                text = "Reference layers are not supported."
            }
            return
        end

        -- Check for tile map support.
        local srcIsTilemap <const> = srcLayer.isTilemap
        local tileSet = nil
        local lenTileSet = 0
        local baseIndex = 0
        if srcIsTilemap then
            tileSet = srcLayer.tileset
            if tileSet then
                lenTileSet = #tileSet
                baseIndex = tileSet.baseIndex
            end
        end

        local activeSpec <const> = activeSprite.spec
        local colorMode <const> = activeSpec.colorMode
        local alphaIndex <const> = activeSpec.transparentColor
        if (not srcIsTilemap) and colorMode ~= ColorMode.INDEXED then
            app.alert {
                title = "Error",
                text = "Only indexed color mode is supported."
            }
            return
        end

        -- Unpack arguments.
        local args <const> = dlg.data
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local rangeStr <const> = args.rangeStr
            or defaults.rangeStr --[[@as string]]
        local delSrcStr <const> = args.delSrc
            or defaults.delSrc --[[@as string]]
        local incrType <const> = args.incrType
            or defaults.incrType --[[@as string]]
        local incrDir <const> = args.incrDir
            or defaults.incrDir --[[@as string]]
        local incrAmt <const> = args.incrAmt
            or defaults.incrAmt --[[@as integer]]

        -- This needs to be done first, otherwise range will be lost.
        local frames <const> = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))
        local lenFrames <const> = #frames

        -- Create target layer.
        local trgLayer = nil
        app.transaction("Adjustment Layer", function()
            trgLayer = activeSprite:newLayer()
            local srcLayerName = "Layer"
            if #srcLayer.name > 0 then
                srcLayerName = srcLayer.name
            end
            trgLayer.name = string.format(
                "%s Cycled", srcLayerName)
            trgLayer.parent = srcLayer.parent
            trgLayer.opacity = srcLayer.opacity
            trgLayer.blendMode = srcLayer.blendMode
        end)

        local usePerFrame <const> = incrType == "PER_FRAME"
        local incrSigned <const> = incrDir == "LEFT"
            and -incrAmt
            or incrAmt
        local idxIncr = incrSigned

        ---@type integer[]
        local chosenIdcs = {}
        if srcIsTilemap then
            -- range.tile doesn't work as a getter.
            -- If it did work, you'd have to make sure to isolate
            -- map flags from indices.

            -- Parse range was designed for frames,
            -- in [1, len], not tiles in [0, len - 1].
            chosenIdcs = Utilities.parseRangeStringUnique(
                rangeStr, lenTileSet - 1, baseIndex - 1)
            if #chosenIdcs < 1 then
                local h = 1
                while h < lenTileSet do
                    chosenIdcs[#chosenIdcs + 1] = h
                    h = h + 1
                end
            end
        else
            local activeFrame <const> = site.frame
                or activeSprite.frames[1]
            local palActive <const> = AseUtilities.getPalette(
                activeFrame, activeSprite.palettes)
            local lenPalActive <const> = #palActive

            -- Parse range was designed for frames,
            -- in [1, len], not colorsin [0, len - 1].
            chosenIdcs = Utilities.parseRangeStringUnique(
                rangeStr, lenPalActive - 1, 0)

            if #chosenIdcs < 1 then
                local range <const> = app.range
                local rangeIsValid <const> = range.sprite == activeSprite
                local rangeColors <const> = range.colors
                local lenRangeColors <const> = #rangeColors
                if rangeIsValid and lenRangeColors > 1 then
                    local h = 0
                    while h < lenRangeColors do
                        h = h + 1
                        chosenIdcs[h] = rangeColors[h]
                    end
                else
                    local h = 0
                    while h < lenPalActive do
                        if h ~= alphaIndex
                            and palActive:getColor(h).alpha > 0 then
                            chosenIdcs[#chosenIdcs + 1] = h
                        end
                        h = h + 1
                    end
                end
            end
        end
        local lenChosenIdcs <const> = #chosenIdcs

        -- Cache methods used in loop.
        local pxTilei <const> = app.pixelColor.tileI
        local pxTilef <const> = app.pixelColor.tileF
        local pxTile <const> = app.pixelColor.tile
        local strbyte <const> = string.byte
        local strchar <const> = string.char
        local strpack <const> = string.pack
        local strsub <const> = string.sub
        local strunpack <const> = string.unpack
        local tconcat <const> = table.concat
        local tilesToImage <const> = AseUtilities.tileMapToImage

        app.transaction("Cycle Indices", function()
            local i = 0
            while i < lenFrames do
                i = i + 1
                local srcFrame <const> = frames[i]
                local srcCel <const> = srcLayer:cel(srcFrame)
                if srcCel then
                    local srcPos <const> = srcCel.position
                    local srcImg <const> = srcCel.image

                    local srcSpec <const> = srcImg.spec
                    local wSrc <const> = srcSpec.width
                    local hSrc <const> = srcSpec.height
                    local lenSrc <const> = wSrc * hSrc
                    local srcBytes <const> = srcImg.bytes

                    -- visited cannot be moved outside the i loop because the
                    -- index shift may be incremeneted per each frame.
                    ---@type table<integer, integer>
                    local visited <const> = {}
                    ---@type string[]
                    local trgStrsArr <const> = {}

                    if srcIsTilemap then
                        local bpp <const> = srcImg.bytesPerPixel
                        local j = 0
                        while j < lenSrc do
                            local jbpp <const> = j * bpp
                            local str <const> = strsub(srcBytes, 1 + jbpp, bpp + jbpp)
                            local srcMapIf <const> = strunpack("I4", str)
                            local srcIdx <const> = pxTilei(srcMapIf)
                            local srcFlags <const> = pxTilef(srcMapIf)

                            local trgIdx = srcIdx
                            if visited[srcIdx] then
                                trgIdx = visited[srcIdx]
                            else
                                -- This would be better as a binary search.
                                local doSearch = true
                                local k = 0
                                while k < lenChosenIdcs and doSearch do
                                    k = k + 1
                                    local candIdx <const> = chosenIdcs[k]
                                    if srcIdx == candIdx then
                                        doSearch = false
                                        local shift <const> = 1 + (k - 1 - idxIncr) % lenChosenIdcs
                                        trgIdx = chosenIdcs[shift]
                                    end
                                end
                                visited[srcIdx] = trgIdx
                            end

                            j = j + 1
                            local trgMapIf <const> = pxTile(trgIdx, srcFlags)
                            trgStrsArr[j] = strpack("I4", trgMapIf)
                        end
                    else
                        local j = 0
                        while j < lenSrc do
                            j = j + 1
                            local srcByte <const> = strbyte(srcBytes, j)
                            local trgByte = srcByte
                            if visited[srcByte] then
                                trgByte = visited[srcByte]
                            else
                                -- This would be better as a binary search.
                                local doSearch = true
                                local k = 0
                                while k < lenChosenIdcs and doSearch do
                                    k = k + 1
                                    local candByte <const> = chosenIdcs[k]
                                    if srcByte == candByte then
                                        doSearch = false
                                        local shift <const> = 1 + (k - 1 - idxIncr) % lenChosenIdcs
                                        trgByte = chosenIdcs[shift]
                                    end
                                end
                                visited[srcByte] = trgByte
                            end

                            trgStrsArr[j] = strchar(trgByte)
                        end
                    end

                    local trgImg = Image(srcSpec)
                    trgImg.bytes = tconcat(trgStrsArr)
                    if srcIsTilemap then
                        -- If you could create tile map layers, then you would
                        -- not have to do this.
                        trgImg = tilesToImage(trgImg, tileSet, colorMode)
                    end

                    local trgCel <const> = activeSprite:newCel(
                        trgLayer, srcFrame, trgImg, srcPos)
                    trgCel.opacity = srcCel.opacity
                    trgCel.zIndex = srcCel.zIndex
                end

                if usePerFrame then
                    idxIncr = idxIncr + incrSigned
                end
            end
        end)

        AseUtilities.hideSource(activeSprite, srcLayer, frames, delSrcStr)
        app.refresh()
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

dlg:show {
    autoscrollbars = true,
    wait = false
}