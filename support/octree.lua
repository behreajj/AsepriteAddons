dofile("./bounds3.lua")

Octree = {}
Octree.__index = Octree

setmetatable(Octree, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

Octree.BACK_NORTH_EAST = 4
Octree.BACK_NORTH_WEST = 3
Octree.BACK_SOUTH_EAST = 2
Octree.BACK_SOUTH_WEST = 1
Octree.FRONT_NORTH_EAST = 8
Octree.FRONT_NORTH_WEST = 7
Octree.FRONT_SOUTH_EAST = 6
Octree.FRONT_SOUTH_WEST = 5

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
    inst.bounds = bounds or Bounds3.newByRef()
    inst.capacity = capacity or 8
    inst.children = {
        nil, nil, nil, nil,
        nil, nil, nil, nil }
    inst.level = level or 0
    inst.points = {}

    if inst.capacity < 1 then inst.capacity = 1 end
    if inst.level < 0 then inst.level = 0 end

    return inst
end

function Octree:__len()
    return #self.points
end

function Octree:__tostring()
    return Octree.toJson(self)
end

---Inserts a point into the octree node. Returns
---true if the point was successfully inserted
---into either the node or its children. Returns
---false if the insertion was unsuccessful.
---@param o table octree node
---@param point table point
---@return boolean
function Octree.insert(o, point)
    if Bounds3.containsInclExcl(o.bounds, point) then
        if Octree.isLeaf(o) then
            table.insert(o.points, point)
            if #o.points > o.capacity then
                Octree.split(o)
            end
            return true
        end

        for i = 1, 8, 1 do
            if Octree.insert(o.children[i], point) then
                return true
            end
        end
    end
    return false
end

---Inserts an array of points into an octree node.
---Returns true if all point insertions succeeded.
---Otherwise, returns false.
---@param o table octree node
---@param points table points array
---@return boolean
function Octree.insertAll(o, points)
    local len = #points
    local flag = true
    for i = 1, len, 1 do
        flag = flag and Octree.insert(o, points[i])
    end
    return flag
end

---Evaluates whether an octree node has
---any children. Returns true if not.
---Otherwise returns false.
---@param o table octree node
---@return boolean
function Octree.isLeaf(o)
    for i = 1, 8, 1 do
        if o.children[i] then return false end
    end
    return true
end

---Gets the maximum depth of the node and
---its children.
---@param o table octree node
---@return number
function Octree.maxLevel(o)
    local mxLvl = o.level
    for i = 1, 8, 1 do
        local child = o.children[i]
        if child then
            local lvl = Octree.maxLevel(child)
            if lvl > mxLvl then mxLvl = lvl end
        end
    end
    return mxLvl
end

---Queries the octree with a spherical range, returning
---points inside the range.
---@param o table octree
---@param center table sphere center
---@param radius number sphere radius
---@return table
function Octree.querySpherical(o, center, radius)
    local found = {}
    Octree.querySphericalInternal(o, center, radius, found)

    -- Treating "found" as a dictionary where distSq
    -- is the key and the point is the value doesn't
    -- seem to help, so this is a last resort.
    table.sort(found, function(a, b)
        return Vec3.distSq(a, center) < Vec3.distSq(b, center)
    end)
    return found

    -- local result = {}
    -- for _, v in pairs(found) do
    --     table.insert(result, v)
    -- end
    -- return result

end

---Queries the octree with a spherical range, returning
---points inside the range.
---@param o table octree
---@param center table sphere center
---@param radius number sphere radius
---@param found table array containing results
---@return table
function Octree.querySphericalInternal(
    o, center, radius, found)

    if Bounds3.intersectsSphere(o.bounds, center, radius) then

        local children = o.children
        local isLeaf = true
        for i = 1, 8, 1 do
            local child = children[i]
            if child then
                isLeaf = false
                Octree.querySphericalInternal(
                    child, center, radius, found)
            end
        end

        if isLeaf then
            local pts = o.points
            local ptsLen = #pts
            local rsq = radius * radius
            for i = 1, ptsLen, 1 do
                local pt = pts[i]
                local currDist = Vec3.distSq(center, pt)

                -- TODO: Look at JS or C# implementations
                -- of color gradient with bisect left, right, etc.
                if currDist < rsq then
                    table.insert(found, pt)
                end
            end
        end

    end

    return found
end

---Splits the octree node into eight child nodes.
---@param o table octree node
---@return table
function Octree.split(o)
    local nxtLvl = o.level + 1
    for i = 1, 8, 1 do
        o.children[i] = Octree.new(
            Bounds3.newByRef(),
            o.capacity,
            nxtLvl)
    end

    Bounds3.splitInternal(
        o.bounds, 0.5, 0.5, 0.5,
        o.children[Octree.BACK_SOUTH_WEST].bounds,
        o.children[Octree.BACK_SOUTH_EAST].bounds,
        o.children[Octree.BACK_NORTH_WEST].bounds,
        o.children[Octree.BACK_NORTH_EAST].bounds,
        o.children[Octree.FRONT_SOUTH_WEST].bounds,
        o.children[Octree.FRONT_SOUTH_EAST].bounds,
        o.children[Octree.FRONT_NORTH_WEST].bounds,
        o.children[Octree.FRONT_NORTH_EAST].bounds)

    local pts = o.points
    local ptsLen = #pts
    for i = 1, ptsLen, 1 do
        local pt = pts[i]
        local flag = false
        for j = 1, 8, 1 do
            flag = Octree.insert(o.children[j], pt)
            if flag then break end
        end
    end

    o.points = {}
    return o
end

---Returns a JSON string of the octree node.
---@param o table octree
function Octree.toJson(o)
    local str = "{\"level\":"
    str = str .. string.format("%d", o.level)
    str = str .. ",\"bounds\":"
    str = str .. Bounds3.toJson(o.bounds)
    str = str .. ",\"capacity\":"
    str = str .. string.format("%d", o.capacity)
    str = str .. ",\"children\":["

    local isLeaf = true
    for i = 1, 8, 1 do
        local child = o.children[i]
        if child ~= nil then
            isLeaf = false
            str = str .. Octree.toJson(child)
        else
            str = str .. "null"
        end
        if i < 8 then str = str .. "," end
    end

    str = str .. "]"
    str = str .. ",\"points\":["

    if isLeaf then
        local pts = o.points
        local ptsLen = #pts
        for i = 1, ptsLen, 1 do
            str = str .. Vec3.toJson(pts[i])
            if i < ptsLen then str = str .. "," end
        end
    end

    str = str .. "]"
    str = str .. "}"

    return str
end

return Octree