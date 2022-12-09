dofile("../../support/aseutilities.lua")

local targets = { "ACTIVE", "ALL", "RANGE" }

local defaults = {
    target = "ACTIVE",
    kernelStep = 1,
    pullFocus = false
}

local dlg = Dialog { title = "Box Blur" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:slider {
    id = "kernelStep",
    label = "Step:",
    min = 1,
    max = 8,
    value = defaults.kernelStep
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

        local colorMode = activeSprite.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
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

        -- Check for tile map support.
        local layerIsTilemap = false
        local tileSet = nil
        if AseUtilities.tilesSupport() then
            layerIsTilemap = srcLayer.isTilemap
            if layerIsTilemap then
                tileSet = srcLayer.tileset
            end
        end

        -- Unpack arguments.
        local args = dlg.data
        local target = args.target
            or defaults.target --[[@as string]]
        local krnStep = args.kernelStep
            or defaults.kernelStep --[[@as integer]]

        -- Cache global methods.
        local tilesToImage = AseUtilities.tilesToImage
        local fromHex = Clr.fromHex
        local rgbToLab = Clr.sRgbToSrLab2Internal
        local labToRgb = Clr.srLab2TosRgb
        local toHex = Clr.toHex

        local frames = AseUtilities.getFrames(activeSprite, target)
        local lenFrames = #frames

        -- Create a new layer, srcLayer should not be a group,
        -- and thus have an opacity and blend mode.
        local trgLayer = activeSprite:newLayer()
        local srcLayerName = "Layer"
        if #srcLayer.name > 0 then
            srcLayerName = srcLayer.name
        end
        trgLayer.name = srcLayerName .. ".Blurred"
        trgLayer.opacity = srcLayer.opacity
        trgLayer.blendMode = srcLayer.blendMode

        -- Create SRLAB2 dictionary outside of while loop
        -- to minimize re-calculation of SR LAB2 colors for
        -- similar images across multiple frames.
        local labDict = {}
        labDict[0] = { l = 0.0, a = 0.0, b = 0.0, alpha = 0.0 }

        -- Find width and flat length of kernel.
        -- All cells of kernel are weighted equally.
        -- If this changes, you'd need the denominator
        -- to be replaced by a table of weights.
        local wKrn = 1 + krnStep * 2
        local krnLen = wKrn * wKrn
        local denom = 1.0 / krnLen

        app.transaction(function()
            local i = 0
            while i < lenFrames do
                i = i + 1
                local srcFrame = frames[i]
                local srcCel = srcLayer:cel(srcFrame)
                if srcCel then
                    local srcImg = srcCel.image
                    if layerIsTilemap then
                        srcImg = tilesToImage(srcImg, tileSet, ColorMode.RGB)
                    end

                    local pxArr = {}
                    local lenPxArr = 0
                    local srcPixels = srcImg:pixels()
                    for pixel in srcPixels do
                        local hex = pixel()

                        lenPxArr = lenPxArr + 1
                        pxArr[lenPxArr] = hex

                        if not labDict[hex] then
                            labDict[hex] = rgbToLab(fromHex(hex))
                        end
                    end

                    local srcSpec = srcImg.spec
                    local wImg = srcSpec.width
                    local hImg = srcSpec.height

                    local trgImg = Image(srcSpec)
                    local trgPixels = trgImg:pixels()

                    for pixel in trgPixels do
                        -- When the kernel is out of bounds, sample
                        -- the central color, but do not tally alpha.
                        local xPx = pixel.x
                        local yPx = pixel.y
                        local hexSrc = pxArr[1 + xPx + yPx * wImg]

                        -- Subtract step to center the kernel
                        -- in the inner for loop.
                        local xSrc = xPx - krnStep
                        local ySrc = yPx - krnStep

                        local lSum = 0.0
                        local aSum = 0.0
                        local bSum = 0.0
                        local tSum = 0.0

                        local j = 0
                        while j < krnLen do
                            local xComp = xSrc + (j % wKrn)
                            local yComp = ySrc + (j // wKrn)
                            if yComp > -1 and yComp < hImg
                                and xComp > -1 and xComp < wImg then
                                local idxNgbr = xComp + yComp * wImg
                                local hexNgbr = pxArr[1 + idxNgbr]
                                local labNgbr = labDict[hexNgbr]
                                lSum = lSum + labNgbr.l
                                aSum = aSum + labNgbr.a
                                bSum = bSum + labNgbr.b
                                tSum = tSum + labNgbr.alpha
                            else
                                local labCtr = labDict[hexSrc]
                                lSum = lSum + labCtr.l
                                aSum = aSum + labCtr.a
                                bSum = bSum + labCtr.b
                            end
                            j = j + 1
                        end

                        local srgb = labToRgb(
                            lSum * denom, aSum * denom, bSum * denom, tSum * denom)
                        pixel(toHex(srgb))
                    end

                    local trgCel = activeSprite:newCel(
                        trgLayer, srcFrame,
                        trgImg, srcCel.position)
                    trgCel.opacity = srcCel.opacity
                end
            end
        end)

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