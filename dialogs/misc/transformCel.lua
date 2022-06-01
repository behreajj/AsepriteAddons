dofile("../../support/aseutilities.lua")

local resizeMethods = { "BICUBIC", "NEAREST" }
local targets = { "ACTIVE", "ALL", "RANGE", "SELECTION" }
local unitOptions = { "PERCENT", "PIXEL" }

local defaults = {
    target = "ACTIVE",
    xTranslate = 0.0,
    yTranslate = 0.0,
    resizeMethod = "NEAREST",
    pxWidth = 64,
    pxHeight = 64,
    prcWidth = 100,
    prcHeight = 100,
    units = "PERCENT"
}

local function getTargetCels(activeSprite, targetPreset)
    local targetCels = {}
    local tinsert = table.insert
    local isUnlocked = AseUtilities.isEditableHierarchy

    -- TODO: Do not impact tile map layers!
    if targetPreset == "ACTIVE" then
        local activeLayer = app.activeLayer
        if activeLayer then
            if isUnlocked(activeLayer, activeSprite)
                and (not activeLayer.isBackground)
                and (not activeLayer.isReference) then
                local activeCel = app.activeCel
                if activeCel then
                    targetCels[1] = activeCel
                end
            end
        end
    elseif targetPreset == "RANGE" then
        local appRange = app.range
        local rangeCels = appRange.cels
        local rangeCelsLen = #rangeCels
        local i = 0
        while i < rangeCelsLen do i = i + 1
            local rangeCel = rangeCels[i]
            local celLayer = rangeCel.layer
            if isUnlocked(celLayer, activeSprite)
                and (not celLayer.isBackground)
                and (not celLayer.isReference) then
                tinsert(targetCels, rangeCel)
            end
        end
    elseif targetPreset == "SELECTION" then
        local sel = activeSprite.selection
        if (not sel.isEmpty) then
            local selOrigin = sel.origin
            local selBounds = sel.bounds
            local activeSpec = activeSprite.spec
            local actFrame = app.activeFrame

            -- Create a subset of flattened sprite.
            local flatSpec = ImageSpec {
                width = selBounds.width,
                height = selBounds.height,
                colorMode = activeSpec.colorMode,
                transparentColor = activeSpec.transparentColor }
            flatSpec.colorSpace = activeSpec.colorSpace
            local flatImage = Image(flatSpec)
            flatImage:drawSprite(
                activeSprite,
                actFrame.frameNumber,
                -selOrigin)

            -- Remove pixels within selection bounds
            -- but not within selection itself.
            local xMin = selBounds.x
            local yMin = selBounds.y
            local flatPxItr = flatImage:pixels()
            for elm in flatPxItr do
                local x = elm.x + xMin
                local y = elm.y + yMin
                if not sel:contains(x, y) then
                    elm(0x0)
                end
            end

            -- Create new layer and new cel. This
            -- makes three transactions.
            local adjLayer = activeSprite:newLayer()
            adjLayer.name = "Transformed"
            local adjCel = activeSprite:newCel(
                adjLayer, actFrame,
                flatImage, selOrigin)
            tinsert(targetCels, adjCel)
        end
    else
        local activeCels = activeSprite.cels
        local activeCelsLen = #activeCels
        local i = 0
        while i < activeCelsLen do i = i + 1
            local activeCel = activeCels[i]
            local celLayer = activeCel.layer
            if isUnlocked(celLayer, activeSprite)
                and (not celLayer.isBackground)
                and (not celLayer.isReference) then
                tinsert(targetCels, activeCel)
            end
        end
    end

    return targetCels
end

local dlg = Dialog { title = "Transform" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:number {
    id = "xTranslate",
    label = "Vector:",
    text = string.format("%.0f", defaults.xTranslate),
    decimals = 0
}

dlg:number {
    id = "yTranslate",
    text = string.format("%.0f", defaults.yTranslate),
    decimals = 0
}

dlg:newrow { always = false }

dlg:button {
    id = "translateButton",
    text = "&MOVE",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local xtr = args.xTranslate or defaults.xTranslate
        local ytr = args.yTranslate or defaults.yTranslate
        if xtr == 0.0 and ytr == 0.0 then return end

        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target)
        local celsLen = #cels

        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                local oldPos = cel.position
                cel.position = Point(
                    oldPos.x + xtr,
                    oldPos.y - ytr)
            end
        end)

        app.refresh()
    end
}

dlg:button {
    id = "wrapButton",
    text = "&WRAP",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local xtr = args.xTranslate or defaults.xTranslate
        local ytr = args.yTranslate or defaults.yTranslate
        if xtr == 0.0 and ytr == 0.0 then return end

        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target)
        local celsLen = #cels

        local wrap = AseUtilities.wrapImage
        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                cel.image = wrap(cel.image, xtr, ytr)
            end
        end)

        app.refresh()
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "tlAlignButton",
    label = "Align:",
    text = "TL",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target)
        local celsLen = #cels

        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                cels[i].position = Point(0, 0)
            end
        end)

        app.refresh()
    end
}

dlg:button {
    id = "tlAlignButton",
    text = "&T",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target)
        local celsLen = #cels

        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                cel.position = Point(cel.position.x, 0)
            end
        end)

        app.refresh()
    end
}

dlg:button {
    id = "trAlignButton",
    text = "TR",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target)
        local celsLen = #cels
        local wSprite = activeSprite.width

        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                local w = cel.image.width
                cel.position = Point(wSprite - w, 0)
            end
        end)

        app.refresh()
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "lAlignButton",
    text = "&L",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target)
        local celsLen = #cels

        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                cel.position = Point(0, cel.position.y)
            end
        end)

        app.refresh()
    end
}

dlg:button {
    id = "cAlignButton",
    text = "C&E",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target)
        local celsLen = #cels
        local xCtrSprite = activeSprite.width * 0.5
        local yCtrSprite = activeSprite.height * 0.5

        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                local celImg = cel.image
                local w = celImg.width
                local h = celImg.height
                cel.position = Point(
                    math.tointeger(0.5 + xCtrSprite - w * 0.5),
                    math.tointeger(0.5 + yCtrSprite - h * 0.5))
            end
        end)

        app.refresh()
    end
}

dlg:button {
    id = "rAlignButton",
    text = "&R",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target)
        local celsLen = #cels
        local wSprite = activeSprite.width

        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                cel.position = Point(
                    wSprite - cel.image.width,
                    cel.position.y)
            end
        end)

        app.refresh()
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "blAlignButton",
    text = "BL",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target)
        local celsLen = #cels
        local hSprite = activeSprite.height

        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                local h = cel.image.height
                cel.position = Point(0, hSprite - h)
            end
        end)

        app.refresh()
    end
}

dlg:button {
    id = "bAlignButton",
    text = "&B",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target)
        local celsLen = #cels
        local hSprite = activeSprite.height

        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                cel.position = Point(
                    cel.position.x,
                    hSprite - cel.image.height)
            end
        end)

        app.refresh()
    end
}

dlg:button {
    id = "brAlignButton",
    text = "BR",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target)
        local celsLen = #cels
        local wSprite = activeSprite.width
        local hSprite = activeSprite.height

        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                local celImg = cel.image
                cel.position = Point(
                    wSprite - celImg.width,
                    hSprite - celImg.height)
            end
        end)

        app.refresh()
    end
}

dlg:separator { id = "rotateSep" }

dlg:button {
    id = "rotate90Button",
    text = "&90",
    label = "Rotate:",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target)
        local celsLen = #cels

        local rot90 = AseUtilities.rotateImage90
        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                local srcImg = cel.image
                local wSrc = srcImg.width
                local hSrc = srcImg.height
                local xSrcHalf = wSrc // 2
                local ySrcHalf = hSrc // 2

                local celPos = cel.position
                local xtlSrc = celPos.x
                local ytlSrc = celPos.y

                local trgImg, _, _ = rot90(srcImg)
                local wTrg = trgImg.width
                local hTrg = trgImg.height
                local xTrgHalf = wTrg // 2
                local yTrgHalf = hTrg // 2

                cel.position = Point(
                    xtlSrc + xSrcHalf - xTrgHalf,
                    ytlSrc + ySrcHalf - yTrgHalf)
                cel.image = trgImg
            end
        end)

        app.refresh()
    end
}

dlg:button {
    id = "rotate180Button",
    text = "&180",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target)
        local celsLen = #cels

        local rot = AseUtilities.rotateImage180
        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                cel.image = rot(cel.image)
            end
        end)

        app.refresh()
    end
}

dlg:button {
    id = "rotate270Button",
    text = "&270",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target)
        local celsLen = #cels

        local rot270 = AseUtilities.rotateImage270
        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                local srcImg = cel.image
                local wSrc = srcImg.width
                local hSrc = srcImg.height
                local xSrcHalf = wSrc // 2
                local ySrcHalf = hSrc // 2

                local celPos = cel.position
                local xtlSrc = celPos.x
                local ytlSrc = celPos.y

                local trgImg, _, _ = rot270(srcImg)
                local wTrg = trgImg.width
                local hTrg = trgImg.height
                local xTrgHalf = wTrg // 2
                local yTrgHalf = hTrg // 2

                cel.position = Point(
                    xtlSrc + xSrcHalf - xTrgHalf,
                    ytlSrc + ySrcHalf - yTrgHalf)
                cel.image = trgImg
            end
        end)

        app.refresh()
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "fliphButton",
    text = "&HORIZONTAL",
    label = "Flip:",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target)
        local celsLen = #cels

        local fliph = AseUtilities.flipImageHoriz
        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                cel.image = fliph(cel.image)
            end
        end)

        app.refresh()
    end
}

dlg:button {
    id = "flipvButton",
    text = "&VERTICAL",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target)
        local celsLen = #cels

        local flipv = AseUtilities.flipImageVert
        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                cel.image = flipv(cel.image)
            end
        end)

        app.refresh()
    end
}

dlg:separator { id = "scaleSep" }

dlg:combobox {
    id = "resizeMethod",
    label = "Type:",
    option = defaults.resizeMethod,
    options = resizeMethods
}

dlg:newrow { always = false }

dlg:number {
    id = "pxWidth",
    label = "Pixels:",
    text = string.format("%.0f", defaults.pxWidth),
    decimals = 0,
    visible = defaults.units == "PIXEL"
}

dlg:number {
    id = "pxHeight",
    text = string.format("%.0f", defaults.pxHeight),
    decimals = 0,
    visible = defaults.units == "PIXEL"
}

dlg:number {
    id = "prcWidth",
    label = "Percent:",
    text = string.format("%.2f", defaults.prcWidth),
    decimals = 6,
    visible = defaults.units == "PERCENT"
}

dlg:number {
    id = "prcHeight",
    text = string.format("%.2f", defaults.prcHeight),
    decimals = 6,
    visible = defaults.units == "PERCENT"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "units",
    label = "Units:",
    option = defaults.units,
    options = unitOptions,
    onchange = function()
        local unitType = dlg.data.units
        local ispx = unitType == "PIXEL"
        local ispc = unitType == "PERCENT"
        dlg:modify { id = "pxWidth", visible = ispx }
        dlg:modify { id = "pxHeight", visible = ispx }
        dlg:modify { id = "prcWidth", visible = ispc }
        dlg:modify { id = "prcHeight", visible = ispc }
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "scaleButton",
    text = "&SCALE",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local abs = math.abs
        local max = math.max
        local min = math.min
        local trunc = math.tointeger

        local args = dlg.data
        local target = args.target or defaults.target
        local unitType = args.units or defaults.units
        local resizeMethod = args.resizeMethod or defaults.resizeMethod
        local wPrc = args.prcWidth or defaults.prcWidth
        local hPrc = args.prcHeight or defaults.prcHeight
        local wPxl = args.pxWidth or defaults.pxWidth
        local hPxl = args.pxHeight or defaults.pxHeight

        -- Validate target dimensions.
        wPrc = max(0.000001, abs(wPrc))
        hPrc = max(0.000001, abs(hPrc))
        wPxl = trunc(0.5 + max(1, abs(wPxl)))
        hPxl = trunc(0.5 + max(1, abs(hPxl)))
        wPrc = wPrc * 0.01
        hPrc = hPrc * 0.01

        -- Convert string checks to booleans for loop.
        local useBicubic = resizeMethod == "BICUBIC"
        local usePercent = unitType == "PERCENT"

        local cels = getTargetCels(activeSprite, target)
        local celsLen = #cels

        local oldMode = activeSprite.colorMode
        if useBicubic then
            app.command.ChangePixelFormat { format = "rgb" }
        end

        app.transaction(function()
            -- Declare bicubic constants outside the loop.
            local kernel = { 0, 0, 0, 0 }
            local chnlCount = 4
            local kernelSize = 4

            local o = 0
            while o < celsLen do o = o + 1
                local cel = cels[o]
                local srcImg = cel.image
                local srcSpec = srcImg.spec
                local sw = srcSpec.width
                local sh = srcSpec.height

                local dw = wPxl
                local dh = hPxl
                if usePercent then
                    dw = max(1, trunc(0.5 + sw * wPrc))
                    dh = max(1, trunc(0.5 + sh * hPrc))
                end

                if sw ~= dw or sh ~= dh then
                    local srcpx = {}
                    local srcpxitr = srcImg:pixels()
                    local srcidx = 1
                    for elm in srcpxitr do
                        srcpx[srcidx] = elm()
                        srcidx = srcidx + 1
                    end

                    local tx = sw / dw
                    local ty = sh / dh
                    local clrs = {}

                    local colorMode = srcSpec.colorMode
                    local alphaIdx = srcSpec.transparentColor
                    local colorSpace = srcSpec.colorSpace
                    local trgSpec = ImageSpec {
                        height = dh,
                        width = dw,
                        colorMode = colorMode,
                        transparentColor = alphaIdx }
                    trgSpec.colorSpace = colorSpace
                    local trgImg = Image(trgSpec)
                    local trgpxitr = trgImg:pixels()

                    if useBicubic then
                        kernel[1] = 0
                        kernel[2] = 0
                        kernel[3] = 0
                        kernel[4] = 0

                        local len2 = kernelSize * chnlCount
                        local len3 = dw * len2
                        local len4n1 = dh * len3 - 1

                        local swn1 = sw - 1
                        local shn1 = sh - 1

                        local k = -1
                        while k < len4n1 do k = k + 1
                            local g = k // len3 -- px row index
                            local m = k - g * len3 -- temp
                            local h = m // len2 -- px col index
                            local n = m - h * len2 -- temp
                            local i = n // kernelSize -- krn row index
                            local j = n % kernelSize -- krn col index

                            -- Row.
                            local y = trunc(ty * g)
                            local dy = ty * g - y
                            local dysq = dy * dy

                            -- Column.
                            local x = trunc(tx * h)
                            local dx = tx * h - x
                            local dxsq = dx * dx

                            -- Clamp kernel to image bounds.
                            local z = max(0, min(shn1, y - 1 + j))
                            local x0 = max(0, min(swn1, x))
                            local x1 = max(0, min(swn1, x - 1))
                            local x2 = max(0, min(swn1, x + 1))
                            local x3 = max(0, min(swn1, x + 2))

                            local zwp1 = 1 + z * sw
                            local i8 = i * 8

                            local a0 = srcpx[zwp1 + x0] >> i8 & 0xff
                            local d0 = srcpx[zwp1 + x1] >> i8 & 0xff
                            local d2 = srcpx[zwp1 + x2] >> i8 & 0xff
                            local d3 = srcpx[zwp1 + x3] >> i8 & 0xff

                            d0 = d0 - a0
                            d2 = d2 - a0
                            d3 = d3 - a0

                            local d36 = 0.66666666666667 * d3
                            local a1 = -0.33333333333333 * d0 + d2 - d36
                            local a2 = 0.5 * (d0 + d2)
                            local a3 = -0.66666666666667 * d0
                                - 0.5 * d2 + d36

                            kernel[1 + j] = max(0, min(255,
                                a0 + trunc(a1 * dx
                                    + a2 * dxsq
                                    + a3 * (dx * dxsq))))

                            a0 = kernel[2]
                            d0 = kernel[1] - a0
                            d2 = kernel[3] - a0
                            d3 = kernel[4] - a0

                            d36 = 0.66666666666667 * d3
                            a1 = -0.33333333333333 * d0 + d2 - d36
                            a2 = 0.5 * (d0 + d2)
                            a3 = -0.66666666666667 * d0
                                - 0.5 * d2 + d36

                            clrs[1 + (k // kernelSize)] = max(0, min(255,
                                a0 + trunc(a1 * dy
                                    + a2 * dysq
                                    + a3 * (dy * dysq))))
                        end

                        local idx = -3
                        for elm in trgpxitr do
                            idx = idx + 4
                            local hex = clrs[idx]
                                | clrs[idx + 1] << 0x08
                                | clrs[idx + 2] << 0x10
                                | clrs[idx + 3] << 0x18
                            elm(hex)
                        end
                    else
                        -- Default to nearest-neighbor.
                        local idx = -1
                        for elm in trgpxitr do
                            idx = idx + 1
                            local nx = trunc((idx % dw) * tx)
                            local ny = trunc((idx // dw) * ty)
                            elm(srcpx[1 + ny * sw + nx])
                        end
                    end

                    cel.image = trgImg
                    local celPos = cel.position
                    local xCenter = celPos.x + sw * 0.5
                    local yCenter = celPos.y + sh * 0.5
                    cel.position = Point(
                        xCenter - dw * 0.5,
                        yCenter - dh * 0.5)
                end
            end
        end)

        if useBicubic then
            AseUtilities.changePixelFormat(oldMode)
        end
        app.refresh()
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }
