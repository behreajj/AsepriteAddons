dofile("./clrkey.lua")

ClrGradient = {}
ClrGradient.__index = ClrGradient

setmetatable(ClrGradient, {
    __call = function(cls, ...)
        return cls.new(...)
    end })

---Constructs a color gradient.
---The first parameter should be a table
---of ClrKeys. Sorts the color gradient's
---table of keys.
---@param keys table color keys
---@param cl boolean closedLoop
---@return table
function ClrGradient.new(keys, cl)
    local inst = setmetatable({}, ClrGradient)

    inst.keys = {}
    local lenKeys = #keys
    for i = 1, lenKeys, 1 do
        inst.keys[i] = keys[i]
    end
    table.sort(inst.keys)

    inst.closedLoop = cl or false
    return inst
end

---Constructs a color gradient.
---The first parameter should be a table
---of ClrKeys. Does not sort the table.
---@param keys table color keys
---@param cl boolean closedLoop
---@return table
function ClrGradient.newInternal(keys, cl)
    local inst = setmetatable({}, ClrGradient)
    inst.keys = keys or {}
    inst.closedLoop = cl or false
    return inst
end

function ClrGradient:__len()
    return #self.keys
end

function ClrGradient:__tostring()
    return ClrGradient.toJson(self)
end

---Appends a color to the end of the gradient.
---Shifts existing keys left.
---@param clr table color
---@return table
function ClrGradient:append(clr)
    self:compressKeysLeft(1)
    table.insert(self.keys,
        ClrKey.newByVal(1.0, clr))
    return self
end

---Appends an array of colors to the end of
---the gradient. Shifts existing keys left.
---@param clrs table color array
---@return table
function ClrGradient:appendAll(clrs)
    local len = #clrs
    self:compressKeysLeft(len)
    local oldLen = #self.keys
    local denom = 1.0 / (oldLen + len - 1.0)
    for i = 1, len, 1 do
        local key = ClrKey.newByVal(
            (oldLen + i - 1) * denom,
            clrs[i])
        table.insert(self.keys, key)
    end
    return self
end

---Shifts existing keys to the left when a new
---color is appended the gradient without a key.
---@param added number count to add
---@return table
function ClrGradient:compressKeysLeft(added)
    local len = #self.keys
    local scalar = 1.0 / (len + added - 1.0)
    for i = 1, len, 1 do
        local key = self.keys[i]
        key.step = key.step * (i - 1) * scalar
    end
    return self
end

---Shifts existing keys to the right when a new
---color is prepended the gradient without a key.
---@param added number count to add
---@return table
function ClrGradient:compressKeysRight(added)
    local len = #self.keys
    local scalar = added / (len + added - 1.0)
    local coeff = 1.0 - scalar
    for i = 1, len, 1 do
        local key = self.keys[i]
        key.step = scalar + coeff * key.step
    end
    return self
end

---Inserts a color key into the keys array based
---on the index returned by bisectLeft.
---@param ck table color key
---@return table
function ClrGradient:insortLeft(ck)
    local i = ClrGradient.bisectLeft(self, ck.step)
    table.insert(self.keys, i, ck)
    return self
end

---Inserts a color key into the keys array based
---on the index returned by bisectRight.
---@param ck table color key
---@return table
function ClrGradient:insortRight(ck)
    local i = ClrGradient.bisectRight(self, ck.step)
    table.insert(self.keys, i, ck)
    return self
end

---Prepends a color to the start of the gradient.
---Shifts existing keys right.
---@param clr table color
---@return table
function ClrGradient:prepend(clr)
    self:compressKeysRight(1)
    table.insert(self.keys, 0,
        ClrKey.newByVal(0.0, clr))
    return self
end

---Prepends an array of colors to the start of
---the gradient. Shifts existing keys right.
---@param clrs table color array
---@return table
function ClrGradient:prependAll(clrs)
    local len = #clrs
    self:compressKeysRight(len)
    local oldLen = #self.keys
    local denom = 1.0 / (oldLen + len - 1.0)
    for i = 1, len, 1 do
        local key = ClrKey.newByVal(
            (i - 1) * denom,
            clrs[i])
        table.insert(self.keys, i, key)
    end
    return self
end

---Internal helper function to locate the insertion
---point for a step in the gradient so as to keep
---sorted order.
---@param cg table color gradient
---@param step number step
---@return number
function ClrGradient.bisectLeft(cg, step)
    local keys = cg.keys
    local low = 0
    local high = #keys
    while low < high do
        local middle = (low + high) // 2
        if keys[1 + middle].step < step then
            low = middle + 1
        else
            high = middle
        end
    end
    return 1 + low
end

---Internal helper function to locate the insertion
---point for a step in the gradient so as to keep
---sorted order.
---@param cg table color gradient
---@param step number step
---@return number
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

---Evaluates a color gradient by a step with
---an easing function. Returns a color.
---The easing function is expected to accept
---an origin color, a destination color,
---and a number as a step.
---@param cg table color gradient
---@param step number step
---@param easing function easing function
---@return table
function ClrGradient.eval(cg, step, easing)
    local t = step or 0.5

    local cl = cg.closedLoop
    local keys = cg.keys
    local lenKeys = #keys

    if cl then
        t = t % 1.0
    elseif t <= keys[1].step then
        local clr = keys[1].clr
        return Clr.new(clr.r, clr.g, clr.b, clr.a)
    elseif t >= keys[lenKeys].step then
        local clr = keys[lenKeys].clr
        return Clr.new(clr.r, clr.g, clr.b, clr.a)
    end

    local nextIdx = ClrGradient.bisectRight(cg, t)
    local prevIdx = nextIdx - 1

    if cl then
        prevIdx = 1 + (prevIdx - 1) % lenKeys
        nextIdx = 1 + (nextIdx - 1) % lenKeys
    end

    local prevKey = keys[prevIdx]
    local nextKey = keys[nextIdx]
    local prevStep = prevKey.step
    local nextStep = nextKey.step

    -- print(string.format(
    --     "prevStep: %.6f, nextStep: %.6f",
    --     prevStep, nextStep))

    if prevStep ~= nextStep then

        -- local function remEuclid(a, b)
        --     local r = math.fmod(a, b)
        --     if r < 0.0 then return r + math.abs(b) end
        --     return r
        -- end

        -- Use Euclidean remainder here, not
        -- floor mod or trunc mod. The absolute
        -- value of the denominator is needed.
        local num = t - prevStep
        local denom = math.abs(nextStep - prevStep)
        local facLocal = num / denom
        facLocal = (num % denom) / denom
        -- print(string.format("facLocal: %.6f", facLocal))
        local g = easing or Clr.mixlRgbaInternal
        return g(prevKey.clr, nextKey.clr, facLocal)
    else
        local clr = prevKey.clr
        return Clr.new(clr.r, clr.g, clr.b, clr.a)
    end
end

---Evaluates a color gradient over a range of
---steps by a requested count.
---The easing function is expected to accept
---an origin color, a destination color,
---and a number as a step.
---@param cg table color gradient
---@param count number color count
---@param origin number origin step
---@param dest number destination step
---@param easing function easing function
---@return table
function ClrGradient.evalRange(
    cg, count, origin, dest,
    easing)

    local vDest = dest or 1.0
    local vOrig = origin or 0.0
    local vCount = count or 3

    local result = {}
    local toFac = 1.0 / (vCount - 1.0)
    for i = 1, vCount, 1 do
        local t = (i - 1) * toFac
        local step = (1.0 - t) * vOrig + t * vDest
        result[i] = ClrGradient.eval(cg, step, easing)
    end

    return result
end

---Creates a color gradient from an array
---of colors. The colors are copied to the
---gradient by value.
---@param arr table color array
---@return table
function ClrGradient.fromColors(arr, cl)
    local len = #arr
    if len < 1 then
        return ClrGradient.newInternal({
            ClrKey.newByRef(0.0, Clr.clearBlack()),
            ClrKey.newByRef(1.0, Clr.white()),
        }, cl)
    end

    if len < 2 then
        local c = arr[1]
        local za = Clr.new(c.r, c.g, c.b, 0.0)
        return ClrGradient.newInternal({
            ClrKey.newByRef(0.0, za),
            ClrKey.newByVal(1.0, c),
        }, cl)
    end

    local toStep = 1.0 / (len - 1)
    local keys = {}
    for i = 1, len, 1 do
        keys[i] = ClrKey.newByVal(
            (i - 1) * toStep, arr[i])
    end

    return ClrGradient.newInternal(keys, cl)
end

---Creates a red-green-blue ramp.
---Contains seven colors and is a loop.
---Red is repeated at 0.0 and 1.0.
---@return table
function ClrGradient.rgb()
    return ClrGradient.newInternal({
        ClrKey.newByRef(0.0, Clr.red()),
        ClrKey.newByRef(0.16666666666667, Clr.yellow()),
        ClrKey.newByRef(0.33333333333333, Clr.green()),
        ClrKey.newByRef(0.5, Clr.cyan()),
        ClrKey.newByRef(0.66666666666667, Clr.blue()),
        ClrKey.newByRef(0.83333333333333, Clr.magenta()),
        ClrKey.newByRef(1.0, Clr.red())
    }, true)
end

---Finds the span of the color gradient, typically
---[0.0, 1.0] or under. Equal to the step of the
---last color key minus the step of the first.
---Assumes order of color keys has been sustained.
---@param cg table color gradient
---@return number
function ClrGradient.span(cg)
    return cg.keys[#cg.keys].step
        - cg.keys[1].step
end

---Returns a JSON sring of a color gradient.
---@param cg table color gradient
---@return string
function ClrGradient.toJson(cg)
    local str = "{\"keys\":["

    local keys = cg.keys
    local keysLen = #keys
    local strArr = {}
    for i = 1, keysLen, 1 do
        strArr[i] = ClrKey.toJson(keys[i])
    end

    str = str .. table.concat(strArr, ",")
    str = str .. "]}"
    return str
end

return ClrGradient
