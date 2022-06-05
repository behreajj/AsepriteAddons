dofile("./clr.lua")

ClrKey = {}
ClrKey.__index = ClrKey

setmetatable(ClrKey, {
    __call = function(cls, ...)
        return cls.new(...)
    end })

---Creates a new color key.
---Defaults to passing the color by value.
---@param step number step
---@param clr table|number color
---@return table
function ClrKey.new(step, clr)
    return ClrKey.newByVal(step, clr)
end

---Creates a new color key.
---The color is assigned by reference.
---The step is clamped to [0.0, 1.0].
---@param step number step
---@param clr table color
---@return table
function ClrKey.newByRef(step, clr)
    local inst = setmetatable({}, ClrKey)
    inst.step = 0.0
    if step then
        inst.step = math.min(math.max(step, 0.0), 1.0)
    end
    inst.clr = clr or Clr.clearBlack()
    return inst
end

---Creates a new color key.
---The color is copied by value.
---The step is clamped to [0.0, 1.0].
---@param step number step
---@param clr table|number color
---@return table
function ClrKey.newByVal(step, clr)
    local inst = setmetatable({}, ClrKey)

    inst.step = 0.0
    if step then
        inst.step = math.min(math.max(step, 0.0), 1.0)
    end

    inst.clr = nil
    if clr then
        if type(clr) == "number"
            and math.type(clr) == "integer" then
            inst.clr = Clr.fromHex(clr)
        else
            inst.clr = Clr.new(clr.r, clr.g, clr.b, clr.a)
        end
    else
        inst.clr = Clr.clearBlack()
    end

    return inst
end

function ClrKey:__eq(b)
    return self.step == b.step
end

function ClrKey:__le(b)
    return self.step <= b.step
end

function ClrKey:__lt(b)
    return self.step < b.step
end

function ClrKey:__tostring()
    return ClrKey.toJson(self)
end

---Returns a JSON string of a color key.
---@param ck table color key
---@return string
function ClrKey.toJson(ck)
    return string.format(
        "{\"step\":%.4f,\"clr\":%s}",
        ck.step,
        Clr.toJson(ck.clr))
end

return ClrKey
