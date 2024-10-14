dofile("./bounds3.lua")

---@class Octree
---@field protected bounds Bounds3 bounding area
---@field protected capacity integer point capacity
---@field protected children Octree[] child nodes
---@field protected level integer level, or depth
---@field protected points Vec3[] points array
---@operator len(): integer
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

---Creates a new Octree node with an empty list of points at a given level. The
---capacity specifies the number of points the node can hold before it is split
---into children.
---@param bounds Bounds3 bounding volume
---@param capacity integer point capacity
---@param level integer? level, or depth
---@return Octree
function Octree.new(bounds, capacity, level)
    local inst <const> = setmetatable({}, Octree)
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

---Finds the mean center of each leaf node in an octree. Appends centers to an
---array if provided, otherwise creates a new array.
---@param o Octree octree
---@param arr Vec3[]? array
---@return Vec3[]
function Octree.centersMean(o, arr)
    local arrVrf <const> = arr or {}
    local children <const> = o.children
    local lenChildren <const> = #children

    local i = 0
    while i < lenChildren do
        i = i + 1
        local child <const> = children[i]
        Octree.centersMean(child, arrVrf)
    end

    if lenChildren < 1 then
        local cursor <const> = #arrVrf + 1
        local leafPoints <const> = o.points
        local lenLeafPoints <const> = #leafPoints
        if lenLeafPoints > 1 then
            local xSum = 0.0
            local ySum = 0.0
            local zSum = 0.0

            local j = 0
            while j < lenLeafPoints do
                j = j + 1
                local pt <const> = leafPoints[j]
                xSum = xSum + pt.x
                ySum = ySum + pt.y
                zSum = zSum + pt.z
            end

            local lenInv <const> = 1.0 / lenLeafPoints
            arrVrf[cursor] = Vec3.new(
                xSum * lenInv,
                ySum * lenInv,
                zSum * lenInv)
        elseif lenLeafPoints > 0 then
            local pt <const> = leafPoints[1]
            arrVrf[cursor] = Vec3.new(
                pt.x, pt.y, pt.z)
        end
    end

    return arrVrf
end

---Counts the number of leaves held by this node. Returns 1 if the node is
---itself a leaf.
---@param o Octree octree
---@return integer
function Octree.countLeaves(o)
    -- Even if this is not used directly by
    -- any dialog, retain it for diagnostics.
    local children <const> = o.children
    local lenChildren <const> = #children
    if lenChildren < 1 then return 1 end

    local sum = 0
    local i = 0
    while i < lenChildren do
        i = i + 1
        local child <const> = children[i]
        sum = sum + Octree.countLeaves(child)
    end
    return sum
end

---Counts the number of points held by this octree's leaf nodes.
---@param o Octree octree
---@return integer
function Octree.countPoints(o)
    local children <const> = o.children
    local lenChildren <const> = #children
    if lenChildren < 1 then return #o.points end

    local sum = 0
    local i = 0
    while i < lenChildren do
        i = i + 1
        local child <const> = children[i]
        sum = sum + Octree.countPoints(child)
    end
    return sum
end

---Removes empty child nodes from the octree. Returns true if this octree node
---should be removed, i.e., it has no children and its points array is empty.
---
---This should only be called after all points have been inserted into the tree.
---@param o Octree octree
---@return boolean
function Octree.cull(o)
    local children <const> = o.children
    local lenChildren <const> = #children
    local cullThis = 0

    -- Because of how length operator works this
    -- should remove from the table instead of
    -- setting table elements to nil.
    local i = lenChildren + 1
    while i > 1 do
        i = i - 1
        local child <const> = children[i]
        if Octree.cull(child) then
            table.remove(children, i)
            cullThis = cullThis + 1
        end
    end

    return (cullThis >= lenChildren)
        and (#o.points < 1)
end

---Inserts a point into the node by reference, not by value. Returns true if
---the point was successfully inserted into either the node or its children.
---@param o Octree octree
---@param point Vec3 point
---@return boolean
function Octree.insert(o, point)
    if Bounds3.containsInclExcl(o.bounds, point) then
        local children <const> = o.children
        local lenChildren <const> = #children
        local i = 0
        while i < lenChildren do
            i = i + 1
            local child <const> = children[i]
            if Octree.insert(child, point) then
                return true
            end
        end

        if lenChildren < 1 then
            -- Using table.sort here was definitely the
            -- cause of a major performance loss.
            local points <const> = o.points
            Vec3.insortRight(points, point, Vec3.comparator)
            if #points > o.capacity then
                Octree.split(o, o.capacity)
            end
            return true
            -- else
            -- Octree.split(o, o.capacity)
            -- return Octree.insert(o, point)
        end
    end

    return false
end

---Inserts an array of points into an node. Returns true if all point
---insertions succeeded. Otherwise, returns false.
---@param o Octree octree
---@param ins Vec3[] insertions array
---@return boolean
function Octree.insertAll(o, ins)
    local lenIns <const> = #ins
    local flag = true
    local i = 0
    while i < lenIns do
        i = i + 1
        flag = flag and Octree.insert(o, ins[i])
    end
    return flag
end

---Evaluates whether a node has any children. Returns true if not.
---@param o Octree octree
---@return boolean
function Octree.isLeaf(o)
    return #o.children < 1
end

---Finds the maximum level, or depth, of the node and its children.
---@param o Octree octree
---@return integer
function Octree.maxLevel(o)
    -- Even if this is not used directly by
    -- any dialog, retain it for diagnostics.
    local children <const> = o.children
    local lenChildren <const> = #children
    local maxLevel = o.level

    local i = 0
    while i < lenChildren do
        i = i + 1
        local child <const> = children[i]
        local lvl <const> = Octree.maxLevel(child)
        if lvl > maxLevel then
            maxLevel = lvl
        end
    end

    return maxLevel
end

---Queries the node with a sphere. If a point can be found within the bounds,
---returns a point and distance from the query center. If it cannot be found,
---returns a default point, which may be nil.
---@param o Octree octree
---@param center Vec3 sphere center
---@param radius number sphere radius
---@param dfPt Vec3|nil default point
---@return Vec3|nil
---@return number
function Octree.query(o, center, radius, dfPt)
    local rVrf <const> = radius or 46340
    local v <const>, d <const> = Octree.queryInternal(
        o, center, rVrf, Vec3.distEuclidean)
    if v then
        return Vec3.new(v.x, v.y, v.z), d
    else
        return dfPt, d
    end
end

---Queries the node with a sphere. If a point can be found within the bounds,
---returns it with the square distance from the query center. If a point
---cannot be found, returns nil.
---@param o Octree octree
---@param center Vec3 sphere center
---@param rad number sphere radius
---@param df fun(a: Vec3, b: Vec3): number distance function
---@return Vec3|nil
---@return number
function Octree.queryInternal(o, center, rad, df)
    local nearPoint = nil
    local nearDist = 2147483647
    if Bounds3.intersectsSphere(
            o.bounds, center, rad) then
        local children <const> = o.children
        local lenChildren <const> = #children
        local i = 0
        while i < lenChildren do
            i = i + 1
            local child <const> = children[i]
            local candDist = 2147483647
            local candPoint = nil
            candPoint, candDist = Octree.queryInternal(
                child, center, rad, df)
            if candPoint and (candDist < nearDist) then
                nearPoint = candPoint
                nearDist = candDist
            end
        end

        -- TODO: Can this be replaced with a stack based approach?
        if lenChildren < 1 then
            local points <const> = o.points
            local lenPoints <const> = #points

            local j = 0
            while j < lenPoints do
                j = j + 1
                local point <const> = points[j]
                local candDist <const> = df(center, point)
                if (candDist < rad)
                    and (candDist < nearDist) then
                    nearPoint = point
                    nearDist = candDist
                end
            end
        end
    end

    return nearPoint, nearDist
end

---Splits the octree node into eight child nodes. If a child capacity is not
---provided, defaults to the parent's capacity.
---@param o Octree octree
---@param childCapacity integer? child capacity
---@return Octree
function Octree.split(o, childCapacity)
    local chCpVerif <const> = childCapacity or o.capacity
    local children <const> = o.children
    local nextLevel <const> = o.level + 1

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
    local pts <const> = o.points
    local ptsLen <const> = #pts

    -- Inner loop has an irregular length due to
    -- early break, so this isn't flattened.
    local j = 0
    while j < ptsLen do
        j = j + 1
        local pt <const> = pts[j]
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

---Splits an octree into children. For cases where a minimum number of children
---nodes is desired, independent of point insertion. The result will be 8
---raised to the power of iterations, e.g.: 8, 64, 512, etc.
---@param o Octree octree
---@param itr integer iterations
---@param childCapacity integer? child capacity
---@return Octree
function Octree.subdivide(o, itr, childCapacity)
    if (not itr) or (itr < 1) then return o end
    local chCpVerif <const> = childCapacity or o.capacity

    local i = 0
    while i < itr do
        i = i + 1
        local children <const> = o.children
        local lenChildren <const> = #children
        local j = 0
        while j < lenChildren do
            j = j + 1
            local child <const> = children[j]
            Octree.subdivide(child, itr - 1, chCpVerif)
        end

        if lenChildren < 1 then
            Octree.split(o, chCpVerif)
        end
    end

    return o
end

---Returns a JSON string of the octree node.
---@param o Octree octree
---@return string
function Octree.toJson(o)
    local leafStr = ""
    if Octree.isLeaf(o) then
        ---@type string[]
        local ptsStrs <const> = {}
        local pts <const> = o.points
        local ptsLen <const> = #pts

        local i = 0
        while i < ptsLen do
            i = i + 1
            ptsStrs[i] = Vec3.toJson(pts[i])
        end

        leafStr = string.format(
            ",\"points\":[%s]",
            table.concat(ptsStrs, ","))
    else
        ---@type string[]
        local childStrs <const> = {}
        local children <const> = o.children
        local lenChildren <const> = #children

        local j = 0
        while j < lenChildren do
            j = j + 1
            local child <const> = children[j]
            childStrs[j] = Octree.toJson(child)
        end

        leafStr = string.format(
            ",\"children\":[%s]",
            table.concat(childStrs, ","))
    end

    return string.format(
        "{\"level\":%d,\"bounds\":%s,\"capacity\":%d%s}",
        o.level - 1,
        Bounds3.toJson(o.bounds),
        o.capacity,
        leafStr)
end

return Octree