dofile("../../support/clr.lua")

local defaults = {
    brightness = 0,
    contrast = 0,
    copyToLayer = true,
    pullFocus = false
}

local dlg = Dialog { title = "Adjust Bright Contrast" }

dlg:slider {
    id = "brightness",
    label = "Brightness:",
    min = -100,
    max = 100,
    value = defaults.brightness
}

dlg:newrow { always = false }

dlg:slider {
    id = "contrast",
    label = "Contrast:",
    min = -100,
    max = 100,
    value = defaults.contrast
}

dlg:newrow { always = false }

dlg:check {
    id = "copyToLayer",
    label = "As New Layer:",
    selected = defaults.copyToLayer
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert("There is no active sprite.")
            return
        end

        local activeSpec = activeSprite.spec
        local colorMode = activeSpec.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert("Only RGB color mode is supported.")
            return
        end

        local srcCel = app.activeCel
        if (not srcCel) then
            app.alert("There is no active cel.")
            return
        end

        local args = dlg.data
        local brightness = args.brightness or defaults.brightness
        local contrast = args.contrast or defaults.contrast
        local copyToLayer = args.copyToLayer

        local valBrip50 = brightness + 50.0
        local valCtr = 1.0 + (contrast * 0.01)

        local srcImg = srcCel.image
        local srcpxitr = srcImg:pixels()
        local srcDict = {}
        for elm in srcpxitr do
            srcDict[elm()] = true
        end

        local trgDict = {}
        for k, _ in pairs(srcDict) do
            local srgb = Clr.fromHex(k)
            local lab = Clr.sRgbaToLab(srgb)
            local srgbAdj = Clr.labTosRgba(
                ( lab.l - 50.0 ) * valCtr + valBrip50,
                lab.a, lab.b, lab.alpha)
            trgDict[k] = Clr.toHex(srgbAdj)
        end

        local trgImg = srcImg:clone()
        local trgpxitr = trgImg:pixels()
        for elm in trgpxitr do
            elm(trgDict[elm()])
        end

        if copyToLayer then
            app.transaction(function()
                local srcLayer = srcCel.layer

                -- Copy layer.
                local trgLayer = activeSprite:newLayer()
                local srcLayerName = "Layer"
                if srcLayer.name and #srcLayer.name > 0 then
                    srcLayerName = srcLayer.name
                end
                trgLayer.name = srcLayerName .. ".Adjusted"
                if srcLayer.opacity then
                    trgLayer.opacity = srcLayer.opacity
                end
                if srcLayer.blendMode then
                    trgLayer.blendMode = srcLayer.blendMode
                end

                -- Copy cel.
                local srcFrame = srcCel.frame or activeSprite.frames[1]
                local trgCel = activeSprite:newCel(
                    trgLayer, srcFrame,
                    trgImg, srcCel.position)
                trgCel.opacity = srcCel.opacity
            end)
        else
            srcCel.image = trgImg
        end

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