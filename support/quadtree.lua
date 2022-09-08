dofile("./bounds2.lua")

---@class Quadtree
---@field bounds Bounds2 bounding area
---@field capacity integer point capacity
---@field children table child nodes
---@field level integer level, or depth
---@field points table points array
Quadtree = {}
Quadtree.__index = Quadtree

setmetatable(Quadtree, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---South West child index.
Quadtree.SOUTH_WEST = 1

---South East child index.
Quadtree.SOUTH_EAST = 2

---North West child index.
Quadtree.NORTH_WEST = 3

---North East child index.
Quadtree.NORTH_EAST = 4

---Creates a new Quadtree node with an empty list of
---points at a given level. The capacity specifies
---the number of points the node can hold before it
---is split into children.
---@param bounds Bounds2 bounding area
---@param capacity integer point capacity
---@param level integer|nil level, or depth
---@return Quadtree
function Quadtree.new(bounds, capacity, level)
    local inst = setmetatable({}, Quadtree)
    inst.bounds = bounds or Bounds2.unitSquareSigned()
    inst.capacity = capacity or 16
    inst.children = {}
    inst.level = level or 1
    inst.points = {}

    if inst.capacity < 1 then inst.capacity = 1 end
    if inst.level < 1 then inst.level = 1 end

    return inst
end

function Quadtree:__le(b)
    return self.bounds <= b.bounds
end

function Quadtree:__len()
    return Quadtree.countPoints(self)
end

function Quadtree:__lt(b)
    return self.bounds < b.bounds
end

function Quadtree:__tostring()
    return Quadtree.toJson(self)
end

---Counts the number of leaves held by this node.
---Returns 1 if the node is itself a leaf.
---@param q Quadtree quadtree
---@return integer
function Quadtree.countLeaves(q)
    -- Even if this is not used directly by
    -- any dialog, retain it for diagnostics.
    local children = q.children
    local lenChildren = #children
    if lenChildren < 1 then return 1 end

    local sum = 0
    local i = 0
    while i < lenChildren do
        i = i + 1
        local child = children[i]
        sum = sum + Quadtree.countLeaves(child)
    end
    return sum
end

---Counts the number of points held by this quadtree's
---leaf nodes.
---@param q Quadtree quadtree
---@return integer
function Quadtree.countPoints(q)
    local children = q.children
    local lenChildren = #children
    if lenChildren < 1 then return #q.points end

    local sum = 0
    local i = 0
    while i < lenChildren do
        i = i + 1
        local child = children[i]
        sum = sum + Quadtree.countPoints(child)
    end
    return sum
end

---Inserts a point into the node by reference,
---not by value. Returns true if the point was
---successfully inserted into either the node or
---its children.
---@param q Quadtree quadtree
---@param point Vec2 point
---@return boolean
function Quadtree.insert(q, point)
    if Bounds2.containsInclExcl(q.bounds, point) then
        local children = q.children
        local lenChildren = #children
        local i = 0
        while i < lenChildren do
            i = i + 1
            local child = children[i]
            if Quadtree.insert(child, point) then
                return true
            end
        end

        if lenChildren < 1 then
            local points = q.points
            Vec2.insortRight(points, point, Vec2.comparator)
            if #points > q.capacity then
                Quadtree.split(q, q.capacity)
            end
            return true
        else
            -- Quadtree.split(q, q.capacity)
            -- return Quadtree.insert(q, point)
        end
    end

    return false
end

---Inserts an array of points into a node.
---Returns true if all point insertions succeeded.
---Otherwise, returns false.
---@param q Quadtree quadtree
---@param ins table insertions array
---@return boolean
function Quadtree.insertAll(q, ins)
    local lenIns = #ins
    local flag = true
    local i = 0
    while i < lenIns do
        i = i + 1
        flag = flag and Quadtree.insert(q, ins[i])
    end
    return flag
end

---Evaluates whether a node has any children.
---Returns true if not.
---@param q Quadtree quadtree
---@return boolean
function Quadtree.isLeaf(q)
    return #q.children < 1
end

---Finds the maximum level, or depth, of
---the node and its children.
---@param q Quadtree quadtree
---@return integer
function Quadtree.maxLevel(q)
    -- Even if this is not used directly by
    -- any dialog, retain it for diagnostics.
    local children = q.children
    local lenChildren = #children
    local maxLevel = q.level

    local i = 0
    while i < lenChildren do
        i = i + 1
        local child = children[i]
        local lvl = Quadtree.maxLevel(child)
        if lvl > maxLevel then
            maxLevel = lvl
        end
    end

    return maxLevel
end

---Queries the node with a circle. If a point can be
---found within the bounds, returns a point and
---distance from the query center. If a point cannot be
---found, returns a default point, which may be nil.
---@param q Quadtree quadtree
---@param center Vec2 circle center
---@param radius number circle radius
---@param dfPt Vec2|nil default point
---@return Vec2|nil
---@return number
function Quadtree.query(q, center, radius, dfPt)
    local radVerif = radius or 46340
    local v, dsq = Quadtree.queryInternal(q, center, radVerif)
    local d = math.sqrt(dsq)
    if v then
        return Vec2.new(v.x, v.y), d
    else
        return dfPt, d
    end
end

---Queries the node with a sphere. If a point can be
---found within the bounds, returns a point and
---square distance from the query center. If a point
---cannot be found, returns nil.
---@param q Quadtree quadtree
---@param center Vec2 circle center
---@param radius number circle radius
---@return Vec2|nil
---@return number
function Quadtree.queryInternal(q, center, radius)
    local nearPoint = nil
    local nearDistSq = 2147483647

    if Bounds2.intersectsCircle(q.bounds, center, radius) then
        local children = q.children
        local lenChildren = #children
        local i = 0
        while i < lenChildren do
            i = i + 1
            local child = children[i]
            local candDistSq = 2147483647
            local candPoint = nil
            candPoint, candDistSq = Quadtree.queryInternal(
                child, center, radius)
            if candPoint and (candDistSq < nearDistSq) then
                nearPoint = candPoint
                nearDistSq = candDistSq
            end
        end

        if lenChildren < 1 then
            local points = q.points
            local lenPoints = #points
            local rsq = radius * radius
            local distSq = Vec2.distSq

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

---Splits the quadtree node into four child nodes.
---If a child capacity is not provided, defaults
---to the parent's capacity.
---@param q Quadtree quadtree
---@param childCapacity integer|nil child capacity
---@return Quadtree
function Quadtree.split(q, childCapacity)
    local chCpVerif = childCapacity or q.capacity
    local children = q.children
    local nextLevel = q.level + 1

    local i = 0
    while i < 4 do
        i = i + 1
        children[i] = Quadtree.new(
            Bounds2.unitSquareSigned(),
            chCpVerif, nextLevel)
    end

    Bounds2.splitInternal(
        q.bounds, 0.5, 0.5,
        children[Quadtree.SOUTH_WEST].bounds,
        children[Quadtree.SOUTH_EAST].bounds,
        children[Quadtree.NORTH_WEST].bounds,
        children[Quadtree.NORTH_EAST].bounds)

    -- This is faster than looping through
    -- children in reverse and removing from
    -- the points table in the inner loop.
    local pts = q.points
    local ptsLen = #pts

    -- Inner loop has an irregular length due to
    -- early break, so this isn't flattened.
    local j = 0
    while j < ptsLen do
        j = j + 1
        local pt = pts[j]
        local k = 0
        while k < 4 do
            k = k + 1
            if Quadtree.insert(children[k], pt) then
                break
            end
        end
    end

    q.points = {}
    return q
end

---Returns a JSON string of the quadtree node.
---@param q Quadtree quadtree
---@return string
function Quadtree.toJson(q)
    local str = string.format("{\"level\":%d", q.level - 1)
    str = str .. ",\"bounds\":"
    str = str .. Bounds2.toJson(q.bounds)
    str = str .. ",\"capacity\":"
    str = str .. string.format("%d", q.capacity)

    if Quadtree.isLeaf(q) then
        str = str .. ",\"points\":["
        local pts = q.points
        local ptsLen = #pts
        local ptsStrs = {}

        local i = 0
        while i < ptsLen do
            i = i + 1
            ptsStrs[i] = Vec2.toJson(pts[i])
        end
        str = str .. table.concat(ptsStrs, ",")
        str = str .. "]"
    else
        str = str .. ",\"children\":["
        local children = q.children
        local childStrs = {}
        local lenChildren = #children
        local j = 0
        while j < lenChildren do
            j = j + 1
            local child = children[j]
            childStrs[j] = Quadtree.toJson(child)
        end
        str = str .. table.concat(childStrs, ",")
        str = str .. "]"
    end

    str = str .. "}"
    return str
end

return Quadtree