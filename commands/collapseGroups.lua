dofile("../support/aseutilities.lua")

local sprite <const> = app.sprite
if not sprite then return end

local groups <const> = AseUtilities.getGroups(sprite, true, true)
local lenGroups <const> = #groups

local activeLayer = app.layer or sprite.layers[1]
while activeLayer.parent.__name ~= "doc::Sprite" do
    activeLayer = activeLayer.parent --[[@as Layer]]
end

local i = 0
while i < lenGroups do
    i = i + 1
    groups[i].isCollapsed = true
end

app.layer = activeLayer