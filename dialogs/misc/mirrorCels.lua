dofile("../../support/aseutilities.lua")
dofile("../../support/canvasutilities.lua")

local screenScale = app.preferences.general.screen_scale

local edgeTypes = { "CLAMP", "OMIT", "WRAP" }
local targets = { "ACTIVE", "ALL", "RANGE" }
local delOptions = { "DELETE_CELS", "DELETE_LAYER", "HIDE", "NONE" }

local defaults = {
    target = "ACTIVE",
    delSrc = "NONE",
    edgeType = "OMIT",
    easeMethod = "NEAREST",
    useInverse = false,
    trimCels = false,
    pullFocus = true
}

local dlg = Dialog { title = "Mirror" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:combobox {
    id = "delSrc",
    label = "Source:",
    option = defaults.delSrc,
    options = delOptions
}

dlg:newrow { always = false }

dlg:combobox {
    id = "edgeType",
    label = "Edges:",
    option = defaults.edgeType,
    options = edgeTypes
}

CanvasUtilities.graphLine(
    dlg, "graphCart", "Graph:",
    128 // screenScale, 128 // screenScale,
    true, true,
    7, 0, -100, 0, 100,
    app.theme.color.text,
    Color { r = 128, g = 128, b = 128 })

-- TODO: Change naming scheme so that this can be assigned
-- an alt+ hotkey via ampersand?
dlg:check {
    id = "useInverse",
    label = "Invert:",
    selected = defaults.useInverse
}

dlg:newrow { always = false }

dlg:check {
    id = "trimCels",
    label = "Trim:",
    text = "Layer Ed&ges",
    selected = defaults.trimCels
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        -- Early returns.
        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local srcLayer = app.activeLayer --[[@as Layer]]
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
        local delSrcStr = args.delSrc or defaults.delSrc --[[@as string]]
        local edgeType = args.edgeType or defaults.edgeType --[[@as string]]
        local useInverse = args.useInverse --[[@as boolean]]
        local trimCels = args.trimCels --[[@as boolean]]

        -- Whether to use greater than or less than to
        -- determine which side of the line to mirror.
        local flipSign = 1.0
        if useInverse then flipSign = -1.0 end

        -- Find frames from target.
        local frames = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))

        -- Determine how to wrap pixels.
        local wrapper = nil
        if edgeType == "CLAMP" then
            wrapper = function(x, y, w, h, srcImg, alphaMask)
                return srcImg:getPixel(
                    math.min(math.max(x, 0), w - 1),
                    math.min(math.max(y, 0), h - 1))
            end
        elseif edgeType == "OMIT" then
            wrapper = function(x, y, w, h, srcImg, alphaMask)
                if x >= 0 and x < w
                    and y >= 0 and y < h then
                    return srcImg:getPixel(x, y)
                else
                    return alphaMask
                end
            end
        else
            wrapper = function(x, y, w, h, srcImg, alphaMask)
                return srcImg:getPixel(x % w, y % h)
            end
        end

        local spriteSpec = activeSprite.spec
        local wSprite = spriteSpec.width
        local hSprite = spriteSpec.height
        local colorMode = spriteSpec.colorMode
        local alphaMask = spriteSpec.transparentColor

        -- Calculate origin and destination.
        -- Divide by 100 to account for percentage.
        local xOrig = args.xOrig --[[@as integer]]
        local yOrig = args.yOrig --[[@as integer]]
        local xDest = args.xDest --[[@as integer]]
        local yDest = args.yDest --[[@as integer]]

        xOrig = xOrig * 0.005 + 0.5
        xDest = xDest * 0.005 + 0.5
        yOrig = 0.5 - yOrig * 0.005
        yDest = 0.5 - yDest * 0.005

        -- Bias required to cope with full reflection
        -- at edges of image (0, 0), (w, h).
        local xOrPx = xOrig * (wSprite + 1) - 0.5
        local yOrPx = yOrig * (hSprite + 1) - 0.5
        local xDsPx = xDest * (wSprite + 1) - 0.5
        local yDsPx = yDest * (hSprite + 1) - 0.5

        -- Find vector between origin and destination.
        -- If the points are too close together, handle
        -- invalid condition.
        local dx = xDsPx - xOrPx
        local dy = yDsPx - yOrPx
        local invalidFlag = (math.abs(dx) < 1)
            and (math.abs(dy) < 1)
        if invalidFlag then
            xOrPx = 0.0
            yOrPx = 0.0
            xDsPx = wSprite - 1.0
            yDsPx = hSprite - 1.0
            dx = xDsPx - xOrPx
            dy = yDsPx - yOrPx
        end
        local dInvMagSq = 1.0 / (dx * dx + dy * dy)

        -- Right side of line is mirrored, left side
        -- copies original pixels.
        local rgtLayer = nil
        local lftLayer = nil
        local mrrGroup = nil

        app.transaction("New Layers", function()
            rgtLayer = activeSprite:newLayer()
            lftLayer = activeSprite:newLayer()
            mrrGroup = activeSprite:newGroup()

            lftLayer.parent = mrrGroup
            lftLayer.opacity = srcLayer.opacity
            lftLayer.name = "Left"

            rgtLayer.parent = mrrGroup
            rgtLayer.opacity = srcLayer.opacity
            rgtLayer.name = "Right"

            mrrGroup.parent = srcLayer.parent
            mrrGroup.isCollapsed = true
            mrrGroup.name = srcLayer.name .. ".Mirrored"
        end)

        -- Cache global methods.
        local floor = math.floor
        local trimAlpha = AseUtilities.trimImageAlpha
        local tilesToImage = AseUtilities.tilesToImage

        local lenFrames = #frames
        local i = 0
        while i < lenFrames do
            i = i + 1
            local srcFrame = frames[i]
            local srcCel = srcLayer:cel(srcFrame)
            if srcCel then
                local srcImg = srcCel.image
                local srcPos = srcCel.position
                local xSrcPos = srcPos.x
                local ySrcPos = srcPos.y

                if isTilemap then
                    srcImg = tilesToImage(
                        srcImg, tileSet, colorMode)
                end

                local wSrcImg = srcImg.width
                local hSrcImg = srcImg.height
                local flatImg = srcImg
                if xSrcPos ~= 0
                    or ySrcPos ~= 0
                    or wSrcImg ~= wSprite
                    or hSrcImg ~= hSprite then
                    flatImg = Image(spriteSpec)
                    flatImg:drawImage(srcImg, srcPos)
                end

                local rgtImg = Image(spriteSpec)
                local lftImg = Image(spriteSpec)
                if alphaMask ~= 0 then
                    rgtImg:clear(alphaMask)
                    lftImg:clear(alphaMask)
                end

                local pxItr = flatImg:pixels()
                for pixel in pxItr do
                    local cx = pixel.x
                    local cy = pixel.y
                    local ex = cx - xOrPx
                    local ey = cy - yOrPx
                    local cross = ex * dy - ey * dx
                    if flipSign * cross < 0.0 then
                        local hex = pixel()
                        lftImg:drawPixel(cx, cy, hex)
                    else
                        local t = (ex * dx + ey * dy) * dInvMagSq
                        local u = 1.0 - t
                        local pxProj = u * xOrPx + t * xDsPx
                        local pyProj = u * yOrPx + t * yDsPx
                        local pxOpp = pxProj + pxProj - cx
                        local pyOpp = pyProj + pyProj - cy

                        local ixOpp = floor(0.5 + pxOpp)
                        local iyOpp = floor(0.5 + pyOpp)

                        rgtImg:drawPixel(cx, cy, wrapper(
                            ixOpp, iyOpp, wSprite, hSprite,
                            flatImg, alphaMask))
                    end
                end

                local xTrimLft = 0
                local yTrimLft = 0
                local xTrimRgt = 0
                local yTrimRgt = 0
                if trimCels then
                    lftImg, xTrimLft, yTrimLft = trimAlpha(
                        lftImg, 0, alphaMask)
                    rgtImg, xTrimRgt, yTrimRgt = trimAlpha(
                        rgtImg, 0, alphaMask)
                end

                app.transaction(
                    string.format("Mirror %d", srcFrame),
                    function()
                        local lftCel = activeSprite:newCel(
                            lftLayer, srcFrame, lftImg,
                            Point(xTrimLft, yTrimLft))
                        local rgtCel = activeSprite:newCel(
                            rgtLayer, srcFrame, rgtImg,
                            Point(xTrimRgt, yTrimRgt))

                        local srcOpacity = srcCel.opacity
                        lftCel.opacity = srcOpacity
                        rgtCel.opacity = srcOpacity
                    end)
            end
        end

        if delSrcStr == "HIDE" then
            srcLayer.isVisible = false
        elseif (not srcLayer.isBackground) then
            if delSrcStr == "DELETE_LAYER" then
                activeSprite:deleteLayer(srcLayer)
            elseif delSrcStr == "DELETE_CELS" then
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
        app.activeLayer = mrrGroup
        app.refresh()

        if invalidFlag then
            app.alert {
                title = "Warning",
                text = "Origin and destination are the same."
            }
        end
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