dofile("../../support/aseutilities.lua")

local dirTypes <const> = {
    "AND",
    "CIRCLE",
    "DIAGONAL",
    "HORIZONTAL",
    "RANDOM",
    "SQUARE",
    "VERTICAL",
    "XOR"
}
local targets <const> = { "ACTIVE", "ALL", "RANGE" }
local delOptions <const> = { "DELETE_CELS", "DELETE_LAYER", "HIDE", "NONE" }

local defaults <const> = {
    target = "ACTIVE",
    delLyr = "HIDE",
    dirType = "HORIZONTAL",
    xOrig = 0,
    yOrig = 0,
    skip = 1,
    xSkip = 0,
    ySkip = 0,
    aSkip = 170,
    pick = 1,
    xPick = 0,
    yPick = 0,
    aPick = 255,
    pullFocus = false
}

local dlg <const> = Dialog { title = "Interlace" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:combobox {
    id = "delLyr",
    label = "Source:",
    option = defaults.delLyr,
    options = delOptions
}

dlg:newrow { always = false }

dlg:combobox {
    id = "dirType",
    label = "Method:",
    option = defaults.dirType,
    options = dirTypes,
    onchange = function()
        local args <const> = dlg.data
        local dirType <const> = args.dirType --[[@as string]]
        local useOrig <const> = dirType == "CIRCLE"
            or dirType == "SQUARE"
        dlg:modify { id = "xOrig", visible = useOrig }
        dlg:modify { id = "yOrig", visible = useOrig }
    end
}

dlg:newrow { always = false }

dlg:number {
    id = "xOrig",
    label = "Center:",
    text = string.format("%d", defaults.xOrig),
    decimals = 0,
    visible = defaults.dirType == "CIRCLE"
        or defaults.dirType == "SQUARE"
}

dlg:number {
    id = "yOrig",
    text = string.format("%d", defaults.yOrig),
    decimals = 0,
    visible = defaults.dirType == "CIRCLE"
        or defaults.dirType == "SQUARE"
}

dlg:separator {
    id = "skipSep",
    text = "Skip"
}

dlg:slider {
    id = "skip",
    label = "Count:",
    min = 1,
    max = 16,
    value = defaults.skip
}

dlg:newrow { always = false }

dlg:number {
    id = "xSkip",
    label = "Offset:",
    text = string.format("%d", defaults.xSkip),
    decimals = 0
}

dlg:number {
    id = "ySkip",
    text = string.format("%d", defaults.ySkip),
    decimals = 0
}

dlg:newrow { always = false }

dlg:slider {
    id = "aSkip",
    label = "Opacity:",
    min = 0,
    max = 255,
    value = defaults.aSkip
}

dlg:separator {
    id = "pickSep",
    text = "Pick"
}

dlg:slider {
    id = "pick",
    label = "Count:",
    min = 1,
    max = 16,
    value = defaults.pick
}

dlg:newrow { always = false }

dlg:number {
    id = "xPick",
    label = "Offset:",
    text = string.format("%d", defaults.xPick),
    decimals = 0
}

dlg:number {
    id = "yPick",
    text = string.format("%d", defaults.yPick),
    decimals = 0
}

dlg:newrow { always = false }

dlg:slider {
    id = "aPick",
    label = "Opacity:",
    min = 0,
    max = 255,
    value = defaults.aPick
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
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

        local docPrefs <const> = app.preferences.document(activeSprite)
        local tlPrefs <const> = docPrefs.timeline
        local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]

        -- Check for tile maps.
        local isTilemap <const> = srcLayer.isTilemap
        local tileSet = nil
        if isTilemap then
            tileSet = srcLayer.tileset
        end

        -- Unpack arguments.
        local args <const> = dlg.data
        local target <const> = args.target or defaults.target --[[@as string]]
        local dirType <const> = args.dirType or defaults.dirType --[[@as string]]
        local delSrcStr <const> = args.delLyr or defaults.delLyr --[[@as string]]
        local xOrig <const> = args.xOrig or defaults.xOrig --[[@as integer]]
        local yOrig <const> = args.yOrig or defaults.yOrig --[[@as integer]]

        local skip <const> = args.skip or defaults.skip --[[@as integer]]
        local xSkip <const> = args.xSkip or defaults.xSkip --[[@as integer]]
        local ySkip <const> = args.ySkip or defaults.ySkip --[[@as integer]]
        local aSkip <const> = args.aSkip or defaults.aSkip --[[@as integer]]

        local pick <const> = args.pick or defaults.pick --[[@as integer]]
        local xPick <const> = args.xPick or defaults.xPick --[[@as integer]]
        local yPick <const> = args.yPick or defaults.yPick --[[@as integer]]
        local aPick <const> = args.aPick or defaults.aPick --[[@as integer]]

        local frames <const> = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))

        local srcBlendMode <const> = srcLayer.blendMode
        local srcParent <const> = srcLayer.parent

        local skipLayer <const> = activeSprite:newLayer()
        local pickLayer <const> = activeSprite:newLayer()
        local targetGroup <const> = activeSprite:newGroup()

        app.transaction("Set Layer Props", function()
            skipLayer.parent = targetGroup
            skipLayer.blendMode = srcBlendMode
            skipLayer.opacity = aSkip
            skipLayer.name = "Skip"

            pickLayer.parent = targetGroup
            pickLayer.blendMode = srcBlendMode
            pickLayer.opacity = aPick
            pickLayer.name = "Pick"

            targetGroup.parent = AseUtilities.getTopVisibleParent(srcLayer)
            targetGroup.isCollapsed = true
            targetGroup.name = string.format(
                "%s Interlaced %s",
                srcLayer.name, dirType)
        end)

        local all <const> = pick + skip
        local eval = nil
        if dirType == "AND" then
            eval = function(x, y, p, a)
                return (x % a < p) and (y % a < p)
            end
        elseif dirType == "CIRCLE" then
            eval = function(x, y, p, a)
                local dx <const> = x - xOrig
                local dy <const> = y - yOrig
                return math.sqrt(dx * dx + dy * dy) % a < p
            end
        elseif dirType == "DIAGONAL" then
            -- Distinguish between (x - y) and (x + y)?
            eval = function(x, y, p, a)
                return (x - y) % a < p
            end
        elseif dirType == "RANDOM" then
            eval = function(x, y, p, a)
                return math.random(0, a - 1) < p
            end
        elseif dirType == "SQUARE" then
            eval = function(x, y, p, a)
                return math.max(
                    math.abs(x - xOrig),
                    math.abs(y - yOrig)) % a < p
            end
        elseif dirType == "VERTICAL" then
            eval = function(x, y, p, a)
                return x % a < p
            end
        elseif dirType == "XOR" then
            -- For booleans, xor == neq.
            eval = function(x, y, p, a)
                return (x % a < p) ~= (y % a < p)
            end
        else
            -- Default to "HORIZONTAL".
            eval = function(x, y, p, a)
                return y % a < p
            end
        end

        local tilesToImage <const> = AseUtilities.tileMapToImage
        local strfmt <const> = string.format
        local strpack <const> = string.pack
        local strsub <const> = string.sub
        local tconcat <const> = table.concat
        local transact <const> = app.transaction

        local colorMode <const> = activeSprite.colorMode
        local offSkip <const> = Point(xSkip, ySkip)
        local offPick <const> = Point(xPick, yPick)

        local lenFrames <const> = #frames
        local idxFrame = 0
        while idxFrame < lenFrames do
            idxFrame = idxFrame + 1
            local srcFrame <const> = frames[idxFrame]
            local srcCel <const> = srcLayer:cel(srcFrame)
            if srcCel then
                local imgSrc = srcCel.image
                if isTilemap then
                    imgSrc = tilesToImage(imgSrc, tileSet, colorMode)
                end

                local srcPos <const> = srcCel.position
                local xPos <const> = srcPos.x
                local yPos <const> = srcPos.y

                local srcBpp = imgSrc.bytesPerPixel
                local srcBytes <const> = imgSrc.bytes

                local srcSpec <const> = imgSrc.spec
                local wSrc <const> = srcSpec.width
                local hSrc <const> = srcSpec.height
                local alphaIndex <const> = srcSpec.transparentColor < 256
                    and srcSpec.transparentColor
                    or 0

                local lenSrc <const> = wSrc * hSrc
                ---@type string[]
                local pickByteArr <const> = {}
                ---@type string[]
                local skipByteArr <const> = {}
                local bppFmtStr <const> = "<I" .. srcBpp

                local alphaStr <const> = strpack(bppFmtStr, alphaIndex)

                local i = 0
                while i < lenSrc do
                    local x <const> = i % wSrc
                    local y <const> = i // wSrc
                    local xSmpl <const> = xPos + x
                    local ySmpl <const> = yPos + y
                    local ibpp <const> = i * srcBpp
                    local hexStr <const> = strsub(srcBytes, 1 + ibpp, srcBpp + ibpp)

                    i = i + 1
                    if eval(xSmpl, ySmpl, pick, all) then
                        pickByteArr[i] = hexStr
                        skipByteArr[i] = alphaStr
                    else
                        pickByteArr[i] = alphaStr
                        skipByteArr[i] = hexStr
                    end
                end

                local imgPick <const> = Image(srcSpec)
                imgPick.bytes = tconcat(pickByteArr)
                local imgSkip <const> = Image(srcSpec)
                imgSkip.bytes = tconcat(skipByteArr)

                transact(strfmt("Interlace %d", srcFrame + frameUiOffset),
                    function()
                        local pickCel <const> = activeSprite:newCel(
                            pickLayer, srcFrame, imgPick,
                            srcPos + offPick)
                        local skipCel <const> = activeSprite:newCel(
                            skipLayer, srcFrame, imgSkip,
                            srcPos + offSkip)

                        local srcOpacity <const> = srcCel.opacity
                        local srcZIndex <const> = srcCel.zIndex
                        pickCel.opacity = srcOpacity
                        skipCel.opacity = srcOpacity
                        pickCel.zIndex = srcZIndex
                        skipCel.zIndex = srcZIndex
                    end)
            end
        end

        -- Active layer assignment triggers a timeline update.
        AseUtilities.hideSource(activeSprite, srcLayer, frames, delSrcStr)
        app.layer = targetGroup
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