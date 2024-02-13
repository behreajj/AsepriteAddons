dofile("../../support/aseutilities.lua")
dofile("../../support/clrgradient.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE" }

local defaults <const> = {
    -- TODO: Support "TAG"? What if tags partial overlap, or one is contained
    -- by the other?
    target = "ALL",
    opNum = 0
}

---@param sprite Sprite|nil
---@param target string
---@param opFlag string
---@param opNum number
local function adjustDuration(sprite, target, opFlag, opNum)
    if not sprite then
        app.alert {
            title = "Error",
            text = "There is no active sprite."
        }
        return
    end

    if opNum == 0.0 then return end

    local frIdcs <const> = Utilities.flatArr2(
        AseUtilities.getFrames(sprite, target))
    local lenFrIdcs <const> = #frIdcs
    local frObjs <const> = sprite.frames

    local lb <const> = 0.001
    local ub <const> = 65.535

    local abs <const> = math.abs
    local floor <const> = math.floor
    local max <const> = math.max
    local min <const> = math.min

    if opFlag == "ADD" then
        app.transaction("Add Duration", function()
            local i = 0
            while i < lenFrIdcs do
                i = i + 1
                local frObj <const> = frObjs[frIdcs[i]]
                local durms <const> = floor(frObj.duration * 1000.0 + 0.5)
                frObj.duration = min(max((durms + opNum) * 0.001, lb), ub)
            end
        end)
    elseif opFlag == "SUBTRACT" then
        app.transaction("Subtract Duration", function()
            local i = 0
            while i < lenFrIdcs do
                i = i + 1
                local frObj <const> = frObjs[frIdcs[i]]
                local durms <const> = floor(frObj.duration * 1000.0 + 0.5)
                frObj.duration = min(max((durms - opNum) * 0.001, lb), ub)
            end
        end)
    elseif opFlag == "MULTIPLY" then
        local opNumAbs <const> = abs(opNum)
        app.transaction("Multiply Duration", function()
            local i = 0
            while i < lenFrIdcs do
                i = i + 1
                local frObj <const> = frObjs[frIdcs[i]]
                frObj.duration = min(max(frObj.duration * opNumAbs, lb), ub)
            end
        end)
    elseif opFlag == "DIVIDE" then
        local opNumAbs <const> = abs(opNum)
        app.transaction("Divide Duration", function()
            local i = 0
            while i < lenFrIdcs do
                i = i + 1
                local frObj <const> = frObjs[frIdcs[i]]
                frObj.duration = min(max(frObj.duration / opNumAbs, lb), ub)
            end
        end)
    else
        -- Default to set.
        local opNumVrf <const> = min(max(abs(opNum) * 0.001, lb), ub)
        app.transaction("Set Duration", function()
            local i = 0
            while i < lenFrIdcs do
                i = i + 1
                frObjs[frIdcs[i]].duration = opNumVrf
            end
        end)
    end
end

local dlg <const> = Dialog { title = "Adjust Time" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets,
    focus = false
}

dlg:newrow { always = false }

dlg:number {
    id = "opNum",
    label = "Number:",
    text = string.format("%d", defaults.opNum),
    decimals = 0,
    focus = false
}

dlg:newrow { always = false }

dlg:button {
    id = "addButton",
    text = "&ADD",
    focus = false,
    onclick = function()
        local args <const> = dlg.data
        local target <const> = args.target --[[@as string]]
        local opNum <const> = args.opNum --[[@as number]]
        adjustDuration(app.site.sprite, target, "ADD", opNum)
    end
}

dlg:button {
    id = "subButton",
    text = "&SUBTRACT",
    focus = false,
    onclick = function()
        local args <const> = dlg.data
        local target <const> = args.target --[[@as string]]
        local opNum <const> = args.opNum --[[@as number]]
        adjustDuration(app.site.sprite, target, "SUBTRACT", opNum)
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "mulButton",
    text = "&MULTIPLY",
    focus = false,
    onclick = function()
        local args <const> = dlg.data
        local target <const> = args.target --[[@as string]]
        local opNum <const> = args.opNum --[[@as number]]
        adjustDuration(app.site.sprite, target, "MULTIPLY", opNum)
    end
}

dlg:button {
    id = "divButton",
    text = "&DIVIDE",
    focus = false,
    onclick = function()
        local args <const> = dlg.data
        local target <const> = args.target --[[@as string]]
        local opNum <const> = args.opNum --[[@as number]]
        adjustDuration(app.site.sprite, target, "DIVIDE", opNum)
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "setButton",
    text = "S&ET",
    focus = false,
    onclick = function()
        local args <const> = dlg.data
        local target <const> = args.target --[[@as string]]
        local opNum <const> = args.opNum --[[@as number]]
        adjustDuration(app.site.sprite, target, "SET", opNum)
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "heatMap",
    text = "&HEAT MAP",
    focus = false,
    onclick = function()
        local sprite <const> = app.site.sprite
        if not sprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local frObjs <const> = sprite.frames
        local lenFrames <const> = #frObjs

        ---@type number[]
        local durations <const> = {}
        local durMin = 2147483647
        local durMax = -2147483648

        local h = 0
        while h < lenFrames do
            h = h + 1
            local frObj <const> = frObjs[h]
            local dur <const> = frObj.duration
            durations[h] = dur
            if dur < durMin then durMin = dur end
            if dur > durMax then durMax = dur end
        end

        local durRange = durMax - durMin
        if durRange < 0.000001 then
            app.alert {
                title = "Error",
                text = "No difference in frame durations."
            }
            return
        end

        -- This approach wouldn't work for indexed and gray color.
        -- local mapLyr = nil
        -- app.transaction("New Layer", function()
        --     mapLyr = sprite:newLayer()
        --     mapLyr.name = "Heat.Map"
        --     mapLyr.blendMode = BlendMode.NORMAL
        --     mapLyr.opacity = 128
        -- end)

        -- local spriteSpec <const> = sprite.spec
        local durToFac <const> = 1.0 / durRange

        local easing <const> = Clr.mixlRgb
        local cgeval <const> = ClrGradient.eval
        -- local toHex <const> = Clr.toHex
        local clrToAseColor <const> = AseUtilities.clrToAseColor

        local leaves <const> = AseUtilities.getLayerHierarchy(
            sprite, true, true, true, true)
        local lenLeaves <const> = #leaves

        local t <const> = 2.0 / 3.0
        local cg <const> = ClrGradient.new({
            ClrKey.new(0.0, Clr.new(0.266667, 0.003922, 0.329412, t)),
            ClrKey.new(0.06666667, Clr.new(0.282353, 0.100131, 0.420654, t)),
            ClrKey.new(0.13333333, Clr.new(0.276078, 0.184575, 0.487582, t)),
            ClrKey.new(0.2, Clr.new(0.254902, 0.265882, 0.527843, t)),
            ClrKey.new(0.26666668, Clr.new(0.221961, 0.340654, 0.549281, t)),
            ClrKey.new(0.33333334, Clr.new(0.192157, 0.405229, 0.554248, t)),
            ClrKey.new(0.4, Clr.new(0.164706, 0.469804, 0.556863, t)),
            ClrKey.new(0.46666667, Clr.new(0.139869, 0.534379, 0.553464, t)),
            ClrKey.new(0.5333333, Clr.new(0.122092, 0.595033, 0.543007, t)),
            ClrKey.new(0.6, Clr.new(0.139608, 0.658039, 0.516863, t)),
            ClrKey.new(0.6666667, Clr.new(0.210458, 0.717647, 0.471895, t)),
            ClrKey.new(0.73333335, Clr.new(0.326797, 0.773595, 0.407582, t)),
            ClrKey.new(0.8, Clr.new(0.477647, 0.821961, 0.316863, t)),
            ClrKey.new(0.8666667, Clr.new(0.648366, 0.858039, 0.208889, t)),
            ClrKey.new(0.93333334, Clr.new(0.825098, 0.884967, 0.114771, t)),
            ClrKey.new(1.0, Clr.new(0.992157, 0.905882, 0.145098, t))
        })

        app.transaction("Time Heat Map", function()
            local i = 0
            while i < lenFrames do
                i = i + 1
                local dur <const> = durations[i]
                local fac <const> = (dur - durMin) * durToFac
                local clr <const> = cgeval(cg, fac, easing)
                -- local hex <const> = toHex(clr)
                -- local img <const> = Image(spriteSpec)
                -- img:clear(hex)
                -- sprite:newCel(mapLyr, i, img, Point(0, 0))

                local ase <const> = clrToAseColor(clr)
                local j = 0
                while j < lenLeaves do
                    j = j + 1
                    local leaf <const> = leaves[j]
                    local cel <const> = leaf:cel(i)
                    if cel then
                        cel.color = ase
                    end
                end
            end
        end)

        app.refresh()
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show {
    autoscrollbars = true,
    wait = false
}