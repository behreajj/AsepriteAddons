dofile("../../support/clr.lua")

local grayHues = { "OMIT", "SHADING", "ZERO" }

local defaults = {
    lAdj = 0,
    cAdj = 0,
    hAdj = 0,
    aAdj = 0,
    grayHue = "OMIT",
    copyToLayer = true,
    pullFocus = false
}

local dlg = Dialog { title = "Adjust LCH" }

dlg:slider {
    id = "lAdj",
    label = "Lightness:",
    min = -100,
    max = 100,
    value = defaults.lAdj
}

dlg:newrow { always = false }

dlg:slider {
    id = "cAdj",
    label = "Chroma:",
    min = -135,
    max = 135,
    value = defaults.cAdj
}

dlg:newrow { always = false }

dlg:slider {
    id = "hAdj",
    label = "Hue:",
    min = -180,
    max = 180,
    value = defaults.hAdj
}

dlg:newrow { always = false }

dlg:slider {
    id = "aAdj",
    label = "Alpha:",
    min = -255,
    max = 255,
    value = defaults.aAdj
}

dlg:newrow { always = false }

dlg:combobox {
    id = "grayHue",
    label = "Grays:",
    option = defaults.grayHue,
    options = grayHues
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

        local srcCel = app.activeCel
        if not srcCel then
            app.alert("There is no active cel.")
            return
        end

        local specSprite = activeSprite.spec
        local colorMode = specSprite.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert("Only RGB color mode is supported.")
            return
        end

        local args = dlg.data
        local lAdj = args.lAdj or defaults.lAdj
        local cAdj = args.cAdj or defaults.cAdj
        local hAdj = args.hAdj or defaults.hAdj
        local aAdj = args.aAdj or defaults.aAdj
        local grayHue = args.grayHue or defaults.grayHue
        local copyToLayer = args.copyToLayer

        local useOmit = grayHue == "OMIT"
        local useZero = grayHue == "ZERO"
        local grayZero = 0.0

        -- Scale adjustments appropriately.
        local hScl = hAdj / 360.0
        local aScl = aAdj / 255.0

        local srcImg = srcCel.image
        local version = app.version
        local layerIsTilemap = false
        if version.major >= 1 and version.minor >= 3 then
            local activeLayer = app.activeLayer
            layerIsTilemap = activeLayer.isTilemap
            if layerIsTilemap then
                local tileSet = activeLayer.tileset
                srcImg = AseUtilities.tilesToImage(srcImg, tileSet, colorMode)
            end
        end

        local srcpxitr = srcImg:pixels()
        local srcDict = {}
        for elm in srcpxitr do
            srcDict[elm()] = true
        end

        local trgDict = {}
        for k, _ in pairs(srcDict) do
            local srgb = Clr.fromHex(k)
            if srgb.a > 0.0 then
                local lch = Clr.sRgbaToLch(srgb)
                local cNew = lch.c
                local hNew = lch.h
                if cNew < 1.0 then
                    if useOmit then
                        cNew = 0.0
                        hNew = 0.0
                    elseif useZero then
                        cNew = cNew + cAdj
                        hNew = grayZero + hScl
                    else
                        cNew = cNew + cAdj
                        hNew = hNew + hScl
                    end
                else
                    cNew = cNew + cAdj
                    hNew = hNew + hScl
                end

                local srgbNew = Clr.lchTosRgba(
                    lch.l + lAdj, cNew, hNew, lch.a + aScl)
                trgDict[k] = Clr.toHex(srgbNew)
            else
                trgDict[k] = 0x0
            end
        end

        local trgImg = srcImg:clone()
        local trgpxitr = trgImg:pixels()
        for elm in trgpxitr do
            elm(trgDict[elm()])
        end

        if copyToLayer or layerIsTilemap then
            app.transaction(function()
                local srcLayer = srcCel.layer

                -- Copy layer.
                local trgLayer = activeSprite:newLayer()
                local srcLayerName = "Layer"
                if #srcLayer.name > 0 then
                    srcLayerName = srcLayer.name
                end
                -- trgLayer.name = srcLayerName .. ".Adjusted"
                trgLayer.name = string.format(
                    "%s.L%+04d.C%+04d.H%+04d",
                    srcLayerName, lAdj, cAdj, hAdj)
                if srcLayer.opacity then
                    trgLayer.opacity = srcLayer.opacity
                end
                if srcLayer.blendMode then
                    trgLayer.blendMode = srcLayer.blendMode
                end
                -- trgLayer.parent = srcLayer.parent

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