dofile("../support/aseutilities.lua")

local site = app.site
local activeSprite = site.sprite
if not activeSprite then return end

local activeLayer = site.layer
if not activeLayer then return end
if activeLayer.isReference then return end
-- Any way to make this work with backgrounds?
if activeLayer.isBackground then return end

local origFrObj = site.frame
if not origFrObj then return end

local shift = -1
local frames = activeSprite.frames
local lenFrames = #frames
local origFrIdx = origFrObj.frameNumber
local destFrIdx = 1 + (shift + origFrIdx - 1) % lenFrames
local destFrObj = frames[destFrIdx]

-- No point in basing this on a range, which will be removed
-- by the swap. Could use getLayerHierarchy for all layers.
local leaves = AseUtilities.appendLeaves(
    activeLayer, {},
    true, true, true, true)
local lenLeaves = #leaves

app.transaction("Cycle Cel Left", function()
    local tempFrameObj = activeSprite:newEmptyFrame()
    local i = 0
    while i < lenLeaves do
        i = i + 1
        local leaf = leaves[i]
        local origCel = leaf:cel(origFrObj)
        local destCel = leaf:cel(destFrObj)
        if origCel and destCel then
            origCel.frame = tempFrameObj
            destCel.frame = origFrObj
            origCel.frame = destFrObj
        elseif origCel then
            origCel.frame = destFrObj
        elseif destCel then
            destCel.frame = origFrObj
        end
    end
    activeSprite:deleteFrame(tempFrameObj)
    app.activeFrame = destFrObj
end)