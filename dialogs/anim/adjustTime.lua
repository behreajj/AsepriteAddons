dofile("../../support/aseutilities.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE" }

local defaults <const> = {
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
        local i = 0
        while i < lenFrIdcs do
            i = i + 1
            local frObj <const> = frObjs[frIdcs[i]]
            local durms = floor(frObj.duration * 1000.0 + 0.5)
            frObj.duration = min(max((durms + opNum) * 0.001, lb), ub)
        end
    elseif opFlag == "SUBTRACT" then
        local i = 0
        while i < lenFrIdcs do
            i = i + 1
            local frObj <const> = frObjs[frIdcs[i]]
            local durms = floor(frObj.duration * 1000.0 + 0.5)
            frObj.duration = min(max((durms - opNum) * 0.001, lb), ub)
        end
    elseif opFlag == "MULTIPLY" then
        local opNumAbs = abs(opNum)
        local i = 0
        while i < lenFrIdcs do
            i = i + 1
            local frObj <const> = frObjs[frIdcs[i]]
            frObj.duration = min(max(frObj.duration * opNumAbs, lb), ub)
        end
    elseif opFlag == "DIVIDE" then
        local opNumAbs = abs(opNum)
        local i = 0
        while i < lenFrIdcs do
            i = i + 1
            local frObj <const> = frObjs[frIdcs[i]]
            frObj.duration = min(max(frObj.duration / opNumAbs, lb), ub)
        end
    else
        -- Default to set.
        local opNumVrf <const> = min(max(abs(opNum) * 0.001, lb), ub)
        local i = 0
        while i < lenFrIdcs do
            i = i + 1
            frObjs[frIdcs[i]].duration = opNumVrf
        end
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
    focus = true
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

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }