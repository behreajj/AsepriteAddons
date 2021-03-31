dofile("./vec3.lua")
dofile("./index3.lua")

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
    local inst = setmetatable({}, Mesh3)
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
    return Mesh3.toJson(self)
end

---Rotates all coordinates in a mesh
---around the x axis by an angle in radians.
---@param radians number angle
---@return table
function Mesh3:rotateX(radians)
    return self:rotateXInternal(
        math.cos(radians),
        math.sin(radians))
end

---Rotates all coordinates in a mesh
---around the y axis by an angle in radians.
---@param radians number angle
---@return table
function Mesh3:rotateY(radians)
    return self:rotateYInternal(
        math.cos(radians),
        math.sin(radians))
end

---Rotates all coordinates in a mesh
---around the z axis by an angle in radians.
---@param radians number angle
---@return table
function Mesh3:rotateZ(radians)
    return self:rotateZInternal(
        math.cos(radians),
        math.sin(radians))
end

---Rotates all coordinates in a mesh
---around the x axis by the cosine and
---sine of an angle.
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return table
function Mesh3:rotateXInternal(cosa, sina)
    local vsLen = #self.vs
    for i = 1, vsLen, 1 do
        self.vs[i] = Vec3.rotateXInternal(
            self.vs[i], cosa, sina)
    end
    return self
end

---Rotates all coordinates in a mesh
---around the y axis by the cosine and
---sine of an angle.
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return table
function Mesh3:rotateYInternal(cosa, sina)
    local vsLen = #self.vs
    for i = 1, vsLen, 1 do
        self.vs[i] = Vec3.rotateYInternal(
            self.vs[i], cosa, sina)
    end
    return self
end

---Rotates all coordinates in a mesh
---around the z axis by the cosine and
---sine of an angle.
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return table
function Mesh3:rotateZInternal(cosa, sina)
    local vsLen = #self.vs
    for i = 1, vsLen, 1 do
        self.vs[i] = Vec3.rotateZInternal(
            self.vs[i], cosa, sina)
    end
    return self
end

---Scales all coordinates in a mesh.
---Defaults to scale by a vector.
---@param v table scalar
---@return table
function Mesh3:scale(v)
    return self:scaleByVec3(v)
end

---Scales all coordinates in this mesh
---by a number
---@param n table uniform scalar
---@return table
function Mesh3:scaleByNumber(n)
    if n ~= 0.0 then
        local vsLen = #self.vs
        for i = 1, vsLen, 1 do
            self.vs[i] = Vec3.scale(self.vs[i], n)
        end
    end
    return self
end

---Scales all coordinates in this mesh
---by a vector.
---@param v table nonuniform scalar
---@return table
function Mesh3:scaleByVec3(v)
    if Vec3.all(v) then
        local vsLen = #self.vs
        for i = 1, vsLen, 1 do
            self.vs[i] = Vec3.mul(self.vs[i], v)
        end
    end
    return self
end

---Returns a JSON string for a mesh.
---@param a table mesh
---@return string
function Mesh3.toJson(a)
    local str = "{\"name\":\""
    str = str .. a.name
    str = str .. "\",\"fs\":["

    local fs = a.fs
    local fsLen = #fs
    for i = 1, fsLen, 1 do
        local f = fs[i]
        local fLen = #f
        str = str .. "["
        for j = 1, fLen, 1 do
            str = str .. Index3.toJson(f[j])
            if j < fLen then str = str .. "," end
        end
        str = str .. "]"
        if i < fsLen then str = str .. "," end
    end

    str = str .. "],\"vs\":["

    local vs = a.vs
    local vsLen = #vs
    for i = 1, vsLen, 1 do
        str = str .. Vec3.toJson(vs[i])
        if i < vsLen then str = str .. ", " end
    end

    str = str .. "],\"vns\":["

    local vns = a.vns
    local vnsLen = #vns
    for i = 1, vnsLen, 1 do
        str = str .. Vec3.toJson(vns[i])
        if i < vnsLen then str = str .. "," end
    end

    str = str .. "]}"
    return str
end

---Translates all coordinates in a mesh
---by a vector.
---@param tr table translation
---@return table
function Mesh3:translate(tr)
    local vsLen = #self.vs
    for i = 1, vsLen, 1 do
        self.vs[i] = Vec3.add(self.vs[i], tr)
    end
    return self
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