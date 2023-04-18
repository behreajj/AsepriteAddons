dofile("../../support/aseutilities.lua")

local dirTypes = { "AND", "DIAGONAL", "HORIZONTAL", "RANDOM", "SQUARE", "VERTICAL", "XOR" }
local targets = { "ACTIVE", "ALL", "RANGE" }
local delOptions = { "DELETE_CELS", "DELETE_LAYER", "HIDE", "NONE" }

local defaults = {
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

local dlg = Dialog { title = "Interlace" }

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
        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local srcLayer = app.activeLayer
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
        local isTilemap = srcLayer.isTilemap
        local tileSet = nil
        if isTilemap then
            tileSet = srcLayer.tileset
        end

        -- Unpack arguments.
        local args = dlg.data
        local target = args.target or defaults.target --[[@as string]]
        local dirType = args.dirType or defaults.dirType --[[@as string]]
        local delLyr = args.delLyr or defaults.delLyr --[[@as string]]

        local skip = args.skip or defaults.skip --[[@as integer]]
        local xSkip = args.xSkip or defaults.xSkip --[[@as integer]]
        local ySkip = args.ySkip or defaults.ySkip --[[@as integer]]
        local aSkip = args.aSkip or defaults.aSkip --[[@as integer]]

        local pick = args.pick or defaults.pick --[[@as integer]]
        local xPick = args.xPick or defaults.xPick --[[@as integer]]
        local yPick = args.yPick or defaults.yPick --[[@as integer]]
        local aPick = args.aPick or defaults.aPick --[[@as integer]]

        local frames = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))

        local srcBlendMode = srcLayer.blendMode
        local srcParent = srcLayer.parent

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

        local all = pick + skip
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

        local tilesToImage = AseUtilities.tilesToImage
        local strfmt = string.format
        local transact = app.transaction

        local colorMode = activeSprite.colorMode
        local offSkip = Point(xSkip, ySkip)
        local offPick = Point(xPick, yPick)

        local lenFrames = #frames
        local idxFrame = 0
        while idxFrame < lenFrames do
            idxFrame = idxFrame + 1
            local srcFrame = frames[idxFrame]
            local srcCel = srcLayer:cel(srcFrame)
            if srcCel then
                local imgSrc = srcCel.image
                if isTilemap then
                    imgSrc = tilesToImage(imgSrc, tileSet, colorMode)
                end
                local posSrc = srcCel.position
                local xPos = posSrc.x
                local yPos = posSrc.y

                local specSrc = imgSrc.spec
                local imgPick = Image(specSrc)
                local imgSkip = Image(specSrc)

                local alphaMask = specSrc.transparentColor
                imgPick:clear(alphaMask)
                imgSkip:clear(alphaMask)

                local pxItr = imgSrc:pixels()
                for pixel in pxItr do
                    local x = pixel.x
                    local y = pixel.y
                    local xSmpl = xPos + x
                    local ySmpl = yPos + y
                    local hex = pixel()
                    if eval(xSmpl, ySmpl, pick, all) then
                        imgPick:drawPixel(x, y, hex)
                    else
                        imgSkip:drawPixel(x, y, hex)
                    end
                end

                transact(
                    strfmt("Interlace %d", srcFrame),
                    function()
                        local pickCel = activeSprite:newCel(
                            pickLayer, srcFrame, imgPick,
                            posSrc + offPick)
                        local skipCel = activeSprite:newCel(
                            skipLayer, srcFrame, imgSkip,
                            posSrc + offSkip)

                        local srcOpacity = srcCel.opacity
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
                        local frame = frames[idxDel]
                        local cel = srcLayer:cel(frame)
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