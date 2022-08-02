dofile("./bounds3.lua")

Octree = {}
Octree.__index = Octree

setmetatable(Octree, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Back South West child index.
Octree.BACK_SOUTH_WEST = 1

---Back South East child index.
Octree.BACK_SOUTH_EAST = 2

---Back North West child index.
Octree.BACK_NORTH_WEST = 3

---Back North East child index.
Octree.BACK_NORTH_EAST = 4

---Front South West child index.
Octree.FRONT_SOUTH_WEST = 5

---Front South East child index.
Octree.FRONT_SOUTH_EAST = 6

---Front North West child index.
Octree.FRONT_NORTH_WEST = 7

---Front North East child index.
Octree.FRONT_NORTH_EAST = 8

---Creates a new Octree node with an empty list of
---points at a given level. The capacity specifies
---the number of points the node can hold before it
---is split into children.
---@param bounds table bounding volume
---@param capacity integer point capacity
---@param level integer|nil level, or depth
---@return table
function Octree.new(bounds, capacity, level)
    local inst = setmetatable({}, Octree)
    inst.bounds = bounds or Bounds3.unitCubeSigned()
    inst.capacity = capacity or 16
    inst.children = {}
    inst.level = level or 1
    inst.points = {}

    if inst.capacity < 1 then inst.capacity = 1 end
    if inst.level < 1 then inst.level = 1 end

    return inst
end

function Octree:__le(b)
    return self.bounds <= b.bounds
end

function Octree:__len()
    return Octree.countPoints(self)
end

function Octree:__lt(b)
    return self.bounds < b.bounds
end

function Octree:__tostring()
    return Octree.toJson(self)
end

---Finds the mean center of each leaf node in
---an octree. If empty nodes are included
---then the center of a node's bounds is used.
---Appends centers to an array if provided,
---otherwise creates a new array.
---@param o table octree
---@param include boolean include empty nodes
---@param arr table array
---@return table
function Octree.centersMean(o, include, arr)
    -- centersMedian would also be possible,
    -- if we assume that a child's points remain
    -- sorted, and could also be cheaper.
    -- It was tried and removed after other
    -- performance improvements were found.

    local arrVerif = arr or {}
    local children = o.children
    local lenChildren = #children
    local isLeaf = true

    local i = 0
    while i < lenChildren do
        i = i + 1
        local child = children[i]
        isLeaf = false
        Octree.centersMean(
            child, include, arrVerif)
    end

    if isLeaf then
        local cursor = #arrVerif + 1
        local leafPoints = o.points
        local lenLeafPoints = #leafPoints
        if lenLeafPoints > 1 then
            local xSum = 0.0
            local ySum = 0.0
            local zSum = 0.0

            local j = 0
            while j < lenLeafPoints do
                j = j + 1
                local pt = leafPoints[j]
                xSum = xSum + pt.x
                ySum = ySum + pt.y
                zSum = zSum + pt.z
            end

            local lenInv = 1.0 / lenLeafPoints
            arrVerif[cursor] = Vec3.new(
                xSum * lenInv,
                ySum * lenInv,
                zSum * lenInv)
        elseif lenLeafPoints > 0 then
            local pt = leafPoints[1]
            arrVerif[cursor] = Vec3.new(
                pt.x, pt.y, pt.z)
        elseif include then
            arrVerif[cursor] = Bounds3.center(o.bounds)
        end
    end

    return arrVerif
end

---Removes empty child nodes from the octree.
---Returns true if this octree node should be
---removed, i.e., all its children are nil and
---its points array is empty.
---
---This should only be called after all points
---have been inserted into the tree.
---@param o table
---@return boolean
function Octree.cull(o)
    local children = o.children
    local lenChildren = #children
    local cullThis = 0

    -- Because of how length operator works this
    -- should remove from the table instead of
    -- setting table elements to nil.
    local i = lenChildren + 1
    while i > 1 do
        i = i - 1
        local child = children[i]
        if Octree.cull(child) then
            table.remove(children, i)
            cullThis = cullThis + 1
        end
    end

    return (cullThis >= lenChildren)
        and (#o.points < 1)
end

---Inserts a point into the node by reference,
---not by value. Returns true if the point was
---successfully inserted into either the node or
---its children.
---@param o table octree node
---@param point table point
---@return boolean
function Octree.insert(o, point)
    if Bounds3.containsInclExcl(o.bounds, point) then
        local children = o.children
        local lenChildren = #children
        local isLeaf = true
        local i = 0
        while i < lenChildren do
            i = i + 1
            local child = children[i]
            isLeaf = false
            if Octree.insert(child, point) then
                return true
            end
        end

        if isLeaf then
            -- Using table.sort here was definitely the
            -- cause of a major performance loss.
            local points = o.points
            Vec3.insortRight(points, point, Vec3.comparator)
            if #points > o.capacity then
                Octree.split(o, o.capacity)
            end
            return true
        else
            -- Octree.split(o, o.capacity)
            -- return Octree.insert(o, point)
        end
    end

    return false
end

---Inserts an array of points into an node.
---Returns true if all point insertions succeeded.
---Otherwise, returns false.
---@param o table octree node
---@param ins table insertions array
---@return boolean
function Octree.insertAll(o, ins)
    local lenIns = #ins
    local flag = true
    local i = 0
    while i < lenIns do
        i = i + 1
        flag = flag and Octree.insert(o, ins[i])
    end
    return flag
end

---Counts the number of leaves held by this node.
---Returns 1 if the node is itself a leaf.
---@param o table octree
---@return integer
function Octree.countLeaves(o)
    -- Even if this is not used directly by
    -- any dialog, retain it for diagnostics.
    local children = o.children
    local lenChildren = #children
    local isLeaf = true
    local sum = 0

    local i = 0
    while i < lenChildren do
        i = i + 1
        local child = children[i]
        isLeaf = false
        sum = sum + Octree.countLeaves(child)
    end

    if isLeaf then return 1 end
    return sum
end

---Counts the number of points held by this octree's
---leaf nodes.
---@param o table octree
---@return integer
function Octree.countPoints(o)
    local children = o.children
    local lenChildren = #children
    local isLeaf = true
    local sum = 0

    local i = 0
    while i < lenChildren do
        i = i + 1
        local child = children[i]
        isLeaf = false
        sum = sum + Octree.countPoints(child)
    end

    if isLeaf then sum = sum + #o.points end
    return sum
end

---Evaluates whether a node has any children.
---Returns true if not.
---@param o table octree node
---@return boolean
function Octree.isLeaf(o)
    local children = o.children
    local lenChildren = #children
    local i = 0
    while i < lenChildren do
        i = i + 1
        if children[i] then return false end
    end
    return true
end

---Finds the maximum level, or depth, of
---the node and its children.
---@param o table octree node
---@return integer
function Octree.maxLevel(o)
    -- Even if this is not used directly by
    -- any dialog, retain it for diagnostics.
    local children = o.children
    local lenChildren = #children
    local maxLevel = o.level

    local i = 0
    while i < lenChildren do
        i = i + 1
        local child = children[i]
        local lvl = Octree.maxLevel(child)
        if lvl > maxLevel then
            maxLevel = lvl
        end
    end
    return maxLevel
end

---Queries the node with a sphere. If a point can be
---found within the bounds, returns a point and
---distance from the query center. If a point cannot be
---found, returns a default point, which may be nil.
---@param o table octree
---@param center table sphere center
---@param radius number sphere radius
---@param dfPt table|nil default point
---@return table|nil
---@return number
function Octree.query(o, center, radius, dfPt)
    local radVerif = radius or 46340
    local v, dsq = Octree.queryInternal(o, center, radVerif)
    local d = math.sqrt(dsq)
    if v then
        return Vec3.new(v.x, v.y, v.z), d
    else
        return dfPt, d
    end
end

---Queries the node with a sphere. If a point can be
---found within the bounds, returns a point and
---square distance from the query center. If a point
---cannot be found, returns nil.
---@param o table octree
---@param center table sphere center
---@param radius number sphere radius
---@return table|nil
---@return number
function Octree.queryInternal(o, center, radius)
    local nearPoint = nil
    local nearDistSq = 2147483647

    if Bounds3.intersectsSphere(o.bounds, center, radius) then
        local children = o.children
        local lenChildren = #children
        local isLeaf = true
        local i = 0
        while i < lenChildren do
            i = i + 1
            local child = children[i]
            isLeaf = false
            local candDistSq = 2147483647
            local candPoint = nil
            candPoint, candDistSq = Octree.queryInternal(
                child, center, radius)
            if candPoint and (candDistSq < nearDistSq) then
                nearPoint = candPoint
                nearDistSq = candDistSq
            end
        end

        if isLeaf then
            local points = o.points
            local lenPoints = #points
            local rsq = radius * radius
            local distSq = Vec3.distSq

            local j = 0
            while j < lenPoints do
                j = j + 1
                local point = points[j]
                local candDistSq = distSq(center, point)
                if (candDistSq < rsq)
                    and (candDistSq < nearDistSq) then
                    nearPoint = point
                    nearDistSq = candDistSq
                end
            end
        end
    end

    return nearPoint, nearDistSq
end

---Splits the octree node into eight child nodes.
---If a child capacity is not provided, defaults
---to the parent's capacity.
---@param o table octree
---@param childCapacity integer|nil child capacity
---@return table
function Octree.split(o, childCapacity)
    local chCpVerif = childCapacity or o.capacity
    local children = o.children
    local nextLevel = o.level + 1

    local i = 0
    while i < 8 do
        i = i + 1
        children[i] = Octree.new(
            Bounds3.unitCubeSigned(),
            chCpVerif, nextLevel)
    end

    Bounds3.splitInternal(
        o.bounds, 0.5, 0.5, 0.5,
        children[Octree.BACK_SOUTH_WEST].bounds,
        children[Octree.BACK_SOUTH_EAST].bounds,
        children[Octree.BACK_NORTH_WEST].bounds,
        children[Octree.BACK_NORTH_EAST].bounds,
        children[Octree.FRONT_SOUTH_WEST].bounds,
        children[Octree.FRONT_SOUTH_EAST].bounds,
        children[Octree.FRONT_NORTH_WEST].bounds,
        children[Octree.FRONT_NORTH_EAST].bounds)

    -- This is faster than looping through
    -- children in reverse and removing from
    -- the points table in the inner loop.
    local pts = o.points
    local ptsLen = #pts

    -- Inner loop has an irregular length due to
    -- early break, so this isn't flattened.
    local j = 0
    while j < ptsLen do
        j = j + 1
        local pt = pts[j]
        local k = 0
        while k < 8 do
            k = k + 1
            if Octree.insert(children[k], pt) then
                break
            end
        end
    end

    o.points = {}
    return o
end

---Splits an octree into children. For cases where
---a minimum number of children nodes is desired,
---independent of point insertion. The result will
---be 8 raised to the power of iterations, e.g.:
---8, 64, 512, etc.
---@param o table octree node
---@param itr integer iterations
---@param childCapacity integer|nil child capacity
---@return table
function Octree.subdivide(o, itr, childCapacity)
    if (not itr) or (itr < 1) then return o end
    local chCpVerif = childCapacity or o.capacity

    local i = 0
    while i < itr do
        i = i + 1
        local children = o.children
        local lenChildren = #children
        local isLeaf = true
        local j = 0
        while j < lenChildren do
            j = j + 1
            local child = children[j]
            isLeaf = false
            Octree.subdivide(child, itr - 1, chCpVerif)
        end

        if isLeaf then Octree.split(o, chCpVerif) end
    end

    return o
end

---Returns a JSON string of the octree node.
---@param o table octree
function Octree.toJson(o)
    local str = string.format("{\"level\":%d", o.level - 1)
    str = str .. ",\"bounds\":"
    str = str .. Bounds3.toJson(o.bounds)
    str = str .. ",\"capacity\":"
    str = str .. string.format("%d", o.capacity)

    -- Node should be a leaf first, before
    -- any string concatenation is done.
    local isLeaf = Octree.isLeaf(o)

    if isLeaf then
        str = str .. ",\"points\":["
        local pts = o.points
        local ptsLen = #pts
        local ptsStrs = {}

        local i = 0
        while i < ptsLen do
            i = i + 1
            ptsStrs[i] = Vec3.toJson(pts[i])
        end
        str = str .. table.concat(ptsStrs, ",")
        str = str .. "]"
    else
        str = str .. ",\"children\":["
        local children = o.children
        local childStrs = {}
        local lenChildren = #children
        local j = 0
        while j < lenChildren do
            j = j + 1
            local child = children[j]
            childStrs[j] = Octree.toJson(child)
        end
        str = str .. table.concat(childStrs, ",")
        str = str .. "]"
    end

    str = str .. "}"
    return str
end

return Octree