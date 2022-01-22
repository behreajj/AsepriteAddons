dofile("../../support/aseutilities.lua")

local angles = { "90_CCW", "180", "90_CW" }
local targets = { "ACTIVE", "ALL", "RANGE" }

local defaults = {
    target = "ACTIVE",
    angle = "180",
    xPivot = 0,
    yPivot = 0,
    pullFocus = false
}

local dlg = Dialog { title = "Simple Cel Rotate" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:combobox {
    id = "angle",
    label = "Angle:",
    option = defaults.angle,
    options = angles
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local activeSprite = app.activeSprite
        if activeSprite then

            local args = dlg.data
            local angle = args.angle or defaults.angle
            local target = args.target or defaults.target

            -- Determine cels by target preset.
            local cels = {}
            if target == "ACTIVE" then
                local activeCel = app.activeCel
                if activeCel then
                    cels[1] = activeCel
                end
            elseif target == "RANGE" then
                cels = app.range.cels
            else
                cels = activeSprite.cels
            end

            -- TODO: Rotate group of points around
            -- a central pivot. You'll need a perpCW
            -- and perpCCW function. Separate new
            -- cel position into a separate transaction
            -- from new image.

            -- Determine rotation function.
            local imgRotFunc = nil
            if angle == "90_CCW" then
                imgRotFunc = AseUtilities.rotate90
            elseif angle == "180" then
                imgRotFunc = AseUtilities.rotate180
            elseif angle == "90_CW" then
                imgRotFunc = AseUtilities.rotate270
            else
                imgRotFunc = function(a)
                    return Image(a), 0, 0
                end
            end

            -- local xMin = 100000
            -- local yMin = 100000
            -- local xMax = -100000
            -- local yMax = -100000

            local celsLen = #cels
            app.transaction(function()
                for i = 1, celsLen, 1 do
                    local cel = cels[i]
                    if cel then
                        local srcImg = cel.image
                        local wSrc = srcImg.width
                        local hSrc = srcImg.height
                        local xSrcHalf = wSrc * 0.5
                        local ySrcHalf = hSrc * 0.5

                        local trgImg, xDisp, yDisp = imgRotFunc(srcImg)
                        local wTrg = trgImg.width
                        local hTrg = trgImg.height
                        local xTrgHalf = wTrg * 0.5
                        local yTrgHalf = hTrg * 0.5

                        local celPos = cel.position
                        local xtlSrc = celPos.x
                        local ytlSrc = celPos.y

                        local xtlTrg = xtlSrc + xSrcHalf - xTrgHalf
                        local ytlTrg = ytlSrc + ySrcHalf - yTrgHalf
                        cel.position = Point(
                            Utilities.round(xtlTrg),
                            Utilities.round(ytlTrg))

                        cel.image = trgImg
                    end
                end
            end)

            app.refresh()
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