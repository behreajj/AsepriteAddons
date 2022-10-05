dofile("./clrkey.lua")

---@class ClrGradient
---@field keys table color keys
ClrGradient = {}
ClrGradient.__index = ClrGradient

setmetatable(ClrGradient, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Constructs a color gradient. The first
---parameter should be a table of ClrKeys.
---@param keys table color keys
---@return ClrGradient
function ClrGradient.new(keys)
    local inst = setmetatable({}, ClrGradient)
    inst.keys = {}
    if keys then
        local lenKeys = #keys
        local i = 0
        while i < lenKeys do i = i + 1
            inst:insortRight(keys[i], 0.0005)
        end
    end
    return inst
end

---Constructs a color gradient.
---The first parameter should be a table
---of ClrKeys.
---@param keys table color keys
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

---Appends a color to the end of this gradient.
---Colors are copied by value, not passed by
---reference. Shifts existing keys to the left.
---@param clr Clr color
---@return ClrGradient
function ClrGradient:append(clr)
    self:compressKeysLeft(1)
    table.insert(self.keys,
        ClrKey.newByVal(1.0, clr))
    return self
end

---Appends an array of colors to the end of
---this gradient. Colors are copied by value,
---not passed by reference. Shifts existing
---keys to the left.
---@param clrs table color array
---@return ClrGradient
function ClrGradient:appendAll(clrs)
    local appLen = #clrs
    self:compressKeysLeft(appLen)
    local oldLen = #self.keys
    local denom = 1.0 / (oldLen + appLen - 1.0)
    local i = 0
    while i < appLen do
        i = i + 1
        local key = ClrKey.newByVal(
            (oldLen + i - 1) * denom,
            clrs[i])
        self.keys[oldLen + i] = key
    end
    return self
end

---Shifts existing keys to the left when a new
---color is appended the gradient without a key.
---@param added number count to add
---@return ClrGradient
function ClrGradient:compressKeysLeft(added)
    local len = #self.keys
    local scalar = 1.0 / (len + added - 1.0)
    local i = 0
    while i < len do
        i = i + 1
        local key = self.keys[i]
        key.step = key.step * (i - 1) * scalar
    end
    return self
end

---Shifts existing keys to the right when a new
---color is prepended the gradient without a key.
---@param added number count to add
---@return ClrGradient
function ClrGradient:compressKeysRight(added)
    local len = #self.keys
    local scalar = added / (len + added - 1.0)
    local coeff = 1.0 - scalar
    local i = 0
    while i < len do
        i = i + 1
        local key = self.keys[i]
        key.step = scalar + coeff * key.step
    end
    return self
end

---Inserts a color key into the keys array based
---on the index returned by bisectRight. Does not
---check for duplicates. Returns true if the key
---was successfully inserted.
---@param ck ClrKey color key
---@param tol number|nil tolerance
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

---Prepends a color to the start of this gradient.
---Colors are copied by value, not passed by
---reference. Shifts existing keys to the right.
---@param clr Clr color
---@return ClrGradient
function ClrGradient:prepend(clr)
    self:compressKeysRight(1)
    table.insert(self.keys, 0,
        ClrKey.newByVal(0.0, clr))
    return self
end

---Prepends an array of colors to the start of
---this gradient. Colors are copied by value,
---not passed by reference. Shifts existing
---keys to the right.
---@param clrs table color array
---@return ClrGradient
function ClrGradient:prependAll(clrs)
    local prpLen = #clrs
    self:compressKeysRight(prpLen)
    local oldLen = #self.keys

    -- Shift old keys with reverse loop.
    local h = oldLen + 1
    while h > 1 do
        h = h - 1
        self.keys[prpLen + h] = self.keys[h]
    end

    local denom = 1.0 / (oldLen + prpLen - 1.0)
    local i = 0
    while i < prpLen do
        i = i + 1
        local key = ClrKey.newByVal(
            (i - 1) * denom,
            clrs[i])
        self.keys[i] = key
    end
    return self
end

---Sorts the color keys in this gradient.
---@return ClrGradient
function ClrGradient:sort()
    table.sort(self.keys)
    return self
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

---Evaluates a color gradient by a step with
---an easing function. Returns a color.
---The easing function is expected to accept
---an origin color, a destination color,
---and a number as a step. If nil, it defaults
---to a mix in linear sRGB.
---@param cg ClrGradient color gradient
---@param step number step
---@param easing function|nil easing function
---@return Clr
function ClrGradient.eval(cg, step, easing)
    local t = step or 0.5
    local keys = cg.keys
    local lenKeys = #keys

    local firstKey = keys[1]
    local lastKey = keys[lenKeys]
    t = math.min(math.max(t,
        firstKey.step), lastKey.step)

    local nextIdx = ClrGradient.bisectRight(cg, t)
    local prevIdx = nextIdx - 1

    local prevKey = keys[prevIdx] or firstKey
    local nextKey = keys[nextIdx] or lastKey
    local prevStep = prevKey.step
    local nextStep = nextKey.step

    local f = easing or Clr.mixlRgbaInternal
    local denom = nextStep - prevStep
    if denom ~= 0.0 then denom = 1.0 / denom end
    return f(prevKey.clr, nextKey.clr,
        (t - prevStep) * denom)
end

---Evaluates a color gradient over a range of
---steps by a requested count.
---The easing function is expected to accept
---an origin color, a destination color,
---and a number as a step.
---@param cg ClrGradient color gradient
---@param count integer color count
---@param origin number|nil origin step
---@param dest number|nil destination step
---@param easing function|nil easing function
---@return table
function ClrGradient.evalRange(cg, count, origin, dest, easing)

    local vCount = count or 3
    if vCount < 3 then vCount = 3 end
    local vDest = dest or 1.0
    vDest = math.min(math.max(vDest, 0.0), 1.0)
    local vOrig = origin or 0.0
    vOrig = math.min(math.max(vOrig, 0.0), 1.0)

    local result = {}
    local toFac = 1.0 / (vCount - 1.0)
    local i = 0
    while i < vCount do
        local t = i * toFac
        local step = (1.0 - t) * vOrig + t * vDest
        i = i + 1
        result[i] = ClrGradient.eval(cg, step, easing)
    end

    return result
end

---Creates a color gradient from an array of
---colors. Colors are copied to the by value.
---If the gradient is a closed loop and the
---last color is unequal to the first, the first
---color is repeated at the end of the gradient.
---@param arr table color array
---@return ClrGradient
function ClrGradient.fromColors(arr)
    -- TODO: Create separate fromColorsInternal?
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

---Finds the range of the color gradient, typically
---[0.0, 1.0] or under. Equal to the step of the
---last color key minus the step of the first.
---Assumes order of color keys has been sustained.
---@param cg ClrGradient color gradient
---@return number
function ClrGradient.range(cg)
    return cg.keys[#cg.keys].step
        - cg.keys[1].step
end

---Creates a red-green-blue ramp.
---Contains seven colors and is a loop.
---Red is repeated at 0.0 and 1.0.
---@return ClrGradient
function ClrGradient.rgb()
    return ClrGradient.newInternal({
        ClrKey.newByRef(0.0, Clr.red()),
        ClrKey.newByRef(0.16666666666667, Clr.yellow()),
        ClrKey.newByRef(0.33333333333333, Clr.green()),
        ClrKey.newByRef(0.5, Clr.cyan()),
        ClrKey.newByRef(0.66666666666667, Clr.blue()),
        ClrKey.newByRef(0.83333333333333, Clr.magenta()),
        ClrKey.newByRef(1.0, Clr.red())
    })
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