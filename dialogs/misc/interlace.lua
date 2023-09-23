dofile("../../support/aseutilities.lua")

local dirTypes <const> = {
    "AND",
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
    skip = 1,
    xSkip = 0.0,
    ySkip = 0.0,
    aSkip = 255,
    pick = 1,
    xPick = 0.0,
    yPick = 0.0,
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
    options = dirTypes
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
        local delLyr <const> = args.delLyr or defaults.delLyr --[[@as string]]

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

        local skipLayer = nil
        local pickLayer = nil
        local targetGroup = nil

        app.transaction("New Layers", function()
            skipLayer = activeSprite:newLayer()
            pickLayer = activeSprite:newLayer()
            targetGroup = activeSprite:newGroup()

            skipLayer.parent = targetGroup
            skipLayer.blendMode = srcBlendMode
            skipLayer.opacity = aSkip
            skipLayer.name = "Skip"

            pickLayer.parent = targetGroup
            pickLayer.blendMode = srcBlendMode
            pickLayer.opacity = aPick
            pickLayer.name = "Pick"

            targetGroup.parent = srcParent
            targetGroup.isCollapsed = true
            targetGroup.name = string.format(
                "%s.Interlaced.%s",
                srcLayer.name, dirType)
        end)

        local all <const> = pick + skip
        local eval = nil
        if dirType == "AND" then
            eval = function(x, y, p, a)
                return (x % a < p) and (y % a < p)
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
                    math.abs(x - activeSprite.width // 2),
                    math.abs(y - activeSprite.height // 2)) % a < p
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

        local tilesToImage <const> = AseUtilities.tilesToImage
        local strfmt <const> = string.format
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

                local srcSpec <const> = imgSrc.spec
                local imgPick <const> = Image(srcSpec)
                local imgSkip <const> = Image(srcSpec)

                local alphaIndex <const> = srcSpec.transparentColor
                imgPick:clear(alphaIndex)
                imgSkip:clear(alphaIndex)

                local pxItr <const> = imgSrc:pixels()
                for pixel in pxItr do
                    local x <const> = pixel.x
                    local y <const> = pixel.y
                    local xSmpl <const> = xPos + x
                    local ySmpl <const> = yPos + y
                    local hex <const> = pixel()
                    if eval(xSmpl, ySmpl, pick, all) then
                        imgPick:drawPixel(x, y, hex)
                    else
                        imgSkip:drawPixel(x, y, hex)
                    end
                end

                transact(
                    strfmt("Interlace %d", srcFrame),
                    function()
                        local pickCel <const> = activeSprite:newCel(
                            pickLayer, srcFrame, imgPick,
                            srcPos + offPick)
                        local skipCel <const> = activeSprite:newCel(
                            skipLayer, srcFrame, imgSkip,
                            srcPos + offSkip)

                        local srcOpacity <const> = srcCel.opacity
                        pickCel.opacity = srcOpacity
                        skipCel.opacity = srcOpacity
                    end)
            end
        end

        if delLyr == "HIDE" then
            srcLayer.isVisible = false
        elseif (not srcLayer.isBackground) then
            if delLyr == "DELETE_LAYER" then
                activeSprite:deleteLayer(srcLayer)
            elseif delLyr == "DELETE_CELS" then
                app.transaction("Delete Cels", function()
                    local idxDel = lenFrames + 1
                    while idxDel > 1 do
                        idxDel = idxDel - 1
                        local frame <const> = frames[idxDel]
                        local cel <const> = srcLayer:cel(frame)
                        if cel then activeSprite:deleteCel(cel) end
                    end
                end)
            end
        end

        -- Active layer assignment triggers a timeline update.
        app.activeLayer = targetGroup
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

dlg:show { wait = false }