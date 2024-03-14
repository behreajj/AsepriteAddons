local site <const> = app.site
local sprite <const> = site.sprite
if not sprite then return end
local frObj <const> = site.frame
if not frObj then return end

local transact <const> = app.transaction
local frIdx <const> = frObj.frameNumber
local frObjs <const> = sprite.frames
local lenFrObjs <const> = #frObjs

---@type Tag[]
local chosenTags <const> = {}
local tags <const> = sprite.tags
local lenTags <const> = #tags
local i = 0
while i < lenTags do
    i = i + 1
    local tag <const> = tags[i]
    local fromFrObj <const> = tag.fromFrame
    local toFrObj <const> = tag.toFrame
    if fromFrObj and toFrObj then
        local toFrIdx <const> = toFrObj.frameNumber
        local fromFrIdx <const> = fromFrObj.frameNumber
        if toFrIdx < lenFrObjs
            and fromFrIdx <= frIdx
            and toFrIdx >= frIdx then
            chosenTags[#chosenTags + 1] = tag
        end
    end
end

local lenChosenTags <const> = #chosenTags
local j = 0
while j < lenChosenTags do
    j = j + 1
    local tag <const> = chosenTags[j]
    transact("Move Tag Right", function()
        tag.toFrame = frObjs[tag.toFrame.frameNumber + 1]
        tag.fromFrame = frObjs[tag.fromFrame.frameNumber + 1]
    end)
end

app.frame = frObjs[1 + frIdx % lenFrObjs]
app.refresh()
app.layer = app.layer