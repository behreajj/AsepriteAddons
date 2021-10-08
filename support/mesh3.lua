dofile("./vec2.lua")
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
---@param vts table texture coordinates
---@param vns table normals
---@param name string name
---@return table
function Mesh3.new(fs, vs, vts, vns, name)
    local inst = setmetatable({}, Mesh3)
    inst.fs = fs or {}
    inst.vs = vs or {}
    inst.vts = vts or {}
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
    return self:scaleVec3(v)
end

---Scales all coordinates in this mesh
---by a number
---@param n table uniform scalar
---@return table
function Mesh3:scaleNum(n)
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
function Mesh3:scaleVec3(v)
    if Vec3.all(v) then
        local vsLen = #self.vs
        for i = 1, vsLen, 1 do
            self.vs[i] = Vec3.hadamard(self.vs[i], v)
        end
    end
    return self
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
---@param size number cube size
---@return table
function Mesh3.cube(size)
    local fs = {
        { Index3.new(3,  7, 1), Index3.new(4,  8, 1), Index3.new(2,  4, 1), Index3.new(1,  3, 1) },
        { Index3.new(2,  4, 2), Index3.new(6,  5, 2), Index3.new(5,  2, 2), Index3.new(1,  1, 2) },
        { Index3.new(1, 13, 3), Index3.new(5, 14, 3), Index3.new(7, 12, 3), Index3.new(3, 11, 3) },
        { Index3.new(4,  8, 4), Index3.new(8,  9, 4), Index3.new(6,  5, 4), Index3.new(2,  4, 4) },
        { Index3.new(3, 11, 5), Index3.new(7, 12, 5), Index3.new(8,  9, 5), Index3.new(4,  8, 5) },
        { Index3.new(8,  9, 6), Index3.new(7, 10, 6), Index3.new(5,  6, 6), Index3.new(6,  5, 6) } }

    local szVal = size or 0.35355339059327373
    local vs = {
        Vec3.new(-szVal, -szVal, -szVal),
        Vec3.new( szVal, -szVal, -szVal),
        Vec3.new(-szVal,  szVal, -szVal),
        Vec3.new( szVal,  szVal, -szVal),
        Vec3.new(-szVal, -szVal,  szVal),
        Vec3.new( szVal, -szVal,  szVal),
        Vec3.new(-szVal,  szVal,  szVal),
        Vec3.new( szVal,  szVal,  szVal) }

    local vts = {
        Vec2.new(0.375, 0.0),
        Vec2.new(0.625, 0.0),
        Vec2.new(0.125, 0.25),
        Vec2.new(0.375, 0.25),
        Vec2.new(0.625, 0.25),
        Vec2.new(0.875, 0.25),
        Vec2.new(0.125, 0.50),
        Vec2.new(0.375, 0.50),
        Vec2.new(0.625, 0.50),
        Vec2.new(0.875, 0.50),
        Vec2.new(0.375, 0.75),
        Vec2.new(0.625, 0.75),
        Vec2.new(0.375, 1.0),
        Vec2.new(0.625, 1.0) }

    local vns = {
        Vec3.new( 0.0,  0.0, -1.0),
        Vec3.new( 0.0, -1.0,  0.0),
        Vec3.new(-1.0,  0.0,  0.0),
        Vec3.new( 1.0,  0.0,  0.0),
        Vec3.new( 0.0,  1.0,  0.0),
        Vec3.new( 0.0,  0.0,  1.0) }

    return Mesh3.new(fs, vs, vts, vns, "Cube")
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
        local fsStrArr = {}
        str = str .. "["
        for j = 1, fLen, 1 do
            fsStrArr[j] = Index3.toJson(f[j])
        end

        str = str .. table.concat(fsStrArr, ",")
        str = str .. "]"

        if i < fsLen then str = str .. "," end
    end

    str = str .. "],\"vs\":["

    local vs = a.vs
    local vsLen = #vs
    local vsStrArr = {}
    for i = 1, vsLen, 1 do
        vsStrArr[i] = Vec3.toJson(vs[i])
    end

    str = str .. table.concat(vsStrArr, ",")
    str = str .. "],\"vts\":["

    local vts = a.vts
    local vtsLen = #vts
    local vtsStrArr = {}
    for i = 1, vtsLen, 1 do
        vtsStrArr[i] = Vec2.toJson(vts[i])
    end

    str = str .. table.concat(vtsStrArr, ",")
    str = str .. "],\"vns\":["

    local vns = a.vns
    local vnsLen = #vns
    local vnsStrArr = {}
    for i = 1, vnsLen, 1 do
        vnsStrArr[i] = Vec3.toJson(vns[i])
    end

    str = str .. table.concat(vnsStrArr, ",")
    str = str .. "]}"
    return str
end

return Mesh3