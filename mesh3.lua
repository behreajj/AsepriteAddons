dofile("./vec3.lua")
dofile("./mat4.lua")
dofile("./index3.lua")
dofile("./utilities.lua")

Mesh3 = {}
Mesh3.__index = Mesh3

setmetatable(Mesh3, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

---Constructs a 3D mesh with a variable
---number of vertices per face.
---@param fs table faces
---@param vs table coordinates
---@param vns table normals
---@param name string name
---@return table
function Mesh3.new(fs, vs, vns, name)
    local inst = {}
    setmetatable(inst, Mesh3)
    inst.fs = fs or {}
    inst.vs = vs or {}
    inst.vns = vns or {}
    inst.name = name or "Mesh3"
    return inst
end

function Mesh3:__len()
    return #self.fs
end

function Mesh3:__tostring()
    local str = "{ name: \""
    str = str .. self.name
    str = str .. "\", fs: [ "

    local fsLen = #self.fs
    for i = 1, fsLen, 1 do
        local f = self.fs[i]
        local fLen = #f
        str = str .. "[ "
        for j = 1, fLen, 1 do
            str = str .. tostring(f[j])
            if j < fLen then str = str .. ", " end
        end
        str = str .. " ]"
        if i < fsLen then str = str .. ", " end
    end

    str = str .. " ], vs: [ "

    local vsLen = #self.vs
    for i = 1, vsLen, 1 do
        str = str .. tostring(self.vs[i])
        if i < vsLen then str = str .. ", " end
    end

    str = str .. " ], vns: [ "

    local vnsLen = #self.vns
    for i = 1, vnsLen, 1 do
        str = str .. tostring(self.vns[i])
        if i < vnsLen then str = str .. ", " end
    end

    str = str .. " ] }"
    return str
end

---Creates a cube.
---@return table
function Mesh3.cube()

    local vsz = 0.5

    local fs = {
        { Index3.new(7, 1), Index3.new(8, 1), Index3.new(6, 1), Index3.new(5, 1) },
        { Index3.new(8, 2), Index3.new(4, 2), Index3.new(2, 2), Index3.new(6, 2) },
        { Index3.new(3, 3), Index3.new(7, 3), Index3.new(5, 3), Index3.new(1, 3) },
        { Index3.new(5, 4), Index3.new(6, 4), Index3.new(2, 4), Index3.new(1, 4) },
        { Index3.new(1, 5), Index3.new(2, 5), Index3.new(4, 5), Index3.new(3, 5) },
        { Index3.new(3, 6), Index3.new(4, 6), Index3.new(8, 6), Index3.new(7, 6) }
    }

    local vs = {
        Vec3.new(-vsz, -vsz, -vsz),
        Vec3.new(-vsz, -vsz, vsz),
        Vec3.new(-vsz, vsz, -vsz),
        Vec3.new(-vsz, vsz, vsz),
        Vec3.new(vsz, -vsz, -vsz),
        Vec3.new(vsz, -vsz, vsz),
        Vec3.new(vsz, vsz, -vsz),
        Vec3.new(vsz, vsz, vsz)
    }

    local vns = {
        Vec3.new(1.0, 0.0, 0.0),
        Vec3.new(0.0, 0.0, 1.0),
        Vec3.new(0.0, 0.0, -1.0),
        Vec3.new(0.0, -1.0, 0.0),
        Vec3.new(-1.0, 0.0, 0.0),
        Vec3.new(0.0, 1.0, 0.0)
    }

    return Mesh3.new(fs, vs, vns, "Cube")
end

return Mesh3