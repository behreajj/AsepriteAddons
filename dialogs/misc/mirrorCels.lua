dofile("../../support/aseutilities.lua")
dofile("../../support/canvasutilities.lua")

local screenScale = 1
if app.preferences then
    local generalPrefs <const> = app.preferences.general
    if generalPrefs then
        local ssCand <const> = generalPrefs.screen_scale --[[@as integer]]
        if ssCand and ssCand > 0 then
            screenScale = ssCand
        end
    end
end

local edgeTypes <const> = { "CLAMP", "OMIT", "WRAP" }
local targets <const> = { "ACTIVE", "ALL", "RANGE" }
local delOptions <const> = { "DELETE_CELS", "DELETE_LAYER", "HIDE", "NONE" }

local defaults <const> = {
    target = "ACTIVE",
    delSrc = "NONE",
    edgeType = "OMIT",
    easeMethod = "NEAREST",
    useInverse = false,
    trimCels = false,
    pullFocus = true
}

local dlg <const> = Dialog { title = "Mirror" }

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
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local delSrcStr <const> = args.delSrc
            or defaults.delSrc --[[@as string]]
        local edgeType <const> = args.edgeType
            or defaults.edgeType --[[@as string]]
        local useInverse <const> = args.useInverse --[[@as boolean]]
        local trimCels <const> = args.trimCels --[[@as boolean]]

        -- Whether to use greater than or less than to
        -- determine which side of the line to mirror.
        local flipSign = 1.0
        if useInverse then flipSign = -1.0 end

        -- Find frames from target.
        local frames <const> = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))

        -- Determine how to wrap pixels.
        local getPixel = Utilities.getPixelOmit
        if edgeType == "CLAMP" then
            getPixel = Utilities.getPixelClamp
        elseif edgeType == "WRAP" then
            getPixel = Utilities.getPixelWrap
        end

        local spriteSpec <const> = activeSprite.spec
        local wSprite <const> = spriteSpec.width
        local hSprite <const> = spriteSpec.height
        local colorMode <const> = spriteSpec.colorMode
        local alphaIndex <const> = spriteSpec.transparentColor < 256
            and spriteSpec.transparentColor
            or 0
        local blendModeSrc <const> = BlendMode.SRC

        -- Calculate origin and destination.
        -- Divide by 100 to account for percentage.
        local xOrig = args.xOrig --[[@as number]]
        local yOrig = args.yOrig --[[@as number]]
        local xDest = args.xDest --[[@as number]]
        local yDest = args.yDest --[[@as number]]

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
        local dInvMagSq <const> = 1.0 / (dx * dx + dy * dy)

        -- Flat length of image for loop iteration.
        local lenFlat <const> = wSprite * hSprite

        -- Right side of line is mirrored, left side
        -- copies original pixels.
        local rgtLayer <const> = activeSprite:newLayer()
        local lftLayer <const> = activeSprite:newLayer()
        local mrrGroup <const> = activeSprite:newGroup()

        app.transaction("Set Layer Props", function()
            lftLayer.parent = mrrGroup
            lftLayer.opacity = srcLayer.opacity
            lftLayer.name = "Left"

            rgtLayer.parent = mrrGroup
            rgtLayer.opacity = srcLayer.opacity
            rgtLayer.name = "Right"

            mrrGroup.parent = AseUtilities.getTopVisibleParent(srcLayer)
            mrrGroup.isCollapsed = true
            mrrGroup.name = srcLayer.name .. " Mirrored"
        end)

        -- Cache global methods.
        local floor <const> = math.floor
        local trimAlpha <const> = AseUtilities.trimImageAlpha
        local tilesToImage <const> = AseUtilities.tileMapToImage
        local strfmt <const> = string.format
        local strpack <const> = string.pack
        local strsub <const> = string.sub
        local transact <const> = app.transaction
        local tconcat <const> = table.concat

        local lenFrames <const> = #frames
        local i = 0
        while i < lenFrames do
            i = i + 1
            local srcFrame <const> = frames[i]
            local srcCel <const> = srcLayer:cel(srcFrame)
            if srcCel then
                local srcImg = srcCel.image
                local srcPos <const> = srcCel.position
                local xSrcPos <const> = srcPos.x
                local ySrcPos <const> = srcPos.y

                if isTilemap then
                    srcImg = tilesToImage(
                        srcImg, tileSet, colorMode)
                end

                local wSrcImg <const> = srcImg.width
                local hSrcImg <const> = srcImg.height
                local flatImg = srcImg
                if xSrcPos ~= 0
                    or ySrcPos ~= 0
                    or wSrcImg ~= wSprite
                    or hSrcImg ~= hSprite then
                    flatImg = Image(spriteSpec)
                    flatImg:drawImage(srcImg, srcPos, 255, blendModeSrc)
                end

                local rgtImg = Image(spriteSpec)
                local lftImg = Image(spriteSpec)

                ---@type string[]
                local lftByteArr <const> = {}
                ---@type string[]
                local rgtByteArr <const> = {}
                local flatBytes <const> = flatImg.bytes
                local flatBpp <const> = flatImg.bytesPerPixel
                local pxAlpha <const> = strpack(
                    "<I" .. flatBpp, alphaIndex)

                local j = 0
                while j < lenFlat do
                    local cx <const> = j % wSprite
                    local cy <const> = j // wSprite
                    local ex <const> = cx - xOrPx
                    local ey <const> = cy - yOrPx
                    local cross <const> = ex * dy - ey * dx

                    local lftStr = pxAlpha
                    local rgtStr = pxAlpha
                    if flipSign * cross < 0.0 then
                        local orig <const> = 1 + j * flatBpp
                        local dest <const> = orig + flatBpp - 1
                        lftStr = strsub(flatBytes, orig, dest)
                    else
                        local t <const> = (ex * dx + ey * dy) * dInvMagSq
                        local u <const> = 1.0 - t
                        local pxProj <const> = u * xOrPx + t * xDsPx
                        local pyProj <const> = u * yOrPx + t * yDsPx
                        local pxOpp <const> = pxProj + pxProj - cx
                        local pyOpp <const> = pyProj + pyProj - cy

                        local ixOpp <const> = floor(0.5 + pxOpp)
                        local iyOpp <const> = floor(0.5 + pyOpp)

                        rgtStr = getPixel(flatBytes, ixOpp, iyOpp,
                            wSprite, hSprite, flatBpp, pxAlpha)
                    end

                    j = j + 1
                    lftByteArr[j] = lftStr
                    rgtByteArr[j] = rgtStr
                end

                lftImg.bytes = tconcat(lftByteArr)
                rgtImg.bytes = tconcat(rgtByteArr)

                local xTrimLft = 0
                local yTrimLft = 0
                local xTrimRgt = 0
                local yTrimRgt = 0
                if trimCels then
                    lftImg, xTrimLft, yTrimLft = trimAlpha(
                        lftImg, 0, alphaIndex)
                    rgtImg, xTrimRgt, yTrimRgt = trimAlpha(
                        rgtImg, 0, alphaIndex)
                end

                transact(
                    strfmt("Mirror %d", srcFrame + frameUiOffset),
                    function()
                        local lftCel <const> = activeSprite:newCel(
                            lftLayer, srcFrame, lftImg,
                            Point(xTrimLft, yTrimLft))
                        local rgtCel <const> = activeSprite:newCel(
                            rgtLayer, srcFrame, rgtImg,
                            Point(xTrimRgt, yTrimRgt))

                        local srcOpacity <const> = srcCel.opacity
                        local srcZIndex <const> = srcCel.zIndex
                        lftCel.opacity = srcOpacity
                        rgtCel.opacity = srcOpacity
                        lftCel.zIndex = srcZIndex
                        rgtCel.zIndex = srcZIndex
                    end)
            end
        end

        -- Active layer assignment triggers a timeline update.
        AseUtilities.hideSource(activeSprite, srcLayer, frames, delSrcStr)
        app.layer = mrrGroup
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

dlg:show {
    autoscrollbars = true,
    wait = false
}