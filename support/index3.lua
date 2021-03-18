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
    local inst = {}
    setmetatable(inst, Index3)
    inst.v = v or 1
    inst.vn = vn or 1
    return inst
end

function Index3:__tostring()
    return string.format(
        "{ v: %03d, vn: %03d }",
        self.v,
        self.vn)
end

return Index3