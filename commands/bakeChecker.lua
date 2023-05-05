dofile("../support/aseutilities.lua")

local activeSprite = app.activeSprite
if not activeSprite then return end

local oldColorMode = activeSprite.colorMode
app.command.ChangePixelFormat { format = "rgb" }

local bkgLayer = activeSprite.backgroundLayer
local bkgUnlocked = true
if bkgLayer then
    bkgUnlocked = bkgLayer.isEditable
    if bkgUnlocked then
        app.activeLayer = bkgLayer
        app.command.LayerFromBackground()
    end
end

local docPref = app.preferences.document(activeSprite)
local bgPref = docPref.bg
local size = bgPref.size

local wGrid = size.width
local hGrid = size.height
if wGrid < 2 then wGrid = 2 end
if hGrid < 2 then hGrid = 2 end

local aAse = bgPref.color1
local bAse = bgPref.color2
local a = AseUtilities.aseColorToHex(aAse, ColorMode.RGB)
local b = AseUtilities.aseColorToHex(bAse, ColorMode.RGB)
a = 0xff000000 | a
b = 0xff000000 | b

-- TODO: Make this its own function in AseUtilities.
local activeSpec = activeSprite.spec
local checker = Image(activeSpec)
local pxItr = checker:pixels()
for pixel in pxItr do
    local hex = b
    local x = pixel.x
    local y = pixel.y
    if (((x // wGrid) + (y // hGrid)) % 2) ~= 1 then
        hex = a
    end
    pixel(hex)
end

app.transaction("Bake Checker", function()
    local checkerLayer = activeSprite:newLayer()
    checkerLayer.name = "Checker"

    local frames = activeSprite.frames
    local lenFrames = #frames
    local i = 0
    while i < lenFrames do
        i = i + 1
        activeSprite:newCel(
            checkerLayer,
            frames[i],
            checker)
    end

    if bkgUnlocked then
        app.command.BackgroundFromLayer()
    end
    AseUtilities.changePixelFormat(oldColorMode)
end)