dofile("../support/aseutilities.lua")

local activeSprite = app.activeSprite
if activeSprite then
    local cels = activeSprite.cels
    local celsLen = #cels
    local trimImage = AseUtilities.trimImageAlpha
    for i = 1, celsLen, 1 do
        local cel = cels[i]
        local srcPos = cel.position
        local srcImg = cel.image
        if srcImg then
            local trgImg, x, y = trimImage(srcImg)
            cel.position = Point(srcPos.x + x, srcPos.y + y)
            cel.image = trgImg
        end
    end

    app.refresh()
else
    app.alert("There is no active sprite.")
end