dofile("../support/aseutilities.lua")

local site <const> = app.site
local sprite <const> = site.sprite
if not sprite then return end

local range <const> = app.range
if range.sprite ~= sprite then return end

local rangeType <const> = range.type
local rangeFrObjs <const> = range.frames
local lenRangeFrObjs <const> = #rangeFrObjs

local spriteFrObjs <const> = sprite.frames
local lenSpriteFrObjs <const> = #spriteFrObjs

if rangeType ~= RangeType.FRAMES or lenRangeFrObjs <= 0 then
    local activeTag <const> = app.tag
    if activeTag then
        local fromFrame <const> = activeTag.fromFrame
        local toFrame <const> = activeTag.toFrame
        if fromFrame and toFrame then
            local fromIdx <const> = fromFrame.frameNumber
            local toIdx <const> = toFrame.frameNumber
            if fromIdx <= lenSpriteFrObjs and toIdx <= lenSpriteFrObjs
                and fromIdx >= 1 and toIdx >= 1 then
                ---@type integer[]
                local tagFrIdcs <const> = {}
                local lenTagFrIdcs = 0
                local i = fromIdx - 1
                while i < toIdx do
                    i = i + 1
                    lenTagFrIdcs = lenTagFrIdcs + 1
                    tagFrIdcs[lenTagFrIdcs] = i
                end
                app.range.frames = tagFrIdcs
                return
            end
        end
    end

    local activeFrObj <const> = site.frame or spriteFrObjs[1]
    app.range.frames = { activeFrObj }
    return
end

local frIdcsRange <const> = AseUtilities.frameObjsToIdcs(rangeFrObjs)
local frIdcsSeqs <const> = Utilities.sequential(frIdcsRange)
local lenFrIdcsSeqs <const> = #frIdcsSeqs

---@type table<integer, boolean>
local frIdxUniques <const> = {}
---@type integer[]
local newFrIdcs <const> = {}
local lenNewFrIdcs = lenRangeFrObjs
local h = 0
while h < lenRangeFrObjs do
    h = h + 1
    local frIdx <const> = frIdcsRange[h]
    frIdxUniques[frIdx] = true
    newFrIdcs[h] = frIdx
end

local i = 0
while i < lenFrIdcsSeqs do
    i = i + 1
    local frIdcsSeq <const> = frIdcsSeqs[i]

    local frIdxOrig <const> = frIdcsSeq[1]
    if frIdxOrig > 1 then
        local frIdxPrev <const> = frIdxOrig - 1
        if not frIdxUniques[frIdxPrev] then
            frIdxUniques[frIdxPrev] = true
            lenNewFrIdcs = lenNewFrIdcs + 1
            newFrIdcs[lenNewFrIdcs] = frIdxPrev
        end
    end

    local frIdxDest <const> = frIdcsSeq[#frIdcsSeq]
    if frIdxDest < lenSpriteFrObjs then
        local frIdxNext <const> = frIdxDest + 1
        if not frIdxUniques[frIdxNext] then
            frIdxUniques[frIdxNext] = true
            lenNewFrIdcs = lenNewFrIdcs + 1
            newFrIdcs[lenNewFrIdcs] = frIdxNext
        end
    end
end

app.range.frames = newFrIdcs