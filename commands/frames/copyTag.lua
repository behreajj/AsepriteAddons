--[[
https://github.com/aseprite/aseprite/issues/4437
]]

dofile("../../support/aseutilities.lua")

local site <const> = app.site
local sprite <const> = site.sprite
if not sprite then return end

local srcTag <const> = app.tag
if not srcTag then return end

local fromFrObj <const> = srcTag.fromFrame
local toFrObj <const> = srcTag.toFrame
if (not fromFrObj) or (not toFrObj) then return end

local fromFrIdx <const> = fromFrObj.frameNumber
local toFrIdx <const> = toFrObj.frameNumber

local spriteFrObjs <const> = sprite.frames
local lenSpriteFrObjs <const> = #spriteFrObjs
if toFrIdx > lenSpriteFrObjs then
    app.alert {
        title = "Error",
        text = {
            "Invalid tag.",
            "Tag to frame exceeds frames in sprite."
        }
    }
    return
end

local frSpan <const> = 1 + toFrIdx - fromFrIdx
-- local srcFrIdcs <const> = AseUtilities.parseTag(srcTag)
-- local lenSrcFrIdcs <const> = #srcFrIdcs
-- if lenSrcFrIdcs <= 0 then return end

local leaves <const> = AseUtilities.getLayerHierarchy(
    sprite, true, true, true, true)
local lenLeaves <const> = #leaves

---@type number[]
local srcDurations <const> = {}
---@type integer[]
local srcFrIdcs <const> = {}

local h = 0
while h < frSpan do
    local srcFrIdx <const> = fromFrIdx + h
    local srcFrObj <const> = spriteFrObjs[srcFrIdx]
    local srcDuration = 0.1
    srcDuration = srcFrObj.duration
    srcFrIdcs[1 + h] = srcFrIdx
    srcDurations[1 + h] = srcDuration
    h = h + 1
end

local oldActiveFrObj <const> = site.frame
local oldActiveFrIdx <const> = oldActiveFrObj
    and oldActiveFrObj.frameNumber
    or toFrIdx

local docPrefs <const> = app.preferences.document(sprite)
local tlPrefs <const> = docPrefs.timeline
local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]

-- Sprite:newFrame doesn't work well because you have no control
-- over where the target frame is appended and you can't easily
-- move the frame.
app.transaction(string.format(
    "Copy Frames %d to %d",
    frameUiOffset + fromFrIdx, frameUiOffset + toFrIdx), function()
    local i = 0
    while i < frSpan do
        i = i + 1
        local srcFrIdx <const> = srcFrIdcs[i]
        local srcDuration <const> = srcDurations[i]

        local trgFrIdx <const> = srcFrIdx + frSpan
        local trgFrObj <const> = sprite:newEmptyFrame(trgFrIdx)

        -- print(string.format(
        --     "srcFrIdx: %d, trgFrIdx: %d",
        --     srcFrIdx, trgFrIdx))

        trgFrObj.duration = srcDuration

        local j = 0
        while j < lenLeaves do
            j = j + 1
            local leaf <const> = leaves[j]
            local srcCel <const> = leaf:cel(srcFrIdx)
            if srcCel then
                local srcColor <const> = srcCel.color
                local srcData <const> = srcCel.data
                local srcImg <const> = srcCel.image
                local srcOpacity <const> = srcCel.opacity
                local srcPos <const> = srcCel.position
                local srcZIndex <const> = srcCel.zIndex

                local trgCel <const> = sprite:newCel(
                    leaf, trgFrIdx, srcImg, srcPos)
                trgCel.color = AseUtilities.aseColorCopy(srcColor, "")
                trgCel.data = srcData
                trgCel.opacity = srcOpacity
                trgCel.zIndex = srcZIndex
            end -- End cel exists.
        end     -- End leaves loop.
    end         -- End frame indices loop.

    srcTag.toFrame = spriteFrObjs[toFrIdx]
end) -- End transaction.

app.transaction("Shift Tags", function()
    -- Tag behavior is a complete mess, not sure if there's much
    -- you can do to fix it...
    local tags <const> = sprite.tags
    local lenTags <const> = #tags
    local i = 0
    while i < lenTags do
        i = i + 1
        local shiftTag <const> = tags[i]
        local shiftFromFrObj <const> = shiftTag.fromFrame
        local shiftToFrObj <const> = shiftTag.toFrame
        if shiftFromFrObj and shiftToFrObj then
            local shiftFromFrIdx <const> = shiftFromFrObj.frameNumber
            local shiftToFrIdx <const> = shiftToFrObj.frameNumber
            if shiftFromFrIdx > fromFrIdx
                or shiftToFrIdx < toFrIdx then
                shiftTag.toFrame = spriteFrObjs[shiftToFrIdx + frSpan]
                shiftTag.fromFrame = spriteFrObjs[shiftFromFrIdx + frSpan]
            end
        end
    end
end)

app.transaction("Copy Tag", function()
    local trgTag <const> = sprite:newTag(
        toFrIdx + 1,
        toFrIdx + frSpan)
    trgTag.name = srcTag.name .. " (Copy)"
    trgTag.aniDir = srcTag.aniDir
    trgTag.color = AseUtilities.aseColorCopy(srcTag.color, "")
    trgTag.data = srcTag.data
    trgTag.repeats = srcTag.repeats
end)

app.frame = sprite.frames[oldActiveFrIdx + frSpan]
app.refresh()