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
    inst.bounds = bounds or Bounds3.unitCubeSigned()
    inst.capacity = capacity or 16
    inst.children = {
        nil, nil, nil, nil,
        nil, nil, nil, nil }
    inst.level = level or 0
    inst.points = {}

    if inst.capacity < 1 then inst.capacity = 1 end
    if inst.level < 0 then inst.level = 0 end

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

    -- https://github.com/python/cpython/blob/main/Lib/bisect.py
    -- http://lua-users.org/wiki/BinarySearch
    -- TODO: This can't be abstracted out because arr[middle]
    -- is an object without a defined < comparator.
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
---an octree. If empty nodes are not omitted
---then the center of a node's bounds is used.
---@param o table octree
---@param omitEmpty boolean omit empty nodes
---@return table
function Octree.centers(o, omitEmpty)
    local vOmit = omitEmpty or false

    local tinsert = table.insert
    local v3new = Vec3.new
    local b3center = Bounds3.center

    local leaves = Octree.leaves(o, {})
    local lenLeaves = #leaves
    local centers = {}

    for i = 1, lenLeaves, 1 do
        local leaf = leaves[i]
        local leafPoints = leaf.points
        local lenLeafPoints = #leafPoints

        if lenLeafPoints > 1 then
            local xSum = 0.0
            local ySum = 0.0
            local zSum = 0.0

            for j = 1, lenLeafPoints, 1 do
                local point = leafPoints[j]
                xSum = xSum + point.x
                ySum = ySum + point.y
                zSum = zSum + point.z
            end

            local lenInv = 1.0 / lenLeafPoints
            tinsert(centers, v3new(
                xSum * lenInv,
                ySum * lenInv,
                zSum * lenInv))
        elseif lenLeafPoints > 0 then
            local point = leafPoints[1]
            tinsert(centers, v3new(
                point.x, point.y, point.z))
        elseif not vOmit then
            tinsert(centers, b3center(leaf.bounds))
        end
    end
    return centers
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

        local ochl = o.children
        local isLeaf = true
        for i = 1, 8, 1 do
            local child = ochl[i]
            if child then
                isLeaf = false
                if Octree.insert(child, point) then
                    return true
                end
            end
        end

        if isLeaf then
            table.insert(o.points, point)
            -- TODO: Is sorting needed here?
            -- table.sort(o.points)
            if #o.points > o.capacity then
                Octree.split(o)
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

---Internal insertion function to assist with
---query arrays.
---@param arr table the array
---@param key table the insertion key
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
    local ochl = o.children
    for i = 1, 8, 1 do
        if ochl[i] then return false end
    end
    return true
end

---Gets a flat array of octree nodes without children,
---i.e., leaves. Appends leaves to an array if provided,
---otherwise creates a new array.
---@param o table octree node
---@param leaves table results array
---@return table
function Octree.leaves(o, leaves)
    local lvsVal = leaves or {}
    local ochl = o.children
    local isLeaf = true

    for i = 1, 8, 1 do
        local child = ochl[i]
        if child then
            isLeaf = false
            Octree.leaves(child, lvsVal)
        end
    end

    if isLeaf then
        table.insert(lvsVal, o)
    end

    return lvsVal
end

---Gets the maximum level of the node and
---its children.
---@param o table octree node
---@return number
function Octree.maxLevel(o)
    local mxLvl = o.level
    local ochl = o.children
    for i = 1, 8, 1 do
        local child = ochl[i]
        if child then
            local lvl = Octree.maxLevel(child)
            if lvl > mxLvl then mxLvl = lvl end
        end
    end
    return mxLvl
end

---Gets a flat array of points contained by an octree,
---including those of its children nodes. Appends points
---to an array if provided, otherwise creates a new array.
---@param o table octree node
---@param points table results array
---@return table
function Octree.points(o, points)
    local ptsVal = points or {}
    local ochl = o.children
    local isLeaf = true

    for i = 1, 8, 1 do
        local child = ochl[i]
        if child then
            isLeaf = false
            Octree.points(child, ptsVal)
        end
    end

    if isLeaf then
        local opts = o.points
        local optsLen = #opts
        for i = 1, optsLen, 1 do
            table.insert(ptsVal, opts[i])
        end
    end

    return ptsVal
end

---Queries the octree with a spherical range, returning
---points inside the range.
---@param o table octree
---@param center table sphere center
---@param radius number sphere radius
---@param limit number size limit on found table
---@return table
function Octree.querySpherical(o, center, radius, limit)
    local found = {}
    local valLimit = limit or 999999
    Octree.querySphericalInternal(o, center, radius,
        found, valLimit)

    local result = {}
    local foundLen = #found
    for i = 1, foundLen, 1 do
        result[i] = found[i].point
    end
    return result
end

---Queries the octree with a spherical range, returning
---an array where each entry is a table containing a point
---and a dist. The array should be sorted, but it does not
---check for duplicates.
---@param o table octree
---@param center table sphere center
---@param radius number sphere radius
---@param found table array containing results
---@param limit number size limit on found table
---@return table
function Octree.querySphericalInternal(
    o, center, radius, found, limit)

    if Bounds3.intersectsSphere(o.bounds, center, radius) then
        local children = o.children
        local isLeaf = true
        for i = 1, 8, 1 do
            local child = children[i]
            if child then
                isLeaf = false
                Octree.querySphericalInternal(
                    child, center, radius, found, limit)
            end
        end

        if isLeaf then
            local pts = o.points
            local ptsLen = #pts
            local rsq = radius * radius
            local distf = Vec3.distSq
            local insort = Octree.insortRight
            for i = 1, ptsLen, 1 do
                local pt = pts[i]
                local currDist = distf(center, pt)
                if currDist < rsq then
                    -- This would need to define an
                    -- lt comparator to work with a
                    -- generic insortRight.
                    insort(found,
                        { dist = currDist,
                          point = pt })
                end

                if #found >= limit then
                    return found
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
    local ochl = o.children
    local ocap = o.capacity

    for i = 1, 8, 1 do
        ochl[i] = Octree.new(
            Bounds3.unitCubeSigned(),
            ocap, nxtLvl)
    end

    Bounds3.splitInternal(
        o.bounds, 0.5, 0.5, 0.5,
        ochl[Octree.BACK_SOUTH_WEST].bounds,
        ochl[Octree.BACK_SOUTH_EAST].bounds,
        ochl[Octree.BACK_NORTH_WEST].bounds,
        ochl[Octree.BACK_NORTH_EAST].bounds,
        ochl[Octree.FRONT_SOUTH_WEST].bounds,
        ochl[Octree.FRONT_SOUTH_EAST].bounds,
        ochl[Octree.FRONT_NORTH_WEST].bounds,
        ochl[Octree.FRONT_NORTH_EAST].bounds)

    local pts = o.points
    local ptsLen = #pts
    for i = 1, ptsLen, 1 do
        local pt = pts[i]
        for j = 1, 8, 1 do
            local child = ochl[j]
            if Octree.insert(child, pt) then
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
    local str = string.format("{\"level\":%d", o.level)
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
        for i = 1, ptsLen, 1 do
            ptsStrs[i] = Vec3.toJson(pts[i])
        end
        str = str .. table.concat(ptsStrs, ",")
        str = str .. "]"
    else
        str = str .. ",\"children\":["
        local children = o.children
        local childStrs = {
            nil, nil, nil, nil,
            nil, nil, nil, nil }
        for i = 1, 8, 1 do
            local child = children[i]
            if child then
                childStrs[i] = Octree.toJson(child)
            else
                childStrs[i] = "null"
            end
        end
        str = str .. table.concat(childStrs, ",")
        str = str .. "]"
    end

    str = str .. "}"
    return str
end

return Octree