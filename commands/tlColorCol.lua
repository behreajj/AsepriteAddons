dofile("../support/aseutilities.lua")

local sprite <const> = app.sprite
if not sprite then return end

local frame <const> = app.frame or sprite.frames[1]

local leaves <const> = AseUtilities.getLayerHierarchy(
    sprite, true, true, true, true)
local lenLeaves <const> = #leaves
if lenLeaves <= 0 then return end

local origClr = Clr.clearBlack()
local destClr = Clr.clearBlack()
local appTag <const> = app.tag
if appTag then
    origClr = AseUtilities.aseColorToClr(appTag.color)
    destClr = AseUtilities.aseColorToClr(appTag.color)
else
    origClr = AseUtilities.aseColorToClr(app.fgColor)
    app.command.SwitchColors()
    destClr = AseUtilities.aseColorToClr(app.fgColor)
    app.command.SwitchColors()
end

app.transaction("TL Color Column", function()
    local toFac <const> = lenLeaves > 1
        and 1.0 / (lenLeaves - 1.0)
        or 0.0
    local mixSrLab2 <const> = Clr.mixSrLab2
    local clrToColor <const> = AseUtilities.clrToAseColor
    local i = 0
    while i < lenLeaves do
        i = i + 1
        local leaf <const> = leaves[i]
        local cel <const> = leaf:cel(frame)
        if cel then
            local fac <const> = (i - 1.0) * toFac
            local clr <const> = mixSrLab2(origClr, destClr, fac)
            cel.color = clrToColor(clr)
        end
    end
end)

app.refresh()