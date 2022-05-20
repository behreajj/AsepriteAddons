dofile("../support/aseutilities.lua")

local activeSprite = app.activeSprite
if not activeSprite then return end

local oldColorMode = activeSprite.colorMode
app.command.ChangePixelFormat { format = "rgb" }

activeSprite.transparentColor = 0

local hexesProfile = AseUtilities.asePalettesToHexArr(activeSprite.palettes)
local uniques, _ = Utilities.uniqueColors(hexesProfile, true)
local masked = Utilities.prependMask(uniques)

local aseColors = {}
local lenAseColors = #masked
for i = 1, lenAseColors, 1 do
    aseColors[i] = AseUtilities.hexToAseColor(masked[i])
end

local palettes = activeSprite.palettes
local palettesLen = #palettes

-- It seems safe to assign the same Aseprite color
-- to multiple palettes because they are copied by
-- value, not passed by reference...?
app.transaction(function()
    for i = 1, palettesLen, 1 do
        local palette = palettes[i]
        palette:resize(lenAseColors)
        for j = 1, lenAseColors, 1 do
            local aseColor = aseColors[j]
            palette:setColor(j - 1, aseColor)
        end
    end
end)

AseUtilities.changePixelFormat(oldColorMode)
app.refresh()
