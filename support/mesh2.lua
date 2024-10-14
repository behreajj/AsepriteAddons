dofile("./vec2.lua")

---@class Mesh2
---@field public fs integer[][] faces
---@field public name string name
---@field public vs Vec2[] coordinates
---@operator len(): integer
Mesh2 = {}
Mesh2.__index = Mesh2

setmetatable(Mesh2, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Constructs a 2D mesh with a variable number of vertices per face.
---@param fs integer[][] faces
---@param vs Vec2[] coordinates
---@param name string? name
---@return Mesh2
function Mesh2.new(fs, vs, name)
    local inst <const> = setmetatable({}, Mesh2)
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

---Insets a face by calculating its center then easing from the face's vertices
---toward the center by the factor, in [0.0, 1.0]. The factor defaults to 0.5.
---@param faceIndex integer face index
---@param fac number? inset factor
---@return Mesh2
function Mesh2:insetFace(faceIndex, fac)
    local t <const> = fac or 0.5

    if t <= 0.0 then
        return self
    end
    if t >= 1.0 then
        return self:subdivFaceFan(faceIndex)
    end

    local facesLen <const> = #self.fs
    local i <const> = 1 + (faceIndex - 1) % facesLen
    local face <const> = self.fs[i]
    local faceLen <const> = #face
    local vsOldLen <const> = #self.vs

    ---@type integer[]
    local centerFace <const> = {}

    -- Find center.
    local vCenter = Vec2.new(0.0, 0.0)
    local h = 0
    while h < faceLen do
        h = h + 1
        local vertCurr <const> = face[h]
        vCenter = Vec2.add(vCenter, self.vs[vertCurr])
    end
    if faceLen > 0 then
        vCenter = Vec2.scale(vCenter, 1.0 / faceLen)
    end

    local u <const> = 1.0 - t
    local j = 0
    while j < faceLen do
        j = j + 1
        local k <const> = 1 + j % faceLen
        local vertCurr <const> = face[j]
        local vertNext <const> = face[k]

        local vCurr <const> = self.vs[vertCurr]
        local vNew <const> = Vec2.new(
            u * vCurr.x + t * vCenter.x,
            u * vCurr.y + t * vCenter.y)
        self.vs[vsOldLen + j] = vNew

        local vSubdivIdx <const> = vsOldLen + j

        ---@type integer[]
        local fNew <const> = {
            vertCurr,
            vertNext,
            vsOldLen + k,
            vSubdivIdx
        }

        self.fs[facesLen + j] = fNew
        centerFace[j] = 1 + vSubdivIdx
    end

    self.fs[#self.fs + 1] = centerFace
    table.remove(self.fs, i)
    return self
end

---Rotates all coordinates in a mesh by an angle in radians.
---@param radians number angle
---@return Mesh2
function Mesh2:rotateZ(radians)
    -- Used by arc early return.
    return self:rotateZInternal(math.cos(radians), math.sin(radians))
end

---Rotates all coordinates in a mesh by the cosine and sine of an angle.
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return Mesh2
function Mesh2:rotateZInternal(cosa, sina)
    local vsLen <const> = #self.vs
    local i = 0
    while i < vsLen do
        i = i + 1
        self.vs[i] = Vec2.rotateZInternal(
            self.vs[i], cosa, sina)
    end
    return self
end

---Scales each face of a mesh individually, based on its median center. Meshes
---should call uniformData first for best results.
---@param scale Vec2|number scale
---@return Mesh2
function Mesh2:scaleFacesIndiv(scale)
    -- Validate that scale is non-zero.
    local vscl = nil
    if type(scale) == "number" then
        if scale ~= 0.0 then
            vscl = Vec2.new(scale, scale)
        else
            vscl = Vec2.new(1.0, 1.0)
        end
    else
        if Vec2.all(scale) then
            vscl = scale
        else
            vscl = Vec2.new(1.0, 1.0)
        end
    end

    local fsLen <const> = #self.fs
    local i = 0
    while i < fsLen do
        i = i + 1
        local f <const> = self.fs[i]
        local fLen <const> = #f

        -- Find center.
        local center = Vec2.new(0.0, 0.0)
        local j = 0
        while j < fLen do
            j = j + 1
            local vert <const> = f[j]
            local v <const> = self.vs[vert]
            center = Vec2.add(center, v)
        end

        if fLen > 0 then
            center = Vec2.scale(center, 1.0 / fLen)
        end

        -- Treat center as a pivot:
        -- Subtract center, scale, add center.
        local k = 0
        while k < fLen do
            k = k + 1
            local vert <const> = f[k]
            local v <const> = self.vs[vert]
            self.vs[vert] = Vec2.add(
                Vec2.hadamard(Vec2.sub(
                    v, center), vscl), center)
        end
    end

    return self
end

---Subdivides a convex face by calculating its center, then connecting its
---vertices to the center. Generates a triangle for the number of edges in the
---face.
---@param faceIndex integer face index
---@return Mesh2
function Mesh2:subdivFaceFan(faceIndex)
    local facesLen <const> = #self.fs
    local i <const> = 1 + (faceIndex - 1) % facesLen
    local face <const> = self.fs[i]
    local faceLen <const> = #face

    local vCenter = Vec2.new(0.0, 0.0)
    local vCenterIdx <const> = 1 + #self.vs

    for j = 0, faceLen - 1, 1 do
        local k <const> = (j + 1) % faceLen
        local vertCurr <const> = face[1 + j]
        local vertNext <const> = face[1 + k]

        vCenter = Vec2.add(vCenter, self.vs[vertCurr])

        local fNew <const> = { vCenterIdx, vertCurr, vertNext }
        self.fs[#self.fs + 1] = fNew
    end

    if faceLen > 0 then
        vCenter = Vec2.scale(vCenter, 1.0 / faceLen)
    end

    table.remove(self.fs, i)
    self.vs[#self.vs + 1] = vCenter
    return self
end

---Creates an arc. Start and stop weights specify the inset of an oculus.
---Sectors specifies the number of sides to approximate a full circle.
---@param startAngle number start angle
---@param stopAngle number stop angle
---@param startWeight number start weight
---@param stopWeight number stop weight
---@param sectors integer sectors
---@param useQuads boolean? use quads
---@return Mesh2
function Mesh2.arc(
    startAngle, stopAngle,
    startWeight, stopWeight,
    sectors, useQuads)
    local a <const> = startAngle % 6.2831853071796
    local b <const> = stopAngle % 6.2831853071796
    local arcLen <const> = (b - a) % 6.2831853071796
    local c <const> = a + arcLen

    -- If arc len is less than TAU / 720
    if arcLen < 0.00873 then
        local target <const> = Mesh2.polygon(sectors)
        target.name = "Ring"
        target:rotateZ(startAngle)
        local r <const> = math.min(0.999999, math.max(0.000001,
            0.5 * startWeight + stopWeight))
        target:insetFace(1, r)
        table.remove(target.fs, #target.fs)
        return target
    end

    local sctVal <const> = math.max(3, sectors)
    local sctCount <const> = math.ceil(1.0 + sctVal *
        arcLen * 0.1591549430919)
    local sctCount2 <const> = sctCount + sctCount

    local radius <const> = 0.5
    local oculFac0 <const> = math.min(math.max(startWeight,
        0.000001), 0.999999)
    local oculFac1 <const> = math.min(math.max(stopWeight,
        0.000001), 0.999999)
    local oculRad0 <const> = radius * (1.0 - oculFac0)
    local oculRad1 <const> = radius * (1.0 - oculFac1)

    ---@type Vec2[]
    local vs <const> = {}
    ---@type integer[][]
    local fs <const> = {}

    local cos <const> = math.cos
    local sin <const> = math.sin
    local toStep <const> = 1.0 / (sctCount - 1.0)
    for i = 0, sctCount - 1, 1 do
        local t <const> = i * toStep
        local u <const> = 1.0 - t

        local oculRad <const> = u * oculRad0 + t * oculRad1

        local theta <const> = u * a + t * c
        local cosTheta <const> = cos(theta)
        local sinTheta <const> = sin(theta)

        local i2 <const> = i + i
        vs[i2 + 1] = Vec2.new(
            cosTheta * radius,
            sinTheta * radius)

        vs[i2 + 2] = Vec2.new(
            cosTheta * oculRad,
            sinTheta * oculRad)
    end

    if useQuads then
        for k = 0, sctCount - 2, 1 do
            local i <const> = k + k
            fs[1 + k] = { 1 + i, 3 + i, 4 + i, 2 + i }
        end
    else
        ---@type integer[]
        local f <const> = {}
        for i = 0, sctCount - 1, 1 do
            local j <const> = i + i
            f[1 + i] = 1 + j
            f[1 + sctCount + i] = 1 + (sctCount2 - 1) - j
        end
        fs[#fs + 1] = f
    end

    return Mesh2.new(fs, vs, "Arc")
end

---Creates a grid of rectangles.
---@param cols integer columns
---@param rows integer rows
---@return Mesh2
function Mesh2.gridCartesian(cols, rows)
    -- Validate inputs.
    local cVrf = cols or 2
    if cVrf < 2 then cVrf = 2 end
    local rVrf = rows or cVrf
    if rVrf < 2 then rVrf = 2 end

    -- Fence posting problem:
    -- There is one more edge than cell.
    local rVal1 <const> = rVrf + 1
    local cVal1 <const> = cVrf + 1

    ---@type Vec2[]
    local vs <const> = {}
    local iToStep <const> = 1.0 / rVrf
    local jToStep <const> = 1.0 / cVrf
    local fLen1 <const> = rVal1 * cVal1

    -- Set vertex coordinates.
    local h = 0
    while h < fLen1 do
        local i <const> = h // cVal1
        local j <const> = h % cVal1
        h = h + 1
        vs[h] = Vec2.new(
            j * jToStep - 0.5,
            i * iToStep - 0.5)
    end

    ---@type integer[][]
    local fs <const> = {}
    local fLen <const> = rVrf * cVrf

    -- Set face indices.
    local k = 0
    while k < fLen do
        local i <const> = k // cVrf
        local j <const> = k % cVrf

        local cOff0 <const> = 1 + i * cVal1

        local c00 <const> = cOff0 + j
        local c10 <const> = c00 + 1
        local c01 <const> = cOff0 + cVal1 + j
        local c11 <const> = c01 + 1

        k = k + 1
        fs[k] = { c00, c10, c11, c01 }
    end

    return Mesh2.new(fs, vs, "Grid.Cartesian")
end

---Creates a grid of rhombi.
---@param cells integer cell count
---@return Mesh2
function Mesh2.gridDimetric(cells)
    local mesh <const> = Mesh2.gridCartesian(cells, cells)

    local vs <const> = mesh.vs
    local vsLen <const> = #vs
    local i = 0
    while i < vsLen do
        i = i + 1
        local vSrc <const> = vs[i]
        vs[i] = Vec2.new(
            0.5 * vSrc.x - 0.5 * vSrc.y,
            0.25 * vSrc.x + 0.25 * vSrc.y)
    end

    mesh.name = "Grid Dimetric"
    return mesh
end

---Creates a grid of hexagons in rings around a central cell.
---@param rings integer number of rings
---@return Mesh2
function Mesh2.gridHex(rings)
    local vRings = 1
    if rings > 1 then vRings = rings end
    local vrad <const> = 0.5
    local extent <const> = vrad * 1.7320508075689
    local halfExt <const> = extent * 0.5
    local rad15 <const> = vrad * 1.5
    local radrt32 <const> = vrad * 0.86602540378444
    local halfRad <const> = vrad * 0.5

    local iMax <const> = vRings - 1
    local iMin <const> = -iMax

    ---@type Vec2[]
    local vs <const> = {}
    ---@type integer[][]
    local fs <const> = {}

    local fIdx = 0
    local vIdx = -5
    local i = iMin - 1
    while i < iMax do
        i = i + 1
        local jMin = iMin
        local jMax = iMax

        if i < 0 then jMin = jMin - i end
        if i > 0 then jMax = jMax - i end

        local iExt <const> = i * extent

        local j = jMin - 1
        while j < jMax do
            j = j + 1
            local x <const> = iExt + j * halfExt
            local y <const> = j * rad15

            local left <const> = x - radrt32
            local right <const> = x + radrt32
            local top <const> = y + halfRad
            local bottom <const> = y - halfRad

            vIdx = vIdx + 6
            vs[vIdx] = Vec2.new(x, y + vrad)
            vs[vIdx + 1] = Vec2.new(left, top)
            vs[vIdx + 2] = Vec2.new(left, bottom)
            vs[vIdx + 3] = Vec2.new(x, y - vrad)
            vs[vIdx + 4] = Vec2.new(right, bottom)
            vs[vIdx + 5] = Vec2.new(right, top)

            fIdx = fIdx + 1
            fs[fIdx] = {
                vIdx, vIdx + 1, vIdx + 2,
                vIdx + 3, vIdx + 4, vIdx + 5
            }
        end
    end

    return Mesh2.new(fs, vs, "Grid Hexagon")
end

---Creates a regular convex polygon
---@param sectors integer sides
---@return Mesh2
function Mesh2.polygon(sectors)
    local vSect = 3
    if sectors > 3 then vSect = sectors end
    local vRad <const> = 0.5
    local toTheta <const> = 6.2831853071796 / vSect

    ---@type Vec2[]
    local vs <const> = {}
    ---@type integer[]
    local f <const> = {}

    local cos <const> = math.cos
    local sin <const> = math.sin

    local i = 0
    while i < vSect do
        local theta <const> = i * toTheta
        i = i + 1
        vs[i] = Vec2.new(
            vRad * cos(theta),
            vRad * sin(theta))
        f[i] = i
    end
    local fs = { f }

    local name <const> = string.format("Polygon %d", vSect)
    return Mesh2.new(fs, vs, name)
end

---Creates a regular polygon where a count of vertices are picked to be inset
---after a count are skipped. The inset is expected to be a factor in
---[0.0, 1.0] that is multiplied by the polygon radius. The default is to pick
---1, skip 1, and inset by 0.5.
---@param sectors integer sides
---@param skip integer? vertices to skip
---@param pick integer? vertices to inset
---@param inset number? percent inset
---@return Mesh2
function Mesh2.star(sectors, skip, pick, inset)
    -- Early return for invalid skip or pick.
    local vSkip = 1
    local vPick = 1
    if skip then vSkip = skip end
    if pick then vPick = pick end
    if vSkip < 1 or vPick < 1 then
        return Mesh2.polygon(sectors)
    end

    -- Validate other arguments.
    local vRad <const> = 0.5
    local vIns = 0.25
    local vSect = 3
    if inset then
        vIns = vRad - vRad * math.min(math.max(
            inset, 0.000002), 0.999998)
    end
    if sectors > 3 then vSect = sectors end

    local all <const> = vPick + vSkip
    local seg <const> = all * vSect
    local toTheta <const> = 6.2831853071796 / seg

    ---@type Vec2[]
    local vs <const> = {}
    ---@type integer[]
    local f <const> = {}

    local cos <const> = math.cos
    local sin <const> = math.sin

    local i = 0
    while i < seg do
        -- TODO: Angle offset so that the middle
        -- of an edge lines up with the x axis.
        local theta <const> = i * toTheta
        local r = vIns
        if (i % all) < vPick then
            r = vRad
        end
        i = i + 1
        vs[i] = Vec2.new(
            r * cos(theta),
            r * sin(theta))
        f[i] = i
    end
    local fs <const> = { f }

    return Mesh2.new(fs, vs, "Star")
end

---Returns a JSON string of a mesh.
---@param a Mesh2 mesh
---@return string
function Mesh2.toJson(a)
    local strfmt <const> = string.format
    local tconcat <const> = table.concat

    local fs <const> = a.fs
    local fsLen <const> = #fs
    ---@type string[]
    local fsStrArr <const> = {}

    local i = 0
    while i < fsLen do
        i = i + 1
        local f <const> = fs[i]
        local fLen <const> = #f
        ---@type integer[]
        local fStrArr <const> = {}

        local j = 0
        while j < fLen do
            j = j + 1
            fStrArr[j] = f[j] - 1
        end
        fsStrArr[i] = strfmt("[%s]", tconcat(fStrArr, ","))
    end

    local vs <const> = a.vs
    local vsLen <const> = #vs
    ---@type string[]
    local vsStrArr <const> = {}

    local k = 0
    while k < vsLen do
        k = k + 1
        vsStrArr[k] = Vec2.toJson(vs[k])
    end

    return strfmt(
        "{\"name\":\"%s\",\"fs\":[%s],\"vs\":[%s]}",
        a.name,
        tconcat(fsStrArr, ","),
        tconcat(vsStrArr, ","))
end

---Restructures the mesh so that each face index refers to unique data.
---@param source Mesh2 source mesh
---@param target Mesh2 target mesh
---@return Mesh2
function Mesh2.uniformData(source, target)
    local trg <const> = target or source
    ---@type Vec2[]
    local vsTrg <const> = {}
    ---@type integer[][]
    local fsTrg <const> = {}

    local vsSrc <const> = source.vs
    local fsSrc <const> = source.fs
    local fsSrcLen <const> = #fsSrc

    local i = 0
    local k = 0
    while i < fsSrcLen do
        i = i + 1
        local fSrc <const> = fsSrc[i]
        local fSrcLen <const> = #fSrc
        ---@type integer[]
        local fTrg <const> = {}

        local j = 0
        while j < fSrcLen do
            j = j + 1
            k = k + 1
            local vertSrc <const> = fSrc[j]
            local vSrc <const> = vsSrc[vertSrc]
            local vTrg <const> = Vec2.new(vSrc.x, vSrc.y)
            vsTrg[k] = vTrg
            fTrg[j] = k
        end

        fsTrg[i] = fTrg
    end

    trg.fs = fsTrg
    trg.vs = vsTrg
    return trg
end

return Mesh2