local site <const> = app.site
local sprite <const> = site.sprite
if not sprite then return end

local frObjs <const> = sprite.frames
local lenFrObjs <const> = #frObjs
if lenFrObjs <= 1 then return end

local frObj <const> = site.frame
if not frObj then return end
local frIdx <const> = frObj.frameNumber

local layer <const> = site.layer
if not layer then return end

local cel <const> = layer:cel(frIdx)
if not cel then return end

local i = frIdx
local searchLeft = true
while i > 1 and searchLeft do
    i = i - 1
    if layer:cel(i) then
        searchLeft = false
        i = i + 1
    end
end

local j = frIdx
local searchRight = true
while j < lenFrObjs and searchRight do
    j = j + 1
    if layer:cel(j) then
        searchRight = false
        j = j - 1
    end
end

local srcImg <const> = Image(cel.image)
local srcPos <const> = cel.position
local srcColor <const> = cel.color
local srcData <const> = cel.data
local srcOpacity <const> = cel.opacity
local srcZIndex <const> = cel.zIndex

local len <const> = 1 + j - i
if len <= 1 then return end

app.transaction("Fill Empty Cels", function()
    local k = 0
    while k < len do
        local trgCel <const> = sprite:newCel(
            layer, i + k, srcImg, srcPos)
        trgCel.color = AseUtilities.aseColorCopy(srcColor, "")
        trgCel.data = srcData
        trgCel.opacity = srcOpacity
        trgCel.zIndex = srcZIndex
        k = k + 1
    end
end)

app.refresh()