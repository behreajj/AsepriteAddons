dofile("../../support/aseutilities.lua")

local angles = { "90", "180", "270" }
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

-- dlg:newrow { always = false }

-- dlg:slider {
--     id = "xPivot",
--     label = "Pivot:",
--     min = -100,
--     max = 100,
--     value = defaults.xPivot
-- }

-- dlg:slider {
--     id = "yPivot",
--     min = -100,
--     max = 100,
--     value = defaults.yPivot
-- }

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
            -- local xPivot = args.xPivot or defaults.xPivot
            -- local yPivot = args.yPivot or defaults.yPivot

            -- local xpSgn = xPivot * 0.01
            -- local ypSgn = yPivot * 0.01
            -- local xFac = xpSgn * 0.5 + 0.5
            -- local yFac = ypSgn * 0.5 + 0.5

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

            -- Determine rotation function.
            local rotFunc = nil
            if angle == "90" then
                rotFunc = AseUtilities.rotate90
            elseif angle == "180" then
                rotFunc = AseUtilities.rotate180
            elseif angle == "270" then
                rotFunc = AseUtilities.rotate270
            else
                rotFunc = function(a)
                    return Image(a), 0, 0
                end
            end

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

                        local trgImg, xDisp, yDisp = rotFunc(srcImg)
                        local wTrg = trgImg.width
                        local hTrg = trgImg.height
                        local xTrgHalf = wTrg * 0.5
                        local yTrgHalf = hTrg * 0.5

                        local celPos = cel.position
                        local xtlSrc = celPos.x
                        local ytlSrc = celPos.y

                        -- local xTrgPivot = (1.0 - xFac) * -xTrgHalf
                        --                        + xFac  *  xTrgHalf
                        -- local yTrgPivot = (1.0 - yFac) *  yTrgHalf
                        --                        + yFac  * -yTrgHalf

                        -- local xSrcPivot = (1.0 - xFac) * -xSrcHalf
                        --                        + xFac  *  xSrcHalf
                        -- local ySrcPivot = (1.0 - yFac) *  ySrcHalf
                        --                        + yFac  * -ySrcHalf

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