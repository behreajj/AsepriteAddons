dofile("../support/aseutilities.lua")

local site <const> = app.site
local activeSprite <const> = site.sprite
if not activeSprite then return end

local activeLayer <const> = site.layer
if not activeLayer then return end

local origFrObj <const> = site.frame
if not origFrObj then return end

local shift <const> = -1
local frames <const> = activeSprite.frames
local lenFrames <const> = #frames
local origFrIdx <const> = origFrObj.frameNumber
local destFrIdx <const> = 1 + (shift + origFrIdx - 1) % lenFrames
local destFrObj <const> = frames[destFrIdx]

-- No point in basing this on a range, which will be removed
-- by the swap. Could use getLayerHierarchy for all layers.
-- Background layers cause an unknown issue. Reference layers
-- are ignored though for this case they coule be included.
local leaves <const> = AseUtilities.appendLeaves(
    activeLayer, {},
    true, true, true, false)
local lenLeaves <const> = #leaves
if lenLeaves > 0 then
    app.transaction("Cycle Cel Left", function()
        local tempFrameObj <const> = activeSprite:newEmptyFrame()
        local i = 0
        while i < lenLeaves do
            i = i + 1
            local leaf <const> = leaves[i]
            local origCel <const> = leaf:cel(origFrObj)
            local destCel <const> = leaf:cel(destFrObj)
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
end