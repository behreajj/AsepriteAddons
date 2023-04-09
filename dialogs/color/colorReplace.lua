dofile("../../support/aseutilities.lua")

local targets = { "ACTIVE", "ALL", "RANGE", "SELECTION" }

local defaults = {
    -- TODO: Backport to alpha scale and
    -- expand iamge to main branch?
    target = "ACTIVE",
    includeLocked = false,
    includeHidden = false,
    tolerance = 0,
    pullFocus = true
}

local function distSqInclAlpha(a, b, alphaScale)
    -- Scale alpha to be at least somewhat
    -- proportional to other channels.
    local dt = alphaScale * (b.alpha - a.alpha)
    local dl = b.l - a.l
    local da = b.a - a.a
    local db = b.b - a.b
    return dt * dt + dl * dl + da * da + db * db
end

local function expandImageToCanvas(cel, sprite)
    local celPos = cel.position
    local xSrc = celPos.x
    local ySrc = celPos.y

    local celImg = cel.image
    local celSpec = celImg.spec

    local xMin = math.min(0, xSrc)
    local yMin = math.min(0, ySrc)
    local xMax = math.max(sprite.width - 1,
        xSrc + celSpec.width - 1)
    local yMax = math.max(sprite.height - 1,
        ySrc + celSpec.height - 1)

    local wTrg = 1 + xMax - xMin
    local hTrg = 1 + yMax - yMin
    if wTrg < 1 or hTrg < 1 then
        return celImg, xSrc, ySrc
    end

    local trgSpec = ImageSpec {
        width = wTrg,
        height = hTrg,
        colorMode = celSpec.colorMode,
        transparentColor = celSpec.transparentColor
    }
    trgSpec.colorSpace = celSpec.colorSpace
    local trgImg = Image(trgSpec)
    trgImg:drawImage(celImg,
        Point(xSrc - xMin, ySrc - yMin))

    return trgImg, xMin, yMin
end

local function swapColors(dialog)
    local args = dialog.data
    local frColor = args.fromColor --[[@as Color]]
    local toColor = args.toColor --[[@as Color]]
    dialog:modify {
        id = "fromColor",
        color = AseUtilities.aseColorCopy(
            toColor, "")
    }
    dialog:modify {
        id = "toColor",
        color = AseUtilities.aseColorCopy(
            frColor, "")
    }
end

local dlg = Dialog { title = "Replace Color" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:check {
    id = "includeLocked",
    label = "Include:",
    text = "&Locked",
    selected = defaults.includeLocked
}

dlg:check {
    id = "includeHidden",
    text = "&Hidden",
    selected = defaults.includeHidden
}

dlg:newrow { always = false }

dlg:color {
    id = "fromColor",
    label = "From:",
    -- color = app.preferences.color_bar.fg_color
    color = Color { r = 255, g = 255, b = 255, a = 255 }
}

dlg:newrow { always = false }

dlg:color {
    id = "toColor",
    label = "To:",
    -- color = app.preferences.color_bar.bg_color
    color = Color { r = 0, g = 0, b = 0, a = 0 }
}

dlg:newrow { always = false }

dlg:slider {
    id = "tolerance",
    label = "Tolerance:",
    min = 0,
    max = 255,
    value = defaults.tolerance
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        -- See: https://github.com/aseprite/aseprite/issues/2563
        -- TODO: Make this consistent with colorSelect?
        -- Maybe have different distance metrics?

        local activeSprite = app.activeSprite
        if not activeSprite then return end
        local activeLayer = app.activeLayer
        local activeFrame = app.activeFrame --[[@as Frame]]

        local args = dlg.data
        local target = args.target
            or defaults.target --[[@as string]]
        local frColor = args.fromColor --[[@as Color]]
        local toColor = args.toColor --[[@as Color]]
        local tolerance = args.tolerance
            or defaults.tolerance --[[@as integer]]
        local includeLocked = args.includeLocked --[[@as boolean]]
        local includeHidden = args.includeHidden --[[@as boolean]]
        local includeTiles = false
        local includeBkg = toColor.alpha >= 255
        local exactSearch = tolerance <= 0
        local activeSpec = activeSprite.spec
        local colorMode = activeSpec.colorMode

        local trgCels = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            includeLocked, includeHidden, includeTiles, includeBkg)
        local lenTrgCels = #trgCels

        app.transaction("Replace Color", function()
            if exactSearch then
                local frInt = AseUtilities.aseColorToHex(
                    frColor, colorMode)
                local toInt = AseUtilities.aseColorToHex(
                    toColor, colorMode)
                if frInt == toInt then return end
                local useExpand = frInt == activeSpec.transparentColor

                local i = 0
                while i < lenTrgCels do
                    i = i + 1
                    local cel = trgCels[i]
                    local trgImg = nil
                    if useExpand then
                        local exp, xtl, ytl = expandImageToCanvas(
                            cel, activeSprite)
                        trgImg = exp
                        cel.position = Point(xtl, ytl)
                    else
                        trgImg = cel.image:clone()
                    end

                    local pxItr = trgImg:pixels()
                    for pixel in pxItr do
                        if pixel() == frInt then pixel(toInt) end
                    end
                    cel.image = trgImg
                end
            else
                app.command.ChangePixelFormat { format = "rgb" }

                local frInt = AseUtilities.aseColorToHex(
                    frColor, ColorMode.RGB)
                local toInt = AseUtilities.aseColorToHex(
                    toColor, ColorMode.RGB)

                local fromHex = Clr.fromHex
                local sRgbaToLab = Clr.sRgbToSrLab2
                local distSq = distSqInclAlpha

                local tScl = 100.0
                local tolsq = tolerance * tolerance
                local frLab = sRgbaToLab(fromHex(frInt))

                local zeroLab = { l = 0.0, a = 0.0, b = 0.0, alpha = 0.0 }
                local useExpand = distSq(frLab, zeroLab, tScl) <= tolsq

                ---@type table<integer, integer>
                local dict = {}

                local i = 0
                while i < lenTrgCels do
                    i = i + 1
                    local cel = trgCels[i]

                    local srcImg = cel.image
                    local srcPxItr = srcImg:pixels()
                    for srcPixel in srcPxItr do
                        local srcHex = srcPixel()
                        if not dict[srcHex] then
                            local srcClr = fromHex(srcHex)
                            local srcLab = sRgbaToLab(srcClr)
                            if distSq(srcLab, frLab, tScl) <= tolsq then
                                dict[srcHex] = toInt
                            else
                                dict[srcHex] = srcHex
                            end
                        end
                    end

                    local trgImg = nil
                    if useExpand then
                        local exp, xtl, ytl = expandImageToCanvas(
                            cel, activeSprite)
                        trgImg = exp
                        cel.position = Point(xtl, ytl)
                    else
                        trgImg = srcImg:clone()
                    end

                    local trgPxItr = trgImg:pixels()
                    for trgPixel in trgPxItr do
                        trgPixel(dict[trgPixel()])
                    end

                    cel.image = trgImg
                end

                AseUtilities.changePixelFormat(colorMode)
            end
        end)

        -- swapColors(dlg)
        app.refresh()
    end
}

dlg:button {
    id = "swapColors",
    text = "&SWAP",
    focus = false,
    onclick = function() swapColors(dlg) end
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