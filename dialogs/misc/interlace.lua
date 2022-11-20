dofile("../../support/aseutilities.lua")

local dirTypes = { "AND", "DIAGONAL", "HORIZONTAL", "RANDOM", "SQUARE", "VERTICAL", "XOR" }
local targets = { "ACTIVE", "ALL", "RANGE" }
local delOptions = { "DELETE_CELS", "DELETE_LAYER", "HIDE", "NONE" }

local defaults = {
    target = "RANGE",
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

        local activeLayer = app.activeLayer
        if not activeLayer then
            app.alert {
                title = "Error",
                text = "There is no active layer."
            }
            return
        end

        if activeLayer.isGroup then
            app.alert {
                title = "Error",
                text = "Group layers are not supported."
            }
            return
        end

        local isTilemap = false
        local tileSet = nil
        if AseUtilities.tilesSupport() then
            isTilemap = activeLayer.isTilemap
            if isTilemap then
                tileSet = activeLayer.tileset
            end
        end

        -- Unpack arguments.
        local args = dlg.data
        local target = args.target or defaults.target --[[@as string]]
        local dirType = args.dirType or defaults.dirType
        local delLyr = args.delLyr or defaults.delLyr

        local skip = args.skip or defaults.skip
        local xSkip = args.xSkip or defaults.xSkip --[[@as integer]]
        local ySkip = args.ySkip or defaults.ySkip --[[@as integer]]
        local aSkip = args.aSkip or defaults.aSkip --[[@as integer]]

        local pick = args.pick or defaults.pick
        local xPick = args.xPick or defaults.xPick --[[@as integer]]
        local yPick = args.yPick or defaults.yPick --[[@as integer]]
        local aPick = args.aPick or defaults.aPick --[[@as integer]]

        local frames = AseUtilities.getFrames(activeSprite, target)

        local activeBlendMode = activeLayer.blendMode
        local activeParent = activeLayer.parent

        local skipLayer = activeSprite:newLayer()
        local pickLayer = activeSprite:newLayer()
        local targetGroup = activeSprite:newGroup()

        skipLayer.name = "Skip"
        skipLayer.parent = targetGroup
        skipLayer.blendMode = activeBlendMode
        skipLayer.opacity = aSkip

        pickLayer.name = "Pick"
        pickLayer.parent = targetGroup
        pickLayer.blendMode = activeBlendMode
        pickLayer.opacity = aPick

        targetGroup.name = string.format(
            "%s.Interlaced.%s",
            activeLayer.name, dirType)
        targetGroup.parent = activeParent
        targetGroup.isCollapsed = true

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
                return math.random(0, a) < p
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
            eval = function(x, y, p, a)
                -- For booleans, xor == neq.
                return (x % a < p) ~= (y % a < p)
            end
        else
            -- Default to "HORIZONTAL".
            eval = function(x, y, p, a)
                return y % a < p
            end
        end

        local tilesToImage = AseUtilities.tilesToImage
        local colorMode = activeSprite.colorMode
        local offSkip = Point(xSkip, ySkip)
        local offPick = Point(xPick, yPick)

        local lenFrames = #frames
        app.transaction(function()
            local idxFrame = 0
            while idxFrame < lenFrames do
                idxFrame = idxFrame + 1
                local frame = frames[idxFrame]
                local cel = activeLayer:cel(frame)
                if cel then
                    local imgSrc = cel.image
                    if isTilemap then
                        imgSrc = tilesToImage(imgSrc, tileSet, colorMode)
                    end
                    local posSrc = cel.position
                    local xPos = posSrc.x
                    local yPos = posSrc.y

                    local specSrc = imgSrc.spec
                    local imgPick = Image(specSrc)
                    local imgSkip = Image(specSrc)

                    local alphaMask = specSrc.transparentColor
                    imgPick:clear(alphaMask)
                    imgSkip:clear(alphaMask)

                    local itrSrc = imgSrc:pixels()
                    for elm in itrSrc do
                        local x = elm.x
                        local y = elm.y
                        local xSmpl = xPos + x
                        local ySmpl = yPos + y
                        local hex = elm()
                        if eval(xSmpl, ySmpl, pick, all) then
                            imgPick:drawPixel(x, y, hex)
                        else
                            imgSkip:drawPixel(x, y, hex)
                        end
                    end

                    activeSprite:newCel(
                        pickLayer, frame, imgPick,
                        posSrc + offPick)
                    activeSprite:newCel(
                        skipLayer, frame, imgSkip,
                        posSrc + offSkip)
                end
            end
        end)

        if delLyr == "HIDE" then
            activeLayer.isVisible = false
        elseif (not activeLayer.isBackground) then
            if delLyr == "DELETE_LAYER" then
                activeSprite:deleteLayer(activeLayer)
            elseif delLyr == "DELETE_CELS" then
                app.transaction(function()
                    local idxDel = 0
                    while idxDel < lenFrames do
                        idxDel = idxDel + 1
                        local frame = frames[idxDel]
                        -- API reports an error if a cel cannot be
                        -- found, so the layer needs to check that
                        -- it has a cel first.
                        if activeLayer:cel(frame) then
                            activeSprite:deleteCel(activeLayer, frame)
                        end
                    end
                end)
            end
        end

        app.refresh()
        app.command.Refresh()
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