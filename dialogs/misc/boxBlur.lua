dofile("../../support/aseutilities.lua")

-- local blurTypes = { "BOX", "DIRECTED" }
local targets = { "ACTIVE", "ALL", "RANGE" }
local delOptions = { "DELETE_CELS", "DELETE_LAYER", "HIDE", "NONE" }

local defaults = {
    -- Support other kinds of blur?
    blurType = "BOX",
    target = "ACTIVE",
    delSrc = "NONE",
    kernelStep = 1,
    angle = 0,
    pullFocus = false
}

local dlg = Dialog { title = "Blur" }

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

-- dlg:combobox {
--     id = "blurType",
--     label = "Type:",
--     option = defaults.blurType,
--     options = blurTypes,
--     onchange = function()
--         local state = dlg.data.blurType
--         dlg:modify {
--             id = "angle",
--             visible = state == "DIRECTED"
--         }
--     end
-- }

-- dlg:newrow { always = false }

dlg:slider {
    id = "kernelStep",
    label = "Step:",
    min = 1,
    max = 8,
    value = defaults.kernelStep
}

dlg:newrow { always = false }

-- dlg:slider {
--     id = "angle",
--     label = "Angle:",
--     min = 0,
--     max = 360,
--     value = defaults.angle,
--     visible = defaults.blurType == "DIRECTED"
-- }

-- dlg:newrow { always = false }

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
        -- local blurType = args.blurType
        --     or defaults.blurType --[[@as string]]
        local krnStep = args.kernelStep
            or defaults.kernelStep --[[@as integer]]
        local delSrcStr = args.delSrc
            or defaults.delSrc --[[@as string]]

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
        trgLayer.parent = srcLayer.parent
        trgLayer.opacity = srcLayer.opacity
        trgLayer.blendMode = srcLayer.blendMode

        -- Create SRLAB2 dictionary outside of while loop
        -- to minimize re-calculation of SR LAB2 colors for
        -- similar images across multiple frames.
        local labDict = {}
        labDict[0] = { l = 0.0, a = 0.0, b = 0.0, alpha = 0.0 }

        -- Find width and flat length of kernel.
        -- All cells of kernel are weighted equally.
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
                    for srcPixel in srcPixels do
                        local hex = srcPixel()
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

                    for trgPixel in trgPixels do
                        -- When the kernel is out of bounds, sample
                        -- the central color, but do not tally alpha.
                        local xPx = trgPixel.x
                        local yPx = trgPixel.y
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
                            lSum * denom,
                            aSum * denom,
                            bSum * denom,
                            tSum * denom)
                        trgPixel(toHex(srgb))
                    end

                    local trgCel = activeSprite:newCel(
                        trgLayer, srcFrame,
                        trgImg, srcCel.position)
                    trgCel.opacity = srcCel.opacity
                end
            end
        end)

        if delSrcStr == "HIDE" then
            srcLayer.isVisible = false
        elseif (not srcLayer.isBackground) then
            if delSrcStr == "DELETE_LAYER" then
                activeSprite:deleteLayer(srcLayer)
            elseif delSrcStr == "DELETE_CELS" then
                app.transaction(function()
                    local idxDel = 0
                    while idxDel < lenFrames do
                        idxDel = idxDel + 1
                        local frame = frames[idxDel]
                        if srcLayer:cel(frame) then
                            activeSprite:deleteCel(srcLayer, frame)
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