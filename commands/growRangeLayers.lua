dofile("../support/aseutilities.lua")

local site <const> = app.site
local sprite <const> = site.sprite
if not sprite then return end

local range <const> = app.range
if range.sprite ~= sprite then return end

local rangeType <const> = range.type
local rangeLayers <const> = range.layers
local lenRangeLayers <const> = #rangeLayers

local activeLayer <const> = site.layer or sprite.layers[1]

if rangeType ~= RangeType.LAYERS or lenRangeLayers <= 0 then
    app.range.layers = { activeLayer }
    return
end

---@type table<integer, Layer>
local idLayerDict <const> = {}
---@type Layer[]
local newLayers <const> = {}
local lenNewLayers = lenRangeLayers
local h = 0
while h < lenRangeLayers do
    h = h + 1
    local rangeLayer <const> = rangeLayers[h]
    idLayerDict[rangeLayer.id] = rangeLayer
    newLayers[h] = rangeLayer
end

local currentLayer = activeLayer

---@diagnostic disable-next-line: undefined-field
while currentLayer.__name ~= "doc::Sprite" do
    -- This will include the current layer itself if it is not a group,
    -- and will allow the range to expand into the active layer's parent
    -- when all of its neighbors have been found.
    local children <const> = {}
    AseUtilities.appendGroups(currentLayer, children, true, true)
    AseUtilities.appendLeaves(currentLayer, children, true, true, true, true)
    local lenChildren = #children
    local hadAllChildren = true

    local i = 0
    while i < lenChildren do
        i = i + 1
        local child <const> = children[i]
        local hadChild <const> = idLayerDict[child.id] ~= nil
        hadAllChildren = hadAllChildren and hadChild
        if not hadChild then
            lenNewLayers = lenNewLayers + 1
            newLayers[lenNewLayers] = child
        end
    end

    if not hadAllChildren then
        app.range.layers = newLayers
        return
    end

    local parent <const> = currentLayer.parent
    local neighbors <const> = parent.layers
    if neighbors then
        local lenNeighbors <const> = #neighbors
        local hadAllKin = true
        local currentIndex <const> = currentLayer.stackIndex

        -- The issue with this is that the user could have manually
        -- selected a neighboring group, but not it's children, so that
        -- hierarchy would be omitted.
        local searchStart = currentIndex
        while searchStart > 1 do
            searchStart = searchStart - 1
            local neighbor <const> = neighbors[searchStart]
            if idLayerDict[neighbor.id] == nil then
                break
            end
        end

        local searchEnd = currentIndex
        while searchEnd < lenNeighbors do
            searchEnd = searchEnd + 1
            local neighbor <const> = neighbors[searchEnd]
            if idLayerDict[neighbor.id] == nil then
                break
            end
        end

        local j = searchStart - 1
        while j < searchEnd do
            j = j + 1
            local neighbor <const> = neighbors[j]
            ---@type Layer[]
            local kin <const> = {}
            AseUtilities.appendGroups(neighbor, kin, true, true)
            AseUtilities.appendLeaves(neighbor, kin, true, true, true, true)
            local lenKin = #kin

            local k = 0
            while k < lenKin do
                k = k + 1
                local cousin <const> = kin[k]
                local hadCousin <const> = idLayerDict[cousin.id] ~= nil
                hadAllKin = hadAllKin and hadCousin
                if not hadCousin then
                    lenNewLayers = lenNewLayers + 1
                    newLayers[lenNewLayers] = cousin
                end
            end -- End kin loop.
        end     -- End neighbors loop.

        if not hadAllKin then
            app.range.layers = newLayers
            return
        end -- End kin early return.
    end     -- End parent has child layers.

    currentLayer = parent --[[@as Layer]]
end -- End layer is not sprite.

app.range.layers = newLayers