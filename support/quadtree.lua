dofile("./bounds2.lua")

Quadtree = {}
Quadtree.__index = Quadtree

setmetatable(Quadtree, {
    __call = function(cls, ...)
        return cls.new(...)
    end })

Quadtree.SOUTH_WEST = 1
Quadtree.SOUTH_EAST = 2
Quadtree.NORTH_WEST = 3
Quadtree.NORTH_EAST = 4

---Creates a new Quadtree node with an empty list of
---points at a given level. The capacity specifies
---the number of points the node can hold before it
---is split into children.
---@param bounds table bounding area
---@param capacity number point capacity
---@param level number level, or depth
---@return table
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
    return #self.points
end

function Quadtree:__lt(b)
    return self.bounds < b.bounds
end

function Quadtree:__tostring()
    return Quadtree.toJson(self)
end

---Counts the number of leaves held by this node.
---Returns 1 if the node is itself a leaf.
---@param q table quadtreee
---@return number
function Quadtree.countLeaves(q)
    -- Even if this is not used directly by
    -- any dialog, retain it for diagnostics.
    local children = q.children
    local lenChildren = #children
    local isLeaf = true
    local sum = 0

    local i = 0
    while i < lenChildren do
        i = i + 1
        local child = children[i]
        if child then
            isLeaf = false
            sum = sum + Quadtree.countLeaves(child)
        end
    end

    if isLeaf then return 1 end
    return sum
end

---Counts the number of points held by this quadtree's
---leaf nodes.
---@param o table quadtree node
---@return number
function Quadtree.countPoints(o)
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
        if child then
            isLeaf = false
            sum = sum + Quadtree.countPoints(child)
        end
    end

    if isLeaf then sum = sum + #o.points end
    return sum
end

---Inserts a point into the node by reference,
---not by value. Returns true if the point was
---successfully inserted into either the node or
---its children.
---@param q table octree node
---@param point table point
---@return boolean
function Quadtree.insert(q, point)
    if Bounds2.containsInclExcl(q.bounds, point) then
        local children = q.children
        local lenChildren = #children
        local isLeaf = true
        local i = 0
        while i < lenChildren do
            i = i + 1
            local child = children[i]
            if child then
                isLeaf = false
                if Quadtree.insert(child, point) then
                    return true
                end
            end
        end

        if isLeaf then
            local points = q.points
            Vec2.insortRight(points, point, Vec2.comparator)
            if #points > q.capacity then
                Quadtree.split(q, q.capacity)
            end
            return true
        else
            -- TODO: What if a child node had
            -- been culled and needs to be recreated?
        end
    end

    return false
end

---Evaluates whether a node has any children.
---Returns true if not.
---@param q table quadtree node
---@return boolean
function Quadtree.isLeaf(q)
    local children = q.children
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
---@param q table quadtree node
---@return number
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
        if child then
            local lvl = Quadtree.maxLevel(child)
            if lvl > maxLevel then
                maxLevel = lvl
            end
        end
    end
    return maxLevel
end

---Queries the node with a circle. If a point can be
---found within the bounds, returns a point and
---distance from the query center. If a point cannot be
---found, returns a default point, which may be nil.
---@param q table quadtree
---@param center table circle center
---@param radius number circle radius
---@param dfPt table|nil default point
---@return table|nil
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
---@param q table quadtree
---@param center table circle center
---@param radius number circle radius
---@return table|nil
---@return number
function Quadtree.queryInternal(q, center, radius)
    local nearPoint = nil
    local nearDistSq = 2147483647

    if Bounds2.intersectsCircle(q.bounds, center, radius) then
        local children = q.children
        local lenChildren = #children
        local isLeaf = true
        local i = 0
        while i < lenChildren do
            i = i + 1
            local child = children[i]
            if child then
                isLeaf = false
                local candDistSq = 2147483647
                local candPoint = nil
                candPoint, candDistSq = Quadtree.queryInternal(
                    child, center, radius)
                if candPoint and (candDistSq < nearDistSq) then
                    nearPoint = candPoint
                    nearDistSq = candDistSq
                end
            end
        end

        if isLeaf then
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
---@param q table quadtree
---@param childCapacity number child capacity
---@return table
function Quadtree.split(q, childCapacity)
    local chCpVerif = childCapacity or q.capacity
    local children = q.children
    local nextLevel = q.level + 1

    local i = 0
    while i < 4 do
        i = i + 1
        -- TODO: Account for scenario where a child
        -- has been culled and needs to be recreated.
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
---@param q table quadtree
function Quadtree.toJson(q)
    local str = string.format("{\"level\":%d", q.level - 1)
    str = str .. ",\"bounds\":"
    str = str .. Bounds2.toJson(q.bounds)
    str = str .. ",\"capacity\":"
    str = str .. string.format("%d", q.capacity)

    -- Node should be a leaf first, before
    -- any string concatenation is done.
    local isLeaf = Quadtree.isLeaf(q)

    if isLeaf then
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
            if child then
                childStrs[j] = Quadtree.toJson(child)
            else
                childStrs[j] = "null"
            end
        end
        str = str .. table.concat(childStrs, ",")
        str = str .. "]"
    end

    str = str .. "}"
    return str
end

return Quadtree
