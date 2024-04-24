dofile("../support/aseutilities.lua")

local sprite <const> = app.sprite
if not sprite then return end

local layer <const> = app.layer or sprite.layers[1]
if layer.isGroup then return end

local origClr = Clr.clearBlack()
local destClr = Clr.clearBlack()
local layerColor <const> = layer.color
if layerColor.alpha ~= 0
    or layerColor.blue ~= 0
    or layerColor.green ~= 0
    or layerColor.red ~= 0 then
    origClr = AseUtilities.aseColorToClr(layerColor)
    destClr = AseUtilities.aseColorToClr(layerColor)
else
    origClr = AseUtilities.aseColorToClr(app.fgColor)
    app.command.SwitchColors()
    destClr = AseUtilities.aseColorToClr(app.fgColor)
    app.command.SwitchColors()
end

local frObjs <const> = sprite.frames
local lenFrames <const> = #frObjs
local toFac <const> = lenFrames > 1
    and 1.0 / (lenFrames - 1.0)
    or 0.0
local mixSrLab2 <const> = Clr.mixSrLab2
local clrToColor <const> = AseUtilities.clrToAseColor

app.transaction("TL Color Row", function()
    local i = 0
    while i < lenFrames do
        i = i + 1
        local frObj <const> = frObjs[i]
        local cel <const> = layer:cel(frObj)
        if cel then
            local fac <const> = (i - 1.0) * toFac
            local clr <const> = mixSrLab2(origClr, destClr, fac)
            cel.color = clrToColor(clr)
        end
    end
end)

app.refresh()