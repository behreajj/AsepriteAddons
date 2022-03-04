local unitOptions = { "PERCENT", "PIXEL" }
local resizeMethods = { "BICUBIC", "NEAREST" }

local defaults = {
    resizeMethod = "BICUBIC",
    pxWidth = 64,
    pxHeight = 64,
    prcWidth = 100,
    prcHeight = 100,
    units = "PERCENT",
    clipImage = true,
    copyToLayer = true,
    preserveAspect = false,
    printElapsed = false,
    pullFocus = false
}

local dlg = Dialog { title = "Resize Cel" }

dlg:combobox {
    id = "resizeMethod",
    label = "Type:",
    option = defaults.resizeMethod,
    options = resizeMethods
}

dlg:number {
    id = "pxWidth",
    label = "Width Px:",
    text = string.format("%.0f", defaults.pxWidth),
    decimals = 5,
    visible = defaults.units == "PIXEL"
}

dlg:number {
    id = "pxHeight",
    label = "Height Px:",
    text = string.format("%.0f", defaults.pxHeight),
    decimals = 5,
    visible = defaults.units == "PIXEL"
}

dlg:number {
    id = "prcWidth",
    label = "Width %:",
    text = string.format("%.0f", defaults.prcWidth),
    decimals = 5,
    visible = defaults.units == "PERCENT"
}

dlg:number {
    id = "prcHeight",
    label = "Height %:",
    text = string.format("%.0f", defaults.prcHeight),
    decimals = 5,
    visible = defaults.units == "PERCENT"
}

dlg:combobox {
    id = "units",
    label = "Units:",
    option = defaults.units,
    options = unitOptions,
    onchange = function()
        local unitType = dlg.data.units
        dlg:modify {
            id = "pxWidth",
            visible = unitType == "PIXEL"
        }
        dlg:modify {
            id = "pxHeight",
            visible = unitType == "PIXEL"
        }

        dlg:modify {
            id = "prcWidth",
            visible = unitType == "PERCENT"
        }
        dlg:modify {
            id = "prcHeight",
            visible = unitType == "PERCENT"
        }
    end
}

dlg:check {
    id = "clipImage",
    label = "Limit Sample:",
    selected = defaults.clipImage
}

dlg:check {
    id = "copyToLayer",
    label = "As New Layer:",
    selected = defaults.copyToLayer
}

dlg:check {
    id = "preserveAspect",
    label = "Preserve Aspect:",
    selected = defaults.preserveAspect
}

dlg:check {
    id = "printElapsed",
    label = "Print Diagnostic:",
    selected = defaults.printElapsed
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data
        local sprite = app.activeSprite
        if sprite then
            local srcCel = app.activeCel
            if srcCel then
                local oldMode = sprite.colorMode
                app.command.ChangePixelFormat { format = "rgb" }

                local srcImg = srcCel.image
                -- if srcImg ~= nil then

                -- Adapted from
                -- https://stackoverflow.com/questions/
                -- 17640173/implementation-of-bi-cubic-resize

                local printElapsed = args.printElapsed
                local startTime = 0
                local endTime = 0
                local elapsed = 0
                if printElapsed then
                    startTime = os.time()
                end

                -- Cache global functions to locals.
                local max = math.max
                local min = math.min
                local trunc = math.tointeger

                -- Find source and destination dimensions.
                local srcSpec = srcImg.spec
                local sw = srcSpec.width
                local sh = srcSpec.height
                local alphaIdx = srcSpec.transparentColor
                local colorSpace = srcSpec.colorSpace

                local clipImage = args.clipImage
                local srcBounds = nil
                if clipImage then

                    -- A cel may be located at a negative position
                    -- and/or have a width, height that exceed the
                    -- sprite boundaries.
                    local celBounds = srcCel.bounds
                    local spriteRect = Rectangle(
                        0, 0, sprite.width, sprite.height)
                    local intersect = celBounds:intersect(spriteRect)

                    -- The image sample rectangle, however, treats
                    -- the cel boundary position as (0, 0), so
                    -- invert the translation.
                    intersect.x = intersect.x - celBounds.x
                    intersect.y = intersect.y - celBounds.y

                    srcBounds = intersect
                    sw = intersect.width
                    sh = intersect.height
                else
                    sw = trunc(0.5 + sw)
                    sh = trunc(0.5 + sh)
                    srcBounds = Rectangle(0, 0, sw, sh)
                end

                local dw = sw
                local dh = sh

                local unitType = args.units
                local preserveAspect = args.preserveAspect
                if unitType == "PERCENT" then
                    local wPrc = args.prcWidth or defaults.prcWidth
                    local hPrc = args.prcHeight or defaults.prcHeight

                    -- TODO: Consider instead setting 0 or negative
                    -- values to 100%?
                    wPrc = max(1, wPrc)
                    hPrc = max(1, hPrc)

                    if preserveAspect then
                        local pcComp = (wPrc + hPrc) * 0.5
                        -- local pcComp = min(wPrc, hPrc)
                        wPrc = pcComp
                        hPrc = pcComp
                    end

                    dw = trunc(0.5 + sw * 0.01 * wPrc)
                    dh = trunc(0.5 + sh * 0.01 * hPrc)
                else
                    local wPxl = args.pxWidth or sw
                    local hPxl = args.pxHeight or sh

                    dw = max(2, wPxl)
                    dh = max(2, hPxl)

                    if preserveAspect then
                        local wRatio = dw / sw
                        local hRatio = dh / sh
                        local pxComp = (wRatio + hRatio) * 0.5
                        -- local pxComp = min(wRatio, hRatio)
                        dw = pxComp * sw
                        dh = pxComp * sh
                    end

                    dw = trunc(0.5 + dw)
                    dh = trunc(0.5 + dh)
                end

                -- Return early if no resize is needed.
                if dw == sw and dh == sh then
                    app.alert {
                        title = "Warning",
                        text = "New size matches the original."
                    }
                    return
                end

                -- Acquire pixels from source image.
                local srcpx = {}
                local srcpxitr = srcImg:pixels(srcBounds)
                local srcidx = 1
                for elm in srcpxitr do
                    srcpx[srcidx] = elm()
                    srcidx = srcidx + 1
                end

                local tx = sw / dw
                local ty = sh / dh
                local clrs = {}

                -- Set target image pixels.
                local trgSpec = ImageSpec {
                    height = dh,
                    width = dw,
                    colorMode = ColorMode.RGB,
                    transparentColor = alphaIdx }
                trgSpec.colorSpace = colorSpace
                local trgImg = Image(trgSpec)
                local trgpxitr = trgImg:pixels()

                local resizeMethod = args.resizeMethod or defaults.resizeMethod
                if resizeMethod == "BICUBIC" then
                    local chnlCount = 4

                    local kernelSize = 4
                    local kernel = { 0, 0, 0, 0 }

                    local len2 = kernelSize * chnlCount
                    local len3 = dw * len2
                    local len4 = dh * len3

                    local swn1 = sw - 1
                    local shn1 = sh - 1

                    for k = 0, len4, 1 do
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

                        local zw = z * sw
                        local i8 = i * 8

                        local a0 = srcpx[1 + zw + x0] >> i8 & 0xff
                        local d0 = srcpx[1 + zw + x1] >> i8 & 0xff
                        local d2 = srcpx[1 + zw + x2] >> i8 & 0xff
                        local d3 = srcpx[1 + zw + x3] >> i8 & 0xff

                        d0 = d0 - a0
                        d2 = d2 - a0
                        d3 = d3 - a0

                        local d36 = d3 / 6.0
                        local a1 = -d0 / 3.0 + d2 - d36
                        local a2 = 0.5 * (d0 + d2)
                        local a3 = -d0 / 6.0 - 0.5 * d2 + d36

                        kernel[1 + j] = max(0, min(255,
                            a0 + trunc(a1 * dx
                                        + a2 * dxsq
                                        + a3 * (dx * dxsq))))

                        a0 = kernel[2]
                        d0 = kernel[1] - a0
                        d2 = kernel[3] - a0
                        d3 = kernel[4] - a0

                        d36 = d3 / 6.0
                        a1 = -d0 / 3.0 + d2 - d36
                        a2 = 0.5 * (d0 + d2)
                        a3 = -d0 / 6.0 - 0.5 * d2 + d36

                        clrs[1 + (k // kernelSize)] = max(0, min(255,
                            a0 + trunc(a1 * dy
                                        + a2 * dysq
                                        + a3 * (dy * dysq))))
                    end

                    local h = 0
                    for elm in trgpxitr do
                        local hex = clrs[h + 1]
                                    | clrs[h + 2] << 0x08
                                    | clrs[h + 3] << 0x10
                                    | clrs[h + 4] << 0x18
                        elm(hex)
                        h = h + 4
                    end
                else
                    -- Default to nearest-neighbor.
                    local h = 0
                    for elm in trgpxitr do
                        local x = h % dw
                        local y = h // dw
                        local nx = trunc(x * tx)
                        local ny = trunc(y * ty)
                        elm(srcpx[1 + ny * sw + nx])
                        h = h + 1
                    end
                end

                app.transaction(function()
                    local copyToLayer = args.copyToLayer
                    local trgCel = nil
                    if copyToLayer then
                        local srcLayer = srcCel.layer

                        -- Copy layer.
                        local trgLayer = sprite:newLayer()
                        local srcLayerName = "Layer"
                        if srcLayer.name and #srcLayer.name > 0 then
                            srcLayerName = srcLayer.name
                        end
                        trgLayer.name = string.format(
                            "%s.%dx%d",
                            srcLayerName, dw, dh)
                        if srcLayer.opacity then
                            trgLayer.opacity = srcLayer.opacity
                        end
                        if srcLayer.blendMode then
                            trgLayer.blendMode = srcLayer.blendMode
                        end

                        -- Copy cel.
                        local frame = app.activeFrame or sprite.frames[1]
                        local newCel = sprite:newCel(
                            trgLayer, frame,
                            trgImg, srcCel.position)
                        newCel.opacity = srcCel.opacity
                        trgCel = newCel
                    else
                        srcCel.image = trgImg
                        trgCel = srcCel
                    end

                    -- Put the cel at center. trunc is out of scope
                    -- maybe due to the transaction.
                    local celPos = srcCel.position
                    local xCenter = celPos.x + sw * 0.5
                    local yCenter = celPos.y + sh * 0.5
                    trgCel.position = Point(
                        xCenter - dw * 0.5,
                        yCenter - dh * 0.5)
                end)

                if oldMode == ColorMode.INDEXED then
                    app.command.ChangePixelFormat { format = "indexed" }
                elseif oldMode == ColorMode.GRAY then
                    app.command.ChangePixelFormat { format = "gray" }
                end

                app.refresh()

                if printElapsed then
                    endTime = os.time()
                    elapsed = os.difftime(endTime, startTime)
                    app.alert {
                        title = "Diagnostic",
                        text = {
                            string.format("Source: %d x %d", sw, sh),
                            string.format("Target: %d x %d", dw, dh),
                            string.format("Start: %d", startTime),
                            string.format("End: %d", endTime),
                            string.format("Elapsed: %d", elapsed)
                        }
                    }
                end
                -- else
                --     app.alert("The cel has no image.")
                -- end
            else
                app.alert("There is no active cel.")
            end
        else
            app.alert("There is no active sprite.")
        end
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }