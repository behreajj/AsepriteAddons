dofile("../support/aseutilities.lua")

local activeSprite = app.activeSprite
if not activeSprite then return end

local oldColorMode = activeSprite.colorMode
app.command.ChangePixelFormat { format = "rgb" }

local activeSpec = activeSprite.spec

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

local checker = Image(activeSpec)
local pxItr = checker:pixels()
for elm in pxItr do
    local hex = b
    local x = elm.x
    local y = elm.y
    if (((x // wGrid) + (y // hGrid)) % 2) ~= 1 then
        hex = a
    end
    elm(hex)
end

local checkerLayer = activeSprite:newLayer()

local frames = activeSprite.frames
local lenFrames = #frames
local i = 0
while i < lenFrames do i = i + 1
    activeSprite:newCel(
        checkerLayer,
        frames[i],
        checker)
end

app.command.BackgroundFromLayer()
AseUtilities.changePixelFormat(oldColorMode)