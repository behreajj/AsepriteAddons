local site <const> = app.site
local activeSprite <const> = site.sprite
if not activeSprite then return end

local range <const> = app.range
if range.sprite ~= activeSprite then return end
local rangeLayers <const> = range.layers
local lenRangeLayers <const> = #rangeLayers
if lenRangeLayers <= 0 then return end

---@param layer Layer
---@param tally integer
---@param idTallyDict table<integer, integer>
---@return integer
local function tallyLeaves(layer, tally, idTallyDict)
    if layer.isGroup then
        local children <const> = layer.layers
        if children then
            local lenChildren <const> = #children
            local i = 0
            while i < lenChildren do
                i = i + 1
                tally = tallyLeaves(children[i], tally, idTallyDict)
            end
        end
        return tally
    else
        idTallyDict[layer.id] = tally + 1
        return tally + 1
    end
end

---@param sprite Sprite
---@return integer
local function tallySpriteLeaves(sprite)
    ---@type table<integer, integer>
    local idTallyDict <const> = {}
    local tally = 0
    local topLayers <const> = sprite.layers
    local lenTopLayers <const> = #topLayers
    local h = 0
    while h < lenTopLayers do
        h = h + 1
        tally = tallyLeaves(topLayers[h], tally, idTallyDict)
    end
    return tally
end

local lenLeaves <const> = tallySpriteLeaves(activeSprite)

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
    -- It's possible to have one group with no children.
    if leavesRemaining == 0 then
        activeSprite:newLayer()
    end

    local i = lenRangeLeaves + 1
    while i > 1 do
        i = i - 1
        local leaf <const> = rangeLeaves[i]
        if leaf then
            leavesRemaining = leavesRemaining - 1
            if leavesRemaining == 0 then
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
                local stackIndex <const> = group.stackIndex
                local grandParent <const> = group.parent or activeSprite
                local lenChildren <const> = #children

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