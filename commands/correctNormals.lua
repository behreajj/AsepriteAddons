local activeSprite = app.activeSprite
if not activeSprite then return end

local colorMode = activeSprite.colorMode
if colorMode ~= ColorMode.RGB then
    app.alert {
        title = "Error",
        text = "Only RGB color mode is supported." }
    return
end

local spriteWidth = activeSprite.width
local spriteHeight = activeSprite.height
local img = Image(spriteWidth, spriteHeight)

local activeFrame = app.activeFrame
    or activeSprite.frames[1]
img:drawSprite(activeSprite, activeFrame)
local pxItr = img:pixels()
for elm in pxItr do
    local hex = elm()
    local a = (hex >> 0x18) & 0xff
    if a > 0 then
        local b = (hex >> 0x10) & 0xff
        local g = (hex >> 0x08) & 0xff
        local r = hex & 0xff

        local x = (r + r - 255) * 0.003921568627451
        local y = (g + g - 255) * 0.003921568627451
        local z = (b + b - 255) * 0.003921568627451

        -- if z < 0.0 then z = 0.0 end

        local sqMag = x * x + y * y + z * z
        if sqMag > 0.000047 then
            local magInv = 1.0 / math.sqrt(sqMag)
            x = x * magInv
            y = y * magInv
            z = z * magInv
        else
            x = 0.0
            y = 0.0
            z = 0.0
        end

        local rNew = math.floor(x * 127.5 + 128.0)
        local gNew = math.floor(y * 127.5 + 128.0)
        local bNew = math.floor(z * 127.5 + 128.0)

        elm((a << 0x18)
            | (bNew << 0x10)
            | (gNew << 0x08)
            | rNew)
    else
        elm(0x0)
    end
end

activeSprite:newCel(
    activeSprite:newLayer(),
    activeFrame,
    img,
    Point(0, 0))