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
local i = 0
while i < lenAseColors do i = i + 1
    aseColors[i] = AseUtilities.hexToAseColor(masked[i])
end

local palettes = activeSprite.palettes
local palettesLen = #palettes

-- It seems safe to assign the same Aseprite color
-- to multiple palettes because they are copied by
-- value, not passed by reference...?
app.transaction(function()
    local j = 0
    while j < palettesLen do j = j + 1
        local palette = palettes[j]
        palette:resize(lenAseColors)
        local k = 0
        while k < lenAseColors do k = k + 1
            local aseColor = aseColors[k]
            palette:setColor(k - 1, aseColor)
        end
    end
end)

AseUtilities.changePixelFormat(oldColorMode)
app.refresh()
