dofile("./clrkey.lua")

ClrGradient = {}
ClrGradient.__index = ClrGradient

setmetatable(ClrGradient, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

---Constructs a color gradient.
---The first parameter should be a table
---of ClrKeys.
---@param keys table color keys
---@param cl boolean closedLoop
---@return table
function ClrGradient.new(keys, cl)
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
        if step > keys[1 + middle].step then
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
    local t = step
    if cg.closedLoop then
        t = step % 1.0
    else
        t = math.min(math.max(step, 0.0), 1.0)
    end

    local prevKey = ClrGradient.findGe(cg, t)
    local nextKey = ClrGradient.findLe(cg, t)

    if prevKey > nextKey then
        local temp = prevKey
        prevKey = nextKey
        nextKey = temp
    end

    local prevStep = prevKey.step
    local nextStep = nextKey.step
    if prevStep == nextStep then
        local prvClr = prevKey.clr
        return Clr.new(prvClr.r, prvClr.g, prvClr.b, prvClr.a)
    end

    local num = t - prevStep
    local denom = nextStep - prevStep
    local g = easing or Clr.mixlRgbaInternal
    return g(prevKey.clr, nextKey.clr, num / denom)
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

---Finds a key less than or equal to the query.
---@param cg table color gradient
---@param step number query step
---@return table
function ClrGradient.findGe(cg, step)
    return cg.keys[ClrGradient.bisectLeft(cg, step)]
end

---Finds a key greater than or equal to the query.
---@param cg table color gradient
---@param step number query step
---@return table
function ClrGradient.findLe(cg, step)
    return cg.keys[ClrGradient.bisectRight(cg, step) - 1]
end

---Creates a color gradient from an array
---of colors. The colors are copied to the
---gradient by value.
---@param arr table color array
---@return table
function ClrGradient.fromColors(arr, cl)
    local len = #arr
    if len < 1 then
        return ClrGradient.new({
            ClrKey.newByRef(0.0, Clr.clearBlack()),
            ClrKey.newByRef(1.0, Clr.white()),
        }, cl)
    end

    if len < 2 then
        local c = arr[1]
        local za = Clr.new(c.r, c.g, c.b, 0.0)
        return ClrGradient.new({
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

    return ClrGradient.new(keys, cl)
end

---Generates a red-green-blue hue ramp.
---Contains seven colors and is a loop.
---Red is repeated at 0.0 and 1.0.
---@return table
function ClrGradient.rgb()
    return ClrGradient.new({
        ClrKey.newByRef(0.0, Clr.red()),
        ClrKey.newByRef(0.16666666666666666, Clr.yellow()),
        ClrKey.newByRef(0.3333333333333333, Clr.green()),
        ClrKey.newByRef(0.5, Clr.cyan()),
        ClrKey.newByRef(0.6666666666666666, Clr.blue()),
        ClrKey.newByRef(0.8333333333333334, Clr.magenta()),
        ClrKey.newByRef(1.0, Clr.red())
    }, true)
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