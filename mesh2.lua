dofile("./vec2.lua")
dofile("./mat3.lua")
dofile("./utilities.lua")

Mesh2 = {}
Mesh2.__index = Mesh2

setmetatable(Mesh2, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

---Constructs a 2D mesh with a variable
---number of vertices per face.
---@param fs table faces
---@param vs table coordinates
---@param name string name
---@return table
function Mesh2.new(fs, vs, name)
    local inst = {}
    setmetatable(inst, Mesh2)
    inst.fs = fs or {}
    inst.vs = vs or {}
    inst.name = name or "Mesh2"
    return inst
end

function Mesh2:__len()
    return #self.fs
end

function Mesh2:__tostring()
    local str = "{ name: \""
    str = str .. self.name
    str = str .. "\", fs: [ "

    local fsLen = #self.fs
    for i = 1, fsLen, 1 do
        local f = self.fs[i]
        local fLen = #f
        str = str .. "[ "
        for j = 1, fLen, 1 do
            str = str .. f[j]
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
    str = str .. " ] }"

    return str
end

---Scales each face of a mesh individually,
---based on its median center. Meshes should
---call uniformData first for best results.
---@param scale number scale
---@return table
function Mesh2:scaleFacesIndiv(scale)

    -- Validate that scale is non-zero.
    local vscl = 1.0
    if scale ~= 0.0 then vscl = scale end

    local fsLen = #self.fs
    for i = 1, fsLen, 1 do
        local f = self.fs[i]
        local fLen = #f

        -- Find center.
        local center = Vec2.new(0.0, 0.0)
        for j = 1, fLen, 1 do
            local vert = f[j]
            local v = self.vs[vert]
            center = Vec2.add(center, v)
        end
        center = Vec2.scale(center, 1.0 / fLen)

        -- Treat center as a pivot:
        -- Subtract center, scale, add center.
        for j = 1, fLen, 1 do
            local vert = f[j]
            local v = self.vs[vert]
            self.vs[vert] = Vec2.add(
                Vec2.scale(Vec2.sub(v,
                center), vscl), center)
        end
    end

    return self
end

---Transforms a mesh by a matrix.
---The mesh is transformed in place.
---@param matrix table matrix
---@return table
function Mesh2:transform(matrix)

    local vsLen = #self.vs
    for i = 1, vsLen, 1 do
        self.vs[i] = Utilities.mulMat3Vec2(
            matrix, self.vs[i])
    end
    return self
end

---Creates a grid of rectangles.
---@param cols integer columns
---@param rows integer rows
---@return table
function Mesh2.gridCartesian(cols, rows)

    -- Create vertical positions in [-0.5, 0.5].
    local rval = 2
    if rows and rows > 2 then rval = rows end
    local rvaln1 = rval - 1
    local iToStep = 1.0 / rval
    local ys = {}
    for i = 0, rval, 1 do
        table.insert(ys, i * iToStep - 0.5)
    end

    -- Create horizontal positions in [-0.5, 0.5].
    local cval = rval
    if cols then
        cval = 2
        if cols > 2 then cval = cols end
    end
    local cvaln1 = cval - 1
    local cvalp1 = cval + 1
    local jToStep = 1.0 / cval
    local xs = {}
    for j = 0, cval, 1 do
        table.insert(xs, j * jToStep - 0.5)
    end

    -- Combine horizontal and vertical.
    local vs = {}
    for i = 0, rval, 1 do
        for j = 0, cval, 1 do
            local v = Vec2.new(xs[1 + j], ys[1 + i])
            table.insert(vs, v)
        end
    end

    -- Create faces.
    local fs = {}
    for i = 0, rvaln1, 1 do
        local noff0 = i * cvalp1
        local noff1 = noff0 + cvalp1
        for j = 0, cvaln1, 1 do
            local n00 = noff0 + j
            local n10 = n00 + 1
            local n01 = noff1  + j
            local n11 = n01 + 1

            -- Create face loop.
            local f = {}

            -- Insert vertices into loop.
            table.insert(f, 1 + n00)
            table.insert(f, 1 + n10)
            table.insert(f, 1 + n11)
            table.insert(f, 1 + n01)

            -- Insert face loop into faces.
            table.insert(fs, f)
        end
    end

    return Mesh2.new(fs, vs, "Grid")
end

---Creates a grid of rhombi
---@param cols integer columns
---@param rows integer rows
---@return table
function Mesh2.gridDimetric(cols, rows)
    local mesh = Mesh2.gridCartesian(cols, rows)

    -- local r = Mat3.fromRotZ(math.rad(45))
    -- local s = Mat3.fromScale(
    --     1.0 / math.sqrt(2.0),
    --     0.5 / math.sqrt(2.0))
    -- local m = Mat3.mul(s, r)

    local mat = Mat3.new(
        0.5, -0.5, 0.0,
        0.25, 0.25, 0.0,
        0.0, 0.0, 1.0)
    return mesh:transform(mat)
end

---Creates a regular convex polygon
---@param sectors integer sides
---@return table
function Mesh2.polygon(sectors)
    local vsect = 3
    if sectors > 3 then vsect = sectors end
    local toTheta = 6.283185307179586 / vsect
    local vs = {}
    local f = {}
    for i = 0, vsect - 1, 1 do
        local theta = i * toTheta
        local v = Vec2.new(
            0.5 * math.cos(theta),
            0.5 * math.sin(theta))
        table.insert(vs, v)
        table.insert(f, 1 + i)
    end
    local fs = { f }

    local name = "Polygon"
    if vsect == 3 then
        name = "Triangle"
    elseif vsect == 4 then
        name = "Rhombus"
    elseif vsect == 5 then
        name = "Pentagon"
    elseif vsect == 6 then
        name = "Hexagon"
    elseif vsect == 8 then
        name = "Octagon"
    end

    return Mesh2.new(fs, vs, name)
end

---Restructures the mesh so that each face index
---refers to unique data.
---@param source table source mesh
---@param target table target mesh
---@return table
function Mesh2.uniformData(source, target)
    local trg = target or source

    local fsSrc = source.fs
    local vsSrc = source.vs

    local fsTrg = {}
    local vsTrg = {}

    local k = 1
    local fsSrcLen = #fsSrc
    for i = 1, fsSrcLen, 1 do
        local fSrc = fsSrc[i]
        local fSrcLen = #fSrc
        local fTrg = {}

        for j = 1, fSrcLen, 1 do
            local vertSrc = fSrc[j]
            local vSrc = vsSrc[vertSrc]
            local vTrg = Vec2.new(vSrc.x, vSrc.y)
            table.insert(vsTrg, vTrg)
            table.insert(fTrg, k)
            k = k + 1
        end

        table.insert(fsTrg, fTrg)
    end

    trg.fs = fsTrg
    trg.vs = vsTrg
    return trg
end

return Mesh2