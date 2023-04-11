dofile("./clrkey.lua")

---@class ClrGradient
---@field protected keys ClrKey[] color keys
ClrGradient = {}
ClrGradient.__index = ClrGradient

setmetatable(ClrGradient, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Constructs a color gradient. The first
---parameter should be a table of ClrKeys.
---@param keys ClrKey[] color keys
---@return ClrGradient
function ClrGradient.new(keys)
    local inst = setmetatable({}, ClrGradient)
    inst.keys = {}
    if keys then
        local lenKeys = #keys
        local i = 0
        while i < lenKeys do
            i = i + 1
            inst:insortRight(keys[i], 0.0005)
        end
    end
    return inst
end

---Constructs a color gradient.
---The first parameter should be a table
---of ClrKeys.
---@param keys ClrKey[] color keys
---@return ClrGradient
function ClrGradient.newInternal(keys)
    local inst = setmetatable({}, ClrGradient)
    inst.keys = keys or {}
    return inst
end

function ClrGradient:__len()
    return #self.keys
end

function ClrGradient:__tostring()
    return ClrGradient.toJson(self)
end

---Inserts a color key into the keys array based
---on the index returned by bisectRight. Does not
---check for duplicates. Returns true if the key
---was successfully inserted.
---@param ck ClrKey color key
---@param tol number? tolerance
---@return boolean
function ClrGradient:insortRight(ck, tol)
    local eps = tol or 0.0005
    local i = ClrGradient.bisectRight(self, ck.step)
    local dupe = self.keys[i - 1]
    if dupe and (math.abs(ck.step - dupe.step) <= eps) then
        return false
    end
    table.insert(self.keys, i, ck)
    return true
end

---Internal helper function to locate the insertion
---point for a step in the gradient so as to keep
---sorted order.
---@param cg ClrGradient color gradient
---@param step number step
---@return integer
function ClrGradient.bisectRight(cg, step)
    local keys = cg.keys
    local low = 0
    local high = #keys
    while low < high do
        local middle = (low + high) // 2
        if step < keys[1 + middle].step then
            high = middle
        else
            low = middle + 1
        end
    end
    return 1 + low
end

---Evaluates a color gradient by a step according
---to a dithering matrix. The maximum and minimum
---elements of the matrix should be found in advance.
---The x and y coordinates are relative to the image.
---See
---https://www.wikiwand.com/en/Ordered_dithering/
---
---Unlike eval, returns a reference to a color in
---the gradient, not a new color.
---@param cg ClrGradient color gradient
---@param step number step
---@param matrix number[] matrix
---@param x integer x coordinate
---@param y integer y coordinate
---@param cols integer matrix columns
---@param rows integer matrix rows
---@param maxElm number max element
---@param minElm number min element
---@return Clr
function ClrGradient.dither(
    cg, step, matrix,
    x, y, cols, rows,
    maxElm, minElm)
    local keys = cg.keys
    local lenKeys = #keys
    local firstKey = keys[1]
    local lastKey = keys[lenKeys]

    -- Unlike eval, dither doesn't have to worry
    -- about normal map mixing, so use early return.
    if step <= firstKey.step or lenKeys < 2 then
        return firstKey.clr
    end
    if step >= lastKey.step then
        return lastKey.clr
    end

    local nextIdx = ClrGradient.bisectRight(cg, step)
    local prevIdx = nextIdx - 1

    local prevKey = keys[prevIdx] or firstKey
    local nextKey = keys[nextIdx] or lastKey

    local prevStep = prevKey.step
    local nextStep = nextKey.step
    local range = nextStep - prevStep
    local tScaled = 0.0
    if range ~= 0.0 then
        tScaled = (step - prevStep) / range
    end

    local matIdx = 1 + (x % cols) + (y % rows) * cols
    local query = matrix[matIdx]

    -- In a Bayer matrix, the maximum element is
    -- (rows * columns) - 1, e.g., 63 for 8 * 8.
    -- The minimum is 0. To get both origin and
    -- destination color into the gradient, 1
    -- needs to be added to minimum on the query
    -- side and 2 needs to be added on the left.
    if minElm + tScaled * (maxElm - minElm) < query then
        return prevKey.clr
    end
    return nextKey.clr
end

---Evaluates a color gradient by a step with
---an easing function. Returns a color.
---The easing function is expected to accept
---an origin color, a destination color,
---and a number as a step. If nil, it defaults
---to a mix in linear sRGB.
---@param cg ClrGradient color gradient
---@param step number? step
---@param easing function? easing function
---@return Clr
function ClrGradient.eval(cg, step, easing)
    local prevKey, nextKey, t = ClrGradient.findKeys(
        cg, step)
    local prevStep = prevKey.step
    local nextStep = nextKey.step
    local f = easing or Clr.mixlRgbaInternal
    local denom = nextStep - prevStep
    if denom ~= 0.0 then denom = 1.0 / denom end
    return f(prevKey.clr, nextKey.clr,
        (t - prevStep) * denom)
end

---Internal helper to find the previous and
---next key to ease between at the local level.
---Returns the previous key, the next key,
---and the validated step.
---@param cg ClrGradient color gradient
---@param step number? step
---@return ClrKey
---@return ClrKey
---@return number
function ClrGradient.findKeys(cg, step)
    local keys = cg.keys
    local lenKeys = #keys
    local firstKey = keys[1]
    local lastKey = keys[lenKeys]

    local t = step or 0.5
    t = math.min(math.max(t,
        firstKey.step), lastKey.step)
    local nextIdx = ClrGradient.bisectRight(cg, t)
    local prevIdx = nextIdx - 1

    local prevKey = keys[prevIdx] or firstKey
    local nextKey = keys[nextIdx] or lastKey

    return prevKey, nextKey, t
end

---Creates a color gradient from an array of
---colors. Colors are copied to the by value.
---If the gradient is a closed loop and the
---last color is unequal to the first, the first
---color is repeated at the end of the gradient.
---@param arr Clr[] color array
---@return ClrGradient
function ClrGradient.fromColors(arr)
    -- QUERY: Create separate fromColorsInternal?
    local len = #arr
    if len < 1 then
        return ClrGradient.newInternal({
            ClrKey.newByRef(0.0, Clr.clearBlack()),
            ClrKey.newByRef(1.0, Clr.white())
        })
    end

    if len < 2 then
        local c0 = arr[1]
        local c1 = nil
        local c2 = nil
        if c0 then
            if type(c0) == "number"
                and math.type(c0) == "integer" then
                c2 = Clr.fromHex(c0)
            else
                c2 = Clr.new(c0.r, c0.g, c0.b, c0.a)
            end
            c1 = Clr.new(c2.r, c2.g, c2.b, 0.0)
        else
            c2 = Clr.white()
            c1 = Clr.clearBlack()
        end
        return ClrGradient.newInternal({
            ClrKey.newByRef(0.0, c1),
            ClrKey.newByRef(1.0, c2)
        })
    end

    local toStep = 1.0 / (len - 1)
    local keys = {}
    local i = 0
    while i < len do
        local step = i * toStep
        i = i + 1
        keys[i] = ClrKey.newByVal(step, arr[i])
    end
    return ClrGradient.newInternal(keys)
end

---Returns a JSON sring of a color gradient.
---@param cg ClrGradient color gradient
---@return string
function ClrGradient.toJson(cg)
    local str = "{\"keys\":["

    local keys = cg.keys
    local lenKeys = #keys
    local strArr = {}
    local i = 0
    while i < lenKeys do
        i = i + 1
        strArr[i] = ClrKey.toJson(keys[i])
    end

    str = str .. table.concat(strArr, ",")
    str = str .. "]}"
    return str
end

return ClrGradient