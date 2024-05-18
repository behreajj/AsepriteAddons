dofile("../support/aseutilities.lua")

local site <const> = app.site
local sprite <const> = site.sprite
if not sprite then return end

local groups <const> = AseUtilities.getGroups(sprite, true, true)
local lenGroups <const> = #groups

local activeLayer = site.layer or sprite.layers[1]
---@diagnostic disable-next-line: undefined-field
while activeLayer.parent.__name ~= "doc::Sprite" do
    activeLayer = activeLayer.parent --[[@as Layer]]
end

local i = 0
while i < lenGroups do
    i = i + 1
    groups[i].isCollapsed = true
end

app.layer = activeLayer