dofile("../support/aseutilities.lua")

local sprite <const> = app.sprite
if not sprite then return end

local groups <const> = AseUtilities.getGroups(sprite, true, true)
local lenGroups <const> = #groups

local i = 0
while i < lenGroups do
    i = i + 1
    local group <const> = groups[i]
    group.isExpanded = not group.isExpanded
end

app.layer = app.layer