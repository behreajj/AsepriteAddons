dofile("../support/aseutilities.lua")

local activeSprite <const> = app.site.sprite
if not activeSprite then return end

local oldColorMode = activeSprite.colorMode
app.command.ChangePixelFormat { format = "rgb" }

local bkgLayer <const> = activeSprite.backgroundLayer
local bkgUnlocked = true
if bkgLayer then
    bkgUnlocked = bkgLayer.isEditable
    if bkgUnlocked then
        app.activeLayer = bkgLayer
        app.command.LayerFromBackground()
    end
end

local docPref <const> = app.preferences.document(activeSprite)
local bgPref <const> = docPref.bg
local size <const> = bgPref.size

local wGrid = size.width
local hGrid = size.height
if wGrid < 2 then wGrid = 2 end
if hGrid < 2 then hGrid = 2 end

local aAse <const> = bgPref.color1
local bAse <const> = bgPref.color2
local a = AseUtilities.aseColorToHex(aAse, ColorMode.RGB)
local b = AseUtilities.aseColorToHex(bAse, ColorMode.RGB)
a = 0xff000000 | a
b = 0xff000000 | b

-- TODO: Make this its own function in AseUtilities.
local activeSpec <const> = activeSprite.spec
local checker <const> = Image(activeSpec)
local pxItr <const> = checker:pixels()
for pixel in pxItr do
    local hex = b
    local x <const> = pixel.x
    local y <const> = pixel.y
    if (((x // wGrid) + (y // hGrid)) % 2) ~= 1 then
        hex = a
    end
    pixel(hex)
end

app.transaction("Bake Checker", function()
    local checkerLayer <const> = activeSprite:newLayer()
    checkerLayer.name = "Checker"

    local frames <const> = activeSprite.frames
    local lenFrames <const> = #frames
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