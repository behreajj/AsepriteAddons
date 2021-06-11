dofile("./Octree.lua")

Octree = {}
Octree.__index = Octree

setmetatable(Octree, {
    __call = function (cls, ...)
        return cls.new(...)
    end})


---Creates a new Octree node with an empty list of
---points at a given level. The capacity specifies
---the number of points the node can hold before it
---is split into children.
---@param bounds table
---@param capacity number
---@param level number
---@return table
function Octree.new(bounds, capacity, level)
    local inst = setmetatable({}, Octree)
    inst.bounds = bounds or Bounds3.new()
    inst.capacity = capacity or 8
    inst.level = level or 0
    inst.points = {}

    if inst.capacity < 1 then inst.capacity = 1 end
    if inst.level < 0 then inst.level = 0 end

    return inst
end