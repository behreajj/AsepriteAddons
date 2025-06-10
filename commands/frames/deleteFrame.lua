local site <const> = app.site
local activeSprite <const> = site.sprite
if not activeSprite then return end

local range <const> = app.range
if range.sprite ~= activeSprite then return end
local rangeFrObjs <const> = range.frames
local lenRangeFrObjs <const> = #rangeFrObjs

---@type integer[]
local rangeFrIdcs <const> = {}
local minFrIdx = 2147483647
local h = 0
while h < lenRangeFrObjs do
    h = h + 1
    local rangeFrObj <const> = rangeFrObjs[h]
    local rangeFrIdx <const> = rangeFrObj.frameNumber
    if rangeFrIdx < minFrIdx then minFrIdx = rangeFrIdx end
    rangeFrIdcs[h] = rangeFrIdx
end

app.transaction("Delete Frames", function()
    local i = lenRangeFrObjs + 1
    while i > 1 do
        i = i - 1
        activeSprite:deleteFrame(rangeFrIdcs[i])
    end
end)

app.frame = activeSprite.frames[math.max(1, minFrIdx - 1)]
app.refresh()