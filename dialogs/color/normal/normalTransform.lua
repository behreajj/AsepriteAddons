dofile("../../../support/aseutilities.lua")
dofile("../../../support/normalutilities.lua")

-- The canvas or layer target.
local majorTargets <const> = {
    "ACTIVE",
    "ALL",
    "RANGE",
    "SELECTION",
}

-- The frame target.
local minorTargets <const> = {
    "ACTIVE",
    "ALL",
    "RANGE",
    "TAG"
}

local unitOptions <const> = { "PERCENT", "PIXEL" }

local defaults <const> = {
    -- TODO: Support rotate x and y.
    majorTarget = "ACTIVE",
    minorTarget = "ACTIVE",
    degrees = 90,
    lockAspect = true,
    pxWidth = 64,
    pxHeight = 64,
    prcWidth = 100,
    prcHeight = 100,
    units = "PERCENT",
    coordSystem = "TOP_LEFT",
    selTargetRevert = "ACTIVE",
}

local dlg <const> = Dialog { title = "Transform Normals" }

dlg:combobox {
    id = "majorTarget",
    label = "Target:",
    option = defaults.majorTarget,
    options = majorTargets,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:combobox {
    id = "minorTarget",
    label = "Frames:",
    option = defaults.minorTarget,
    options = minorTargets,
    hexpand = false,
}

dlg:separator { id = "rotateSep" }

dlg:slider {
    id = "degrees",
    label = "Degrees:",
    min = 0,
    max = 360,
    value = defaults.degrees,
}

dlg:newrow { always = false }

dlg:button {
    id = "zRotateButton",
    text = "&ROTATE",
    focus = true,
    onclick = function()
        -- Early returns.
        -- Early returns.
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end
        if activeSprite.colorMode ~= ColorMode.RGB then
            return
        end
        local activeLayer <const> = site.layer

        -- Unpack arguments.
        local args <const> = dlg.data
        local majorTarget <const> = args.majorTarget
            or defaults.majorTarget --[[@as string]]
        local minorTarget <const> = args.minorTarget
            or defaults.minorTarget --[[@as string]]
        local degrees = args.degrees
            or defaults.degrees --[[@as integer]]

        local includeBkg <const> = degrees == 180
            or (activeSprite.width == activeSprite.height
                and (degrees == 90 or degrees == 270))
        local trgFrames <const> = Utilities.flatArr2(
            AseUtilities.getFrames(
                activeSprite, minorTarget))
        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, trgFrames, majorTarget,
            false, false, false, includeBkg)
        local lenCels <const> = #cels

        degrees = 360 - degrees
        local query <const> = AseUtilities.DIMETRIC_ANGLES[degrees]
        local radians <const> = query
            or (0.017453292519943 * degrees)

        -- Avoid trigonometric functions in while loop below.
        -- Cache sine and cosine here, then use formula for
        -- vector rotation.
        local cosa <const> = math.cos(radians)
        local sina <const> = -math.sin(radians)

        -- Cache methods.
        local floor <const> = math.floor
        local trimAlpha <const> = AseUtilities.trimImageAlpha
        local rotz <const> = NormalUtilities.rotateImageZInternal

        app.transaction("Rotate Cels", function()
            local i = 0
            while i < lenCels do
                i = i + 1
                local cel <const> = cels[i]
                local srcImg <const> = cel.image
                if not srcImg:isEmpty() then
                    local celPos <const> = cel.position
                    local xSrcCtr <const> = celPos.x + srcImg.width * 0.5
                    local ySrcCtr <const> = celPos.y + srcImg.height * 0.5

                    local trgImg = rotz(srcImg, cosa, sina)
                    local xtlTrg = xSrcCtr - trgImg.width * 0.5
                    local ytlTrg = ySrcCtr - trgImg.height * 0.5

                    local xTrim = 0
                    local yTrim = 0
                    trgImg, xTrim, yTrim = trimAlpha(trgImg, 0, 0)
                    xtlTrg = xtlTrg + xTrim
                    ytlTrg = ytlTrg + yTrim

                    cel.position = Point(floor(xtlTrg), floor(ytlTrg))
                    cel.image = trgImg
                end -- End source image not empty.
            end     -- End cels loop.
        end)        -- End transaction.

        if majorTarget == "SELECTION" then
            dlg:modify {
                id = "majorTarget",
                option = defaults.selTargetRevert
            }
            activeSprite.selection:deselect()
        end
        app.refresh()
    end
}

dlg:separator { id = "scaleSep" }

dlg:number {
    id = "pxWidth",
    label = "Pixels:",
    text = string.format("%d", defaults.pxWidth),
    decimals = 0,
    visible = defaults.units == "PIXEL",
    onchange = function()
        local args <const> = dlg.data
        local lockAspect <const> = args.lockAspect --[[@as boolean]]
        if lockAspect then
            local pxWidth <const> = args.pxWidth --[[@as integer]]
            dlg:modify {
                id = "pxHeight",
                text = string.format("%d", pxWidth)
            }
        end
    end
}

dlg:number {
    id = "pxHeight",
    text = string.format("%d", defaults.pxHeight),
    decimals = 0,
    visible = defaults.units == "PIXEL",
    onchange = function()
        local args <const> = dlg.data
        local lockAspect <const> = args.lockAspect --[[@as boolean]]
        if lockAspect then
            local pxHeight <const> = args.pxHeight --[[@as integer]]
            dlg:modify {
                id = "pxWidth",
                text = string.format("%d", pxHeight)
            }
        end
    end
}

dlg:number {
    id = "prcWidth",
    label = "Percent:",
    text = string.format("%.2f", defaults.prcWidth),
    decimals = 2,
    visible = defaults.units == "PERCENT",
    onchange = function()
        local args <const> = dlg.data
        local lockAspect <const> = args.lockAspect --[[@as boolean]]
        if lockAspect then
            local prcWidth <const> = args.prcWidth --[[@as number]]
            dlg:modify {
                id = "prcHeight",
                text = string.format("%.2f", prcWidth)
            }
        end
    end
}

dlg:number {
    id = "prcHeight",
    text = string.format("%.2f", defaults.prcHeight),
    decimals = 2,
    visible = defaults.units == "PERCENT",
    onchange = function()
        local args <const> = dlg.data
        local lockAspect <const> = args.lockAspect --[[@as boolean]]
        if lockAspect then
            local prcHeight <const> = args.prcHeight --[[@as number]]
            dlg:modify {
                id = "prcWidth",
                text = string.format("%.2f", prcHeight)
            }
        end
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "units",
    label = "Units:",
    option = defaults.units,
    options = unitOptions,
    hexpand = false,
    onchange = function()
        local args <const> = dlg.data
        local unitType <const> = args.units --[[@as string]]
        local ispx <const> = unitType == "PIXEL"
        local ispc <const> = unitType == "PERCENT"
        dlg:modify { id = "pxWidth", visible = ispx }
        dlg:modify { id = "pxHeight", visible = ispx }
        dlg:modify { id = "prcWidth", visible = ispc }
        dlg:modify { id = "prcHeight", visible = ispc }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "lockAspect",
    label = "Lock:",
    text = "&Aspect",
    selected = defaults.lockAspect,
    hexpand = false,
    onclick = function()
        local args <const> = dlg.data
        local lockAspect <const> = args.lockAspect --[[@as boolean]]
        if lockAspect then
            local pxWidth <const> = args.pxWidth --[[@as integer]]
            local pxHeight <const> = args.pxHeight --[[@as integer]]
            if pxWidth ~= pxHeight then
                local mx <const> = math.max(pxWidth, pxHeight)
                local mxStr <const> = string.format("%d", mx)
                dlg:modify { id = "pxWidth", text = mxStr }
                dlg:modify { id = "pxHeight", text = mxStr }
            end

            local prcWidth <const> = args.prcWidth --[[@as number]]
            local prcHeight <const> = args.prcHeight --[[@as number]]
            if prcWidth ~= prcHeight then
                local mx <const> = math.max(prcWidth, prcHeight)
                local mxStr <const> = string.format("%.2f", mx)
                dlg:modify { id = "prcWidth", text = mxStr }
                dlg:modify { id = "prcHeight", text = mxStr }
            end
        end
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "fliphButton",
    text = "FLIP &H",
    focus = false,
    onclick = function()
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end
        local activeLayer <const> = site.layer

        local args <const> = dlg.data
        local majorTarget <const> = args.majorTarget
            or defaults.majorTarget --[[@as string]]
        local minorTarget <const> = args.minorTarget
            or defaults.minorTarget --[[@as string]]

        local trgFrames <const> = Utilities.flatArr2(
            AseUtilities.getFrames(
                activeSprite, minorTarget))
        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, trgFrames, majorTarget,
            false, false, false, true)
        local lenCels <const> = #cels
        local flipx <const> = NormalUtilities.flipImageX

        app.transaction("Flip H", function()
            local i = 0
            while i < lenCels do
                i = i + 1
                local cel <const> = cels[i]
                cel.image = flipx(cel.image)
            end
        end)

        if majorTarget == "SELECTION" then
            dlg:modify {
                id = "majorTarget",
                option = defaults.selTargetRevert
            }
            activeSprite.selection:deselect()
        end
        app.refresh()
    end
}

dlg:button {
    id = "flipvButton",
    text = "FLIP &V",
    focus = false,
    onclick = function()
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end
        local activeLayer <const> = site.layer

        local args <const> = dlg.data
        local majorTarget <const> = args.majorTarget
            or defaults.majorTarget --[[@as string]]
        local minorTarget <const> = args.minorTarget
            or defaults.minorTarget --[[@as string]]

        local trgFrames <const> = Utilities.flatArr2(
            AseUtilities.getFrames(
                activeSprite, minorTarget))
        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, trgFrames, majorTarget,
            false, false, false, true)
        local lenCels <const> = #cels
        local flipy <const> = NormalUtilities.flipImageY

        app.transaction("Flip V", function()
            local i = 0
            while i < lenCels do
                i = i + 1
                local cel <const> = cels[i]
                cel.image = flipy(cel.image)
            end
        end)

        if majorTarget == "SELECTION" then
            dlg:modify {
                id = "majorTarget",
                option = defaults.selTargetRevert
            }
            activeSprite.selection:deselect()
        end
        app.refresh()
    end
}

dlg:button {
    id = "scaleButton",
    text = "&SCALE",
    focus = false,
    onclick = function()
        -- Early returns.
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end
        local activeLayer <const> = site.layer

        -- Cache methods.
        local abs <const> = math.abs
        local max <const> = math.max
        local floor <const> = math.floor

        -- Unpack arguments.
        local args <const> = dlg.data
        local majorTarget <const> = args.majorTarget
            or defaults.majorTarget --[[@as string]]
        local minorTarget <const> = args.minorTarget
            or defaults.minorTarget --[[@as string]]
        local unitType <const> = args.units
            or defaults.units --[[@as string]]
        local wPrc = args.prcWidth
            or defaults.prcWidth --[[@as number]]
        local hPrc = args.prcHeight
            or defaults.prcHeight --[[@as number]]
        local wPxl = args.pxWidth
            or activeSprite.width --[[@as integer]]
        local hPxl = args.pxHeight
            or activeSprite.height --[[@as integer]]

        wPxl = floor(0.5 + abs(wPxl))
        hPxl = floor(0.5 + abs(hPxl))
        wPrc = 0.01 * abs(wPrc)
        hPrc = 0.01 * abs(hPrc)

        local usePercent <const> = unitType == "PERCENT"
        local trgFrames <const> = Utilities.flatArr2(
            AseUtilities.getFrames(
                activeSprite, minorTarget))
        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, trgFrames, majorTarget,
            false, false, false, false)
        local lenCels = #cels

        local resize <const> = NormalUtilities.resizeImageNearest

        app.transaction("Scale Cels", function()
            local o = 0
            while o < lenCels do
                o = o + 1
                local cel <const> = cels[o]
                local srcImg <const> = cel.image
                if not srcImg:isEmpty() then
                    local celPos <const> = cel.position
                    local xSrcCtr <const> = celPos.x + srcImg.width * 0.5
                    local ySrcCtr <const> = celPos.y + srcImg.height * 0.5

                    local wTrg = wPxl
                    local hTrg = hPxl
                    if usePercent then
                        wTrg = max(1, floor(0.5 + srcImg.width * wPrc))
                        hTrg = max(1, floor(0.5 + srcImg.height * hPrc))
                    end

                    local trgImg <const> = resize(srcImg, wTrg, hTrg)
                    local xtlTrg <const> = xSrcCtr - trgImg.width * 0.5
                    local ytlTrg <const> = ySrcCtr - trgImg.height * 0.5

                    cel.position = Point(floor(xtlTrg), floor(ytlTrg))
                    cel.image = trgImg
                end
            end
        end)

        if majorTarget == "SELECTION" then
            dlg:modify {
                id = "majorTarget",
                option = defaults.selTargetRevert
            }
            activeSprite.selection:deselect()
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

dlg:show {
    autoscrollbars = true,
    wait = false
}

local dlgBounds <const> = dlg.bounds
dlg.bounds = Rectangle(
    dlgBounds.x * 2 - 52, dlgBounds.y,
    dlgBounds.w, dlgBounds.h)