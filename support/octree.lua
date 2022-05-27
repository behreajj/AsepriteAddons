dofile("./bounds3.lua")

Octree = {}
Octree.__index = Octree

setmetatable(Octree, {
    __call = function(cls, ...)
        return cls.new(...)
    end })

Octree.BACK_SOUTH_WEST = 1
Octree.BACK_SOUTH_EAST = 2
Octree.BACK_NORTH_WEST = 3
Octree.BACK_NORTH_EAST = 4
Octree.FRONT_SOUTH_WEST = 5
Octree.FRONT_SOUTH_EAST = 6
Octree.FRONT_NORTH_WEST = 7
Octree.FRONT_NORTH_EAST = 8

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
    return #self.points
end

function Octree:__lt(b)
    return self.bounds < b.bounds
end

function Octree:__tostring()
    return Octree.toJson(self)
end

---Internal sorting function to assist with
---query arrays.
---@param arr table the array
---@param dist number the point distance
---@return table
function Octree.bisectRight(arr, dist)
    local low = 0
    local high = #arr

    -- This can't be abstracted out because arr[1 + middle]
    -- is an object without a defined < comparator; and
    -- Octree shouldn't depend on Utilities.
    while low < high do
        local middle = (low + high) // 2
        if dist < arr[1 + middle].dist then
            high = middle
        else
            low = middle + 1
        end
    end

    return 1 + low
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
        if child then
            isLeaf = false
            Octree.centersMean(
                child, include, arrVerif)
        end
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
---@param o table
---@return boolean
function Octree.cull(o)
    local children = o.children
    local lenChildren = #children
    local cullThis = 0
    local i = lenChildren + 1
    while i > 1 do
        i = i - 1
        local child = children[i]
        if child then
            if Octree.cull(child) then
                -- children[i] = nil
                table.remove(children, i)
            else
                cullThis = cullThis + 1
            end
        else
            cullThis = cullThis + 1
        end
    end

    return (cullThis >= lenChildren)
        and (#o.points < 0)
end

---Inserts a point into the octree node by reference,
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
            if child then
                isLeaf = false
                if Octree.insert(child, point) then
                    return true
                end
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
        end
    end

    return false
end

---Inserts an array of points into an octree node.
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

---Internal insertion function to assist with
---query arrays.
---@param arr table array
---@param key table insertion key
---@return table
function Octree.insortRight(arr, key)
    local i = Octree.bisectRight(arr, key.dist)
    table.insert(arr, i, key)
    return arr
end

---Evaluates whether an octree node has
---any children. Returns true if not.
---Otherwise returns false.
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

---Queries the octree with a sphere. If a point can be
---found within the octree's bounds returns a point and
---distance from the query center. If a point cannot be
---found, returns a default point, which may be nil.
---@param o table octree
---@param center table sphere center
---@param radius number sphere radius
---@param dfPt table|nil
---@return table|nil
---@return number
function Octree.query(o, center, radius, dfPt)
    local v, d = Octree.queryInternal(o, center, radius)
    if v then
        return Vec3.new(v.x, v.y, v.z), d
    else
        return dfPt, d
    end
end

---Queries the octree with a sphere. If a point can be
---found within the octree's bounds returns a point and
---distance from the query center. If a point cannot be
---found, returns nil.
---@param o table octree
---@param center table sphere center
---@param radius number sphere radius
---@return table|nil
---@return number
function Octree.queryInternal(o, center, radius)
    local nearPoint = nil
    local nearDist = 2147483647

    if Bounds3.intersectsSphere(o.bounds, center, radius) then
        local children = o.children
        local lenChildren = #children
        local isLeaf = true
        local i = 0
        while i < lenChildren do
            i = i + 1
            local child = children[i]
            if child then
                isLeaf = false
                local candDist = 2147483647
                local candPoint = nil
                candPoint, candDist = Octree.queryInternal(
                    child, center, radius)
                if candPoint and (candDist < nearDist) then
                    nearPoint = candPoint
                    nearDist = candDist
                end
            end
        end

        if isLeaf then
            local points = o.points
            local lenPoints = #points
            local rsq = radius * radius
            local distf = Vec3.distSq

            local j = 0
            while j < lenPoints do
                j = j + 1
                local point = points[j]
                local candDist = distf(center, point)
                if (candDist < rsq) and (candDist < nearDist) then
                    nearPoint = point
                    nearDist = candDist
                end
            end
        end
    end

    return nearPoint, nearDist
end

---Splits the octree node into eight child nodes.
---If a child capacity is not provided, defaults
---to the parent's capacity.
---@param o table octree node
---@param childCapacity number child capacity
---@return table
function Octree.split(o, childCapacity)
    local nxtLvl = o.level + 1
    local children = o.children
    local chCpVerif = childCapacity or o.capacity

    local i = 0
    while i < 8 do
        i = i + 1
        children[i] = Octree.new(
            Bounds3.unitCubeSigned(),
            chCpVerif, nxtLvl)
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

---Returns a JSON string of the octree node.
---@param o table octree
function Octree.toJson(o)
    local str = string.format("{\"level\":%d", o.level - 1)
    str = str .. ",\"bounds\":"
    str = str .. Bounds3.toJson(o.bounds)
    str = str .. ",\"capacity\":"
    str = str .. string.format("%d", o.capacity)

    -- Cannot use shortcuts here. Octree node
    -- should be determined to be a leaf first, before
    -- any string concatenation is done!!
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
            if child then
                childStrs[j] = Octree.toJson(child)
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

return Octree
