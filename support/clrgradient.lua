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

---Constructs a color gradient. The first parameter is a table of ClrKeys.
---@param keys ClrKey[] color keys
---@return ClrGradient
---@nodiscard
function ClrGradient.new(keys)
    local inst <const> = setmetatable({}, ClrGradient)
    inst.keys = {}
    if keys then
        local lenKeys <const> = #keys
        local i = 0
        while i < lenKeys do
            i = i + 1
            inst:insortRight(keys[i], 0.0005)
        end
    end
    return inst
end

---Constructs a color gradient. The first parameter is a table of ClrKeys.
---@param keys ClrKey[] color keys
---@return ClrGradient
---@nodiscard
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

---Inserts a color key into the keys array based on the index returned by
---bisectRight. Does not check for duplicates. Returns true if the key was
---successfully inserted.
---@param ck ClrKey color key
---@param tol number? tolerance
---@return boolean
function ClrGradient:insortRight(ck, tol)
    local eps <const> = tol or 0.0005
    local i <const> = ClrGradient.bisectRight(self, ck.step)
    local dupe <const> = self.keys[i - 1]
    if dupe and (math.abs(ck.step - dupe.step) <= eps) then
        return false
    end
    table.insert(self.keys, i, ck)
    return true
end

---Internal helper function to locate the insertion point for a step in the
---gradient so as to keep sorted order.
---@param cg ClrGradient color gradient
---@param step number step
---@return integer
---@nodiscard
function ClrGradient.bisectRight(cg, step)
    local keys <const> = cg.keys
    local low = 0
    local high = #keys
    while low < high do
        local middle <const> = (low + high) // 2
        if step < keys[1 + middle].step then
            high = middle
        else
            low = middle + 1
        end
    end
    return 1 + low
end

---Evaluates a color gradient by a step according to a dithering matrix. The
---matrix should be normalized in advance. The x and y coordinates are relative
---to the image. See https://www.wikiwand.com/en/Ordered_dithering/ .
---
---Unlike eval, returns a reference to a color in the gradient, not a new color.
---@param cg ClrGradient color gradient
---@param step number step
---@param matrix number[] matrix
---@param x integer x coordinate
---@param y integer y coordinate
---@param cols integer matrix columns
---@param rows integer matrix rows
---@return Clr
---@nodiscard
function ClrGradient.dither(
    cg, step, matrix,
    x, y, cols, rows)
    local prKey <const>, nxKey <const>, t <const> = ClrGradient.findKeys(
        cg, step)

    local prStep <const> = prKey.step
    local nxStep <const> = nxKey.step
    local range <const> = nxStep - prStep
    if range ~= 0.0 then
        local tScaled <const> = (t - prStep) / range
        local matIdx <const> = 1 + (x % cols) + (y % rows) * cols
        if tScaled >= matrix[matIdx] then
            return nxKey.clr
        end
    end

    return prKey.clr
end

---Evaluates a color gradient by a step with an easing function. Returns a
---color. The easing function is expected to accept an origin color, a
---destination color and a number as a step. If nil, it defaults to a mix in
---standard RGB.
---@param cg ClrGradient color gradient
---@param step number? step
---@param easing? fun(o: Clr, d: Clr, t: number): Clr easing function
---@return Clr
---@nodiscard
function ClrGradient.eval(cg, step, easing)
    local prKey <const>, nxKey <const>, t <const> = ClrGradient.findKeys(
        cg, step)
    local prStep <const> = prKey.step
    local nxStep <const> = nxKey.step
    local f <const> = easing or Clr.mixlRgbaInternal
    local denom = nxStep - prStep
    if denom ~= 0.0 then denom = 1.0 / denom end
    return f(prKey.clr, nxKey.clr,
        (t - prStep) * denom)
end

---Internal helper to find the previous and next key to ease between at the
---local level. Returns the previous key, the next key and the validated step.
---@param cg ClrGradient color gradient
---@param step number? step
---@return ClrKey
---@return ClrKey
---@return number
function ClrGradient.findKeys(cg, step)
    local keys <const> = cg.keys
    local lenKeys <const> = #keys
    local firstKey <const> = keys[1]
    local lastKey <const> = keys[lenKeys]

    local t = step or 0.5
    t = math.min(math.max(t,
        firstKey.step), lastKey.step)
    local nextIdx <const> = ClrGradient.bisectRight(cg, t)
    local prevIdx <const> = nextIdx - 1

    local prevKey <const> = keys[prevIdx] or firstKey
    local nextKey <const> = keys[nextIdx] or lastKey

    return prevKey, nextKey, t
end

---Evaluates a color gradient by a step according to interleaved gradient
---noise, IGN, developed by Jorge Jimenez.
---
---Unlike eval, returns a reference to a color in the gradient, not a new color.
---@param cg ClrGradient color gradient
---@param step number step
---@param x integer x coordinate
---@param y integer y coordinate
---@return Clr
---@nodiscard
function ClrGradient.noise(cg, step, x, y)
    local prKey <const>, nxKey <const>, t <const> = ClrGradient.findKeys(
        cg, step)
    local prStep <const> = prKey.step
    local nxStep <const> = nxKey.step
    local range <const> = nxStep - prStep

    -- Radial gradients had noticeable artifacts when mod (floor) was used
    -- instead of fmod (trunc). Time can be included with x + 5.588238
    -- * (frame % 64) and the same for y. See
    -- https://blog.demofox.org/2022/01/01/interleaved-
    -- gradient-noise-a-different-kind-of-low-
    -- discrepancy-sequence/
    if range ~= 0.0 then
        local tScaled <const> = (t - prStep) / range
        local ign <const> = math.fmod(52.9829189 * math.fmod(
            0.06711056 * x + 0.00583715 * y, 1.0), 1.0)
        if tScaled >= ign then
            return nxKey.clr
        end
    end

    return prKey.clr
end

---Returns a JSON string of a color gradient.
---@param cg ClrGradient color gradient
---@return string
---@nodiscard
function ClrGradient.toJson(cg)
    local str = "{\"keys\":["

    local keys <const> = cg.keys
    local lenKeys <const> = #keys
    local strArr <const> = {}
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