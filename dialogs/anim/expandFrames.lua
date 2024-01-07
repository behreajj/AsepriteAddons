local targets <const> = { "ALL", "AFTER", "BEFORE" }
local fillOpts <const> = { "CROSS_FADE", "EMPTY" }

local defaults <const> = {
    target = "ALL",
    fillOpt = "EMPTY",
    inbetweens = 1
}

local dlg <const> = Dialog { title = "Expand Frames" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:slider {
    id = "inbetweens",
    label = "Expand:",
    min = 1,
    max = 64,
    value = defaults.inbetweens
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    onclick = function()
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local spriteSpec <const> = activeSprite.spec
        local colorMode <const> = spriteSpec.colorMode
        local colorSpace <const> = spriteSpec.colorSpace
        local alphaIndex <const> = spriteSpec.transparentColor

        -- TODO: Return early if cross fade is selected?

        -- Unpack arguments.
        local args <const> = dlg.data
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local inbetweens <const> = args.inbetweens
            or defaults.inbetweens --[[@as integer]]

        -- TODO: How to handle linked cels?

        local frObjsBefore <const> = activeSprite.frames
        local lenFrObjsBefore <const> = #frObjsBefore

        local oldActFrObj <const> = app.frame --[[@as Frame]]
        local oldActFrIdx = 1
        if oldActFrObj then
            oldActFrIdx = oldActFrObj.frameNumber
        end

        ---@type integer[]
        local frIdcs = {}

        if target == "BEFORE" then
            if not oldActFrObj then
                app.alert {
                    title = "Error",
                    text = "There is no active frame."
                }
                return
            end

            if oldActFrObj.frameNumber <= 1 then
                app.alert {
                    title = "Error",
                    text = "There is no previous frame."
                }
                return
            end

            frIdcs[1] = oldActFrIdx - 1
            frIdcs[2] = oldActFrIdx
        elseif target == "AFTER" then
            if not oldActFrObj then
                app.alert {
                    title = "Error",
                    text = "There is no active frame."
                }
                return
            end

            if oldActFrObj.frameNumber >= lenFrObjsBefore then
                app.alert {
                    title = "Error",
                    text = "There is no subseqent frame."
                }
                return
            end

            frIdcs[1] = oldActFrIdx
            frIdcs[2] = oldActFrIdx + 1
        else
            frIdcs = AseUtilities.frameObjsToIdcs(frObjsBefore)
        end

        ---@type table<integer, integer>
        local frIdxDict <const> = {}
        local jToFac <const> = 1.0 / (inbetweens + 1)

        app.transaction("Create New Frames", function()
            -- local lenChosenFrames <const> = #frObjs
            local lenChosenFrames <const> = #frIdcs
            local i = lenChosenFrames + 1
            while i > 2 do
                i = i - 1

                local frIdxNext <const> = frIdcs[i]
                local frIdxPrev <const> = frIdcs[i - 1]

                local frObjNext <const> = frObjsBefore[frIdxNext]
                local frObjPrev <const> = frObjsBefore[frIdxPrev]

                frIdxDict[frIdxPrev] = frIdxPrev
                frIdxDict[frIdxNext] = frIdxNext + inbetweens * (i - 1)

                local durNext <const> = frObjNext.duration
                local durPrev <const> = frObjPrev.duration

                local j = inbetweens + 1
                while j > 1 do
                    j = j - 1
                    local jFac <const> = j * jToFac
                    local dur <const> = (1.0 - jFac) * durPrev + jFac * durNext
                    -- print(string.format("%.3f: %.3f", jFac, dur))
                    local btwn <const> = activeSprite:newEmptyFrame(frIdxNext)
                    btwn.duration = dur
                end
            end
        end)

        if oldActFrObj then
            app.frame = activeSprite.frames[frIdxDict[oldActFrIdx]]
        else
            app.frame = activeSprite.frames[1]
        end

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