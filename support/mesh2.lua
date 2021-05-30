dofile("./vec2.lua")

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
    local inst = setmetatable({}, Mesh2)
    inst.fs = fs or {}
    inst.vs = vs or {}
    inst.name = name or "Mesh2"
    return inst
end

function Mesh2:__len()
    return #self.fs
end

function Mesh2:__tostring()
    return Mesh2.toJson(self)
end

---Insets a face by calculating its center then
---easing from the face's vertices toward the center
---by the factor, in range [0.0, 1.0].
---@param faceIndex number
---@param fac number
---@return table
function Mesh2:insetFace(faceIndex, fac)
    local t = fac or 0.5

    if t <= 0.0 then
        return self
    end

    if t >= 1.0 then
        return self:subdivFaceFan(faceIndex)
    end

    local facesLen = #self.fs
    local i = 1 + (faceIndex - 1) % facesLen
    local face = self.fs[i]
    local faceLen = #face

    local vsOldLen = #self.vs
    local centerFace = {}

    local vCenter = Vec2.new(0.0, 0.0)
    for j = 1, faceLen, 1 do
        local vertCurr = face[j]
        vCenter = Vec2.add(vCenter, self.vs[vertCurr])
    end

    if faceLen > 0 then
        vCenter = Vec2.scale(vCenter, 1.0 / faceLen)
    end

    local u = 1.0 - t
    for j = 0, faceLen - 1, 1 do
        local k = (j + 1) % faceLen
        local vertCurr = face[1 + j]
        local vertNext = face[1 + k]

        local vCurr = self.vs[vertCurr]
        local vNew = Vec2.new(
            u * vCurr.x + t * vCenter.x,
            u * vCurr.y + t * vCenter.y)
        table.insert(self.vs, vNew)

        local vSubdivIdx = vsOldLen + j
        local fNew = {
            vertCurr,
            vertNext,
            1 + vsOldLen + k,
            1 + vSubdivIdx
        }

        table.insert(self.fs, fNew)
        table.insert(centerFace, 1 + vSubdivIdx)
    end

    table.insert(self.fs, centerFace)
    table.remove(self.fs, i)
    return self
end

---Rotates all coordinates in a mesh by
---an angle in radians.
---@param radians number angle
---@return table
function Mesh2:rotateZ(radians)
    return self:rotateZInternal(
        math.cos(radians),
        math.sin(radians))
end

---Rotates all coordinates in a mesh by
---the cosine and sine of an angle.
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return table
function Mesh2:rotateZInternal(cosa, sina)
    local vsLen = #self.vs
    for i = 1, vsLen, 1 do
        self.vs[i] = Vec2.rotateZInternal(
            self.vs[i], cosa, sina)
    end
    return self
end

---Scales all coordinates in a mesh.
---Defaults to scale by a vector.
---@param v table scalar
---@return table
function Mesh2:scale(v)
    return self:scaleVec2(v)
end

---Scales all coordinates in this mesh
---by a number
---@param n table uniform scalar
---@return table
function Mesh2:scaleNum(n)
    if n ~= 0.0 then
        local vsLen = #self.vs
        for i = 1, vsLen, 1 do
            self.vs[i] = Vec2.scale(self.vs[i], n)
        end
    end
    return self
end

---Scales all coordinates in this mesh
---by a vector.
---@param v table nonuniform scalar
---@return table
function Mesh2:scaleVec2(v)
    if Vec2.all(v) then
        local vsLen = #self.vs
        for i = 1, vsLen, 1 do
            self.vs[i] = Vec2.hadamard(self.vs[i], v)
        end
    end
    return self
end

---Scales each face of a mesh individually,
---based on its median center. Meshes should
---call uniformData first for best results.
---@param scale number scale
---@return table
function Mesh2:scaleFacesIndiv(scale)

    -- Validate that scale is non-zero.
    local vscl = nil
    if type(scale) == "number" then
        if scale ~= 0.0 then
            vscl = Vec2.new(scale, scale)
        else vscl = Vec2.new(1.0, 1.0) end
    else
        if Vec2.all(scale) then vscl = scale
        else vscl = Vec2.new(1.0, 1.0) end
    end

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

        if fLen > 0 then
            center = Vec2.scale(center, 1.0 / fLen)
        end

        -- Treat center as a pivot:
        -- Subtract center, scale, add center.
        for j = 1, fLen, 1 do
            local vert = f[j]
            local v = self.vs[vert]
            self.vs[vert] = Vec2.add(
                Vec2.hadamard(Vec2.sub(v,
                center), vscl), center)
        end
    end

    return self
end

---Subdivides a convex face by calculating its
---center, then connecting its vertices to the center.
---Generates a triangle for the number of edges
---in the face.
---@param faceIndex number face index
---@return table
function Mesh2:subdivFaceFan(faceIndex)

    local facesLen = #self.fs
    local i = 1 + (faceIndex - 1) % facesLen
    local face = self.fs[i]
    local faceLen = #face

    local vCenter = Vec2.new(0.0, 0.0)
    local vCenterIdx = 1 + #self.vs

    for j = 0, faceLen - 1, 1 do
        local k = (j + 1) % faceLen
        local vertCurr = face[1 + j]
        local vertNext = face[1 + k]

        vCenter = Vec2.add(vCenter, self.vs[vertCurr])

        local fNew = { vCenterIdx, vertCurr, vertNext }
        table.insert(self.fs, fNew)
    end

    if faceLen > 0 then
        vCenter = Vec2.scale(vCenter, 1.0 / faceLen)
    end

    table.remove(self.fs, i)
    table.insert(self.vs, vCenter)
    return self
end

---Translates all coordinates in a mesh
---by a vector.
---@param tr table translation
---@return table
function Mesh2:translate(tr)
    local vsLen = #self.vs
    for i = 1, vsLen, 1 do
        self.vs[i] = Vec2.add(self.vs[i], tr)
    end
    return self
end

---Creates an arc. Start and stop weights
---specify the inset of an oculus.
---Sectors specifies the number of sides
---to approximate a full circle.
---@param startAngle number start angle
---@param stopAngle number stop angle
---@param startWeight number start weight
---@param stopWeight number stop weight
---@param sectors number sectors
---@param useQuads boolean use quads
---@return table
function Mesh2.arc(
    startAngle,
    stopAngle,
    startWeight,
    stopWeight,
    sectors,
    useQuads)

    -- TODO: Needs to be refactored to use
    -- NGONs with n resolution per sector.
    local a = startAngle % 6.283185307179586
    local b = stopAngle % 6.283185307179586
    local arcLen = (b - a) % 6.283185307179586
    local c = a + arcLen

    -- If arc len is less than TAU / 720
    if arcLen < 0.00873 then
        local target = Mesh2.polygon(sectors)
        target.name = "Ring"
        target:rotateZ(startAngle)
        local r = math.min(0.999999, math.max(0.000001,
            0.5 * startWeight + stopWeight))
        target:insetFace(1, r)
        table.remove(target.fs, #target.fs)
        return target
    end

    local sctVal = math.max(3, sectors)
    local sctCount = math.ceil(1.0 + sctVal *
        arcLen * 0.15915494309189535)
    local sctCount2 = sctCount + sctCount

    local radius = 0.5
    local oculFac0 = math.min(math.max(startWeight,
        0.000001), 0.999999)
    local oculFac1 = math.min(math.max(stopWeight,
        0.000001), 0.999999)
    local oculRad0 = radius * (1.0 - oculFac0)
    local oculRad1 = radius * (1.0 - oculFac1)

    local vs = {}
    local fs = {}

    local toStep = 1.0 / (sctCount - 1.0)
    for i = 0, sctCount - 1, 1 do
        local t = i * toStep
        local u = 1.0 - t

        local oculRad = u * oculRad0 + t * oculRad1

        local theta = u * a + t * c
        local cosTheta = math.cos(theta)
        local sinTheta = math.sin(theta)

        -- TODO: Refactor to avoid table.insert
        table.insert(vs, Vec2.new(
            cosTheta * radius,
            sinTheta * radius))

        table.insert(vs, Vec2.new(
            cosTheta * oculRad,
            sinTheta * oculRad))
    end

    if useQuads then

        for k = 0, sctCount - 2, 1 do
            local i = k + k
            local f = {
                1 + i,
                3 + i,
                4 + i,
                2 + i }
            table.insert(fs, f)
        end

    else

        local f = {}
        for i = 0, sctCount - 1, 1 do
            local j = i + i
            f[1 + i] = 1 + j
            f[1 + sctCount + i] = 1 + (sctCount2 - 1) - j
        end
        table.insert(fs, f)

    end

    return Mesh2.new(fs, vs, "Arc")
end

---Creates a grid of bricks.
---The frequency describes interval before an offset.
---The aspect is the ratio of brick width to height.
---The offset is how far to displace offset rows.
---@param cols number columns
---@param rows number rows
---@param offset number offset
---@param aspect number ratio width / height
---@param freq number frequency
---@return table
function Mesh2.gridBricks(
    cols, rows,
    offset, aspect, freq)

    -- Assume defaults.
    local vcols = 4
    local vrows = 4
    local voff = 0.5
    local vasp = 2.0
    local vfrq = 2

    -- Validate inputs.
    if cols and cols > 2 then vcols = cols end
    if rows and rows > 2 then vrows = rows end
    if offset then
        voff = math.max(-1.0, math.min(1.0, offset))
    end
    if aspect and aspect ~= 0.0 then vasp = aspect end
    if freq and freq > 2 then vfrq = freq end

    local halfOff = voff * 0.5
    local invAspect = 1.0 / vasp

    local jToStep = 1.0 / vcols
    local iToStep = 1.0 / vrows

    local fs = {}
    local vs = {}

    local len2n1 = vcols * vrows - 1
    for k = 0, len2n1, 1 do
        local i = k // vcols
        local j = k % vcols

        local iStp0 = i * iToStep
        local iStp1 = (i + 1) * iToStep
        local y0 = invAspect * (0.5 - iStp0)
        local y1 = invAspect * (0.5 - iStp1)

        local x0 = 0.0
        local x1 = 0.0
        local useOffset = i % vfrq == 0
        if useOffset then
            x0 = (j - halfOff) * jToStep - 0.5
            x1 = (j + 1 - halfOff) * jToStep - 0.5
        else
            x0 = (j + halfOff) * jToStep - 0.5
            x1 = (j + 1 + halfOff) * jToStep - 0.5
        end

        local n4 = k * 4
        vs[1 + n4] = Vec2.new(x0, y0)
        vs[2 + n4] = Vec2.new(x1, y0)
        vs[3 + n4] = Vec2.new(x1, y1)
        vs[4 + n4] = Vec2.new(x0, y1)

        fs[1 + k] = { 1 + n4, 2 + n4, 3 + n4, 4 + n4 }
    end

    return Mesh2.new(fs, vs, "Bricks")
end

---Creates a grid of rectangles.
---@param cols number columns
---@param rows number rows
---@return table
function Mesh2.gridCartesian(cols, rows)

    -- Validate inputs.
    local cVal = cols or 2
    if cVal < 2 then cVal = 2 end
    local rVal = rows or cVal
    if rVal < 2 then rVal = 2 end

    -- Fence posting problem:
    -- There is one more edge than cell.
    local rVal1 = rVal + 1
    local cVal1 = cVal + 1

    -- Set vertex coordinates.
    local vs = {}
    local iToStep = 1.0 / rVal
    local jToStep = 1.0 / cVal
    local fLen1n1 = (rVal1 * cVal1) - 1
    for k = 0, fLen1n1, 1 do
        vs[1 + k] = Vec2.new(
            (k % cVal1) * jToStep - 0.5,
            (k // cVal1) * iToStep - 0.5)
    end

    -- Set face indices.
    local fs = {}
    local fLenn1 = (rVal * cVal) - 1
    for k = 0, fLenn1, 1 do
        local i = k // cVal
        local j = k % cVal

        local cOff0 = 1 + i * cVal1

        local c00 = cOff0 + j
        local c10 = c00 + 1
        local c01 = cOff0 + cVal1 + j
        local c11 = c01 + 1

        fs[1 + k] = { c00, c10, c11, c01 }
    end

    return Mesh2.new(fs, vs, "Grid.Cartesian")
end

---Creates a grid of rhombi.
---@param cells number cells
---@return table
function Mesh2.gridDimetric(cells)
    local mesh = Mesh2.gridCartesian(cells, cells)

    local vs = mesh.vs
    local vsLen = #vs
    for i = 1, vsLen, 1 do
        local vSrc = vs[i]
        vs[i] = Vec2.new(
            0.5  * vSrc.x - 0.5  * vSrc.y,
            0.25 * vSrc.x + 0.25 * vSrc.y)
    end

    mesh.name = "Grid.Dimetric"
    return mesh
end

---Creates a grid of hexagons in rings around
---a central cell.
---@param rings number
---@return table
function Mesh2.gridHex(rings)
    local vRings = 1
    if rings > 1 then vRings = rings end
    local vrad = 0.5
    local extent = vrad * 1.7320508075688772
    local halfExt = extent * 0.5
    local rad15 = vrad * 1.5
    local radrt32 = vrad * 0.8660254037844386
    local halfRad = vrad * 0.5

    local iMax = vRings - 1
    local iMin = -iMax

    local fs = {}
    local vs = {}
    local vIdx = 1
    for i = iMin, iMax, 1 do
        local jMin = iMin + math.max(0, -i)
        local jMax = iMax + math.min(0, -i)
        local iExt = i * extent

        for j = jMin, jMax, 1 do
            local x = iExt + j * halfExt
            local y = j * rad15

            local left = x - radrt32
            local right = x + radrt32
            local top = y + halfRad
            local bottom = y - halfRad

            table.insert(vs, Vec2.new(x, y + vrad))
            table.insert(vs, Vec2.new(left, top))
            table.insert(vs, Vec2.new(left, bottom))
            table.insert(vs, Vec2.new(x, y - vrad))
            table.insert(vs, Vec2.new(right, bottom))
            table.insert(vs, Vec2.new(right, top))

            local f = {
                vIdx    , vIdx + 1, vIdx + 2,
                vIdx + 3, vIdx + 4, vIdx + 5 }
            table.insert(fs, f)

            vIdx = vIdx + 6
        end
    end

    return Mesh2.new(fs, vs, "Grid.Hexagon")
end

---Creates a regular convex polygon
---@param sectors number sides
---@return table
function Mesh2.polygon(sectors)
    local vsect = 3
    if sectors > 3 then vsect = sectors end
    local vrad = 0.5
    local toTheta = 6.283185307179586 / vsect
    local vs = {}
    local f = {}
    for i = 0, vsect - 1, 1 do
        local theta = i * toTheta
        table.insert(vs, Vec2.new(
            vrad * math.cos(theta),
            vrad * math.sin(theta)))
        table.insert(f, 1 + i)
    end
    local fs = { f }

    local name = "Polygon"
    if vsect == 3 then name = "Triangle"
    elseif vsect == 4 then name = "Quadrilateral"
    elseif vsect == 5 then name = "Pentagon"
    elseif vsect == 6 then name = "Hexagon"
    elseif vsect == 7 then name = "Heptagon"
    elseif vsect == 8 then name = "Octagon"
    elseif vsect == 9 then name = "Enneagon"
    end

    return Mesh2.new(fs, vs, name)
end

---Separates a mesh into several meshes with one
---face per mesh.
---@param source table source mesh
---@param from number start index
---@param to number stop index
---@return table
function Mesh2.separateFaces(source, from, to)
    local meshes = {}
    local fsSrc = source.fs
    local vsSrc = source.vs
    local fsSrcLen = #fsSrc

    local origin = 1
    local dest = fsSrcLen

    if from and from > 1 then origin = from end
    if to and to < fsSrcLen then dest = to end

    for i = origin, dest, 1 do
        local fSrc = fsSrc[i]
        local fSrcLen = #fSrc
        local vsTrg = {}
        local fTrg = {}
        for j = 1, fSrcLen, 1 do
            local vertSrc = fSrc[j]
            local vSrc = vsSrc[vertSrc]
            local vTrg = Vec2.new(vSrc.x, vSrc.y) 
            table.insert(vsTrg, vTrg)
            table.insert(fTrg, j)
        end

        local mesh = Mesh2.new({ fTrg }, vsTrg, "Mesh2")
        table.insert(meshes, mesh)
    end

    return meshes
end

---Returns a JSON string for a mesh.
---@param a table mesh
---@return string
function Mesh2.toJson(a)
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
            str = str .. (f[j] - 1)
            if j < fLen then str = str .. "," end
        end
        str = str .. "]"
        if i < fsLen then str = str .. "," end
    end

    str = str .. "],\"vs\":["

    local vs = a.vs
    local vsLen = #vs
    for i = 1, vsLen, 1 do
        str = str .. Vec2.toJson(vs[i])
        if i < vsLen then str = str .. "," end
    end

    str = str .. "]}"
    return str
end

---Restructures the mesh so that each face index
---refers to unique data.
---@param source table source mesh
---@param target table target mesh
---@return table
function Mesh2.uniformData(source, target)
    local trg = target or source
    local fsTrg = {}
    local vsTrg = {}

    local fsSrc = source.fs
    local vsSrc = source.vs

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