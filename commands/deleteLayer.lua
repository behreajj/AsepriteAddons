dofile("../support/aseutilities.lua")

local site <const> = app.site
local activeSprite <const> = site.sprite
if not activeSprite then return end

local range <const> = app.range
if range.sprite ~= activeSprite then return end
local rangeLayers <const> = range.layers
local lenRangeLayers <const> = #rangeLayers
if lenRangeLayers <= 0 then return end

local includeLocked <const> = true
local includeHidden <const> = true
local includeTiles <const> = true
local includeBkg <const> = true

local leaves <const> = AseUtilities.getLayerHierarchy(
    activeSprite,
    includeLocked, includeHidden, includeTiles, includeBkg)
local lenLeaves <const> = #leaves

---@type Layer[]
local rangeGroups <const> = {}
local lenRangeGroups = 0
---@type Layer[]
local rangeLeaves <const> = {}
local lenRangeLeaves = 0

local h = 0
while h < lenRangeLayers do
    h = h + 1
    local rangeLayer <const> = rangeLayers[h]
    if rangeLayer.isGroup then
        lenRangeGroups = lenRangeGroups + 1
        rangeGroups[lenRangeGroups] = rangeLayer
    else
        lenRangeLeaves = lenRangeLeaves + 1
        rangeLeaves[lenRangeLeaves] = rangeLayer
    end
end

app.transaction("Delete Layers", function()
    local leavesRemaining = lenLeaves
    local i = lenRangeLeaves + 1
    while i > 1 do
        i = i - 1
        local leaf <const> = rangeLeaves[i]
        if leaf then
            leavesRemaining = leavesRemaining - 1
            if leavesRemaining == 0 then
                -- TODO: Problem with this is that it ignores
                -- reference layers.
                activeSprite:newLayer()
            end
            activeSprite:deleteLayer(leaf)
        end
    end

    ---@type Layer[]
    local newRangeLayers <const> = {}
    local lenNewRangeLayers = 0

    local j = lenRangeGroups + 1
    while j > 1 do
        j = j - 1
        local group <const> = rangeGroups[j]
        if group then
            local children <const> = group.layers
            if children then
                local lenChildren <const> = #children
                local stackIndex <const> = group.stackIndex
                local grandParent <const> = group.parent or activeSprite

                local k = 0
                while k < lenChildren do
                    k = k + 1
                    local child <const> = children[k]
                    child.parent = grandParent
                    child.stackIndex = stackIndex + k - 1
                    lenNewRangeLayers = lenNewRangeLayers + 1
                    newRangeLayers[lenNewRangeLayers] = child
                end
            end
            activeSprite:deleteLayer(group)
        end
    end

    if lenNewRangeLayers > 0 then
        app.range:clear()
        app.range.layers = newRangeLayers
    end
end)

app.refresh()