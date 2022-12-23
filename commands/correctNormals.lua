local activeSprite = app.activeSprite
if not activeSprite then return end

local colorMode = activeSprite.colorMode
if colorMode ~= ColorMode.RGB then
    app.alert {
        title = "Error",
        text = "Only RGB color mode is supported."
    }
    return
end

local spriteWidth = activeSprite.width
local spriteHeight = activeSprite.height
local img = Image(spriteWidth, spriteHeight)

local sqrt = math.sqrt
local floor = math.floor

local activeFrame = app.activeFrame
    or activeSprite.frames[1]
img:drawSprite(activeSprite, activeFrame)
local pxItr = img:pixels()
for pixel in pxItr do
    local hex = pixel()
    local aMask = hex & 0xff000000
    if aMask ~= 0 then
        local b = (hex >> 0x10) & 0xff
        local g = (hex >> 0x08) & 0xff
        local r = hex & 0xff

        local x = (r + r - 255) * 0.003921568627451
        local y = (g + g - 255) * 0.003921568627451
        local z = (b + b - 255) * 0.003921568627451

        -- if z < 0.0 then z = 0.0 end

        local sqMag = x * x + y * y + z * z
        if sqMag > 0.000047 then
            local invMag = 127.5 / sqrt(sqMag)
            pixel(aMask
                | (floor(z * invMag + 128.0) << 0x10)
                | (floor(y * invMag + 128.0) << 0x08)
                | floor(x * invMag + 128.0))
        else
            pixel(0xff808080)
        end
    else
        pixel(0x0)
    end
end

activeSprite:newCel(
    activeSprite:newLayer(),
    activeFrame, img)