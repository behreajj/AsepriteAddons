Index3 = {}
Index3.__index = Index3

setmetatable(Index3, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

---Constructs a vertex index for a Mesh3.
---@param v integer coordinate index
---@param vn integer normal index
---@return table
function Index3.new(v, vn)
    local inst = setmetatable({}, Index3)
    inst.v = v or 1
    inst.vn = vn or 1
    return inst
end

function Index3:__tostring()
    return Index3.toJson(self)
end

---Returns a JSON string of an index.
---One is subtracted from the fields
---so indices will begin at zero.
---@param i table index
---@return string
function Index3.toJson(i)
    return string.format(
        "{\"v\":%d,\"vn\":%d}",
        i.v - 1, i.vn - 1)
end

return Index3