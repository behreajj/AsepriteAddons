dofile("./rgb.lua")

---@class ClrKey
---@field public rgb Rgb color
---@field public step number step
ClrKey = {}
ClrKey.__index = ClrKey

setmetatable(ClrKey, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Creates a new color key. Defaults to passing the color by value.
---@param step number step
---@param clr Rgb|integer color
---@return ClrKey
---@nodiscard
function ClrKey.new(step, clr)
    return ClrKey.newByVal(step, clr)
end

---Creates a new color key. The color is assigned by reference. The step is
---clamped to [0.0, 1.0].
---@param step number step
---@param clr Rgb color
---@return ClrKey
---@nodiscard
function ClrKey.newByRef(step, clr)
    local inst <const> = setmetatable({}, ClrKey)
    inst.step = 0.0
    if step then
        inst.step = math.min(math.max(step, 0.0), 1.0)
    end
    inst.rgb = clr or Rgb.new(0.0, 0.0, 0.0, 0.0)
    return inst
end

---Creates a new color key. The color is copied by value. The step is clamped
---to [0.0, 1.0].
---@param step number step
---@param clr Rgb|integer color
---@return ClrKey
---@nodiscard
function ClrKey.newByVal(step, clr)
    local inst <const> = setmetatable({}, ClrKey)

    inst.step = 0.0
    if step then
        inst.step = math.min(math.max(step, 0.0), 1.0)
    end

    inst.rgb = nil
    if clr then
        if type(clr) == "number"
            and math.type(clr) == "integer" then
            inst.rgb = Rgb.fromHexAbgr32(clr)
        else
            inst.rgb = Rgb.new(clr.r, clr.g, clr.b, clr.a)
        end
    else
        inst.rgb = Rgb.new(0.0, 0.0, 0.0, 0.0)
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
---@param ck ClrKey color key
---@return string
---@nodiscard
function ClrKey.toJson(ck)
    return string.format(
        "{\"step\":%.4f,\"clr\":%s}",
        ck.step,
        Rgb.toJson(ck.rgb))
end

return ClrKey