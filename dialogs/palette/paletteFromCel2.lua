dofile("../support/aseutilities.lua")

local areaTargets <const> = { "ACTIVE", "SELECTION" }
local palTargets <const> = { "ACTIVE", "SAVE" }

local defaults <const> = {
    areaTarget = "ACTIVE",
    palTarget = "ACTIVE"
}

local dlg <const> = Dialog { title = "Palette From Cel" }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = true,
    onclick = function()
        -- Begin measuring elapsed time.
        local args <const> = dlg.data
        local printElapsed <const> = args.printElapsed --[[@as boolean]]
        local startTime <const> = os.clock()

        -- Early returns.
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local srcFrame <const> = site.frame
        if not srcFrame then
            app.alert {
                title = "Error",
                text = "There is no active frame."
            }
            return
        end

        local srcImg = nil
        local xtl = 0
        local ytl = 0

        local spriteSpec <const> = activeSprite.spec
        local colorMode <const> = spriteSpec.colorMode
        local colorSpace <const> = spriteSpec.colorSpace
        local alphaIndex <const> = spriteSpec.transparentColor

        local areaTarget <const> = args.areaTarget
            or defaults.areaTarget --[[@as string]]
        if areaTarget == "SELECTION" then
            local mask <const>, isValid <const> = AseUtilities.getSelection(
                activeSprite)
            srcImg, xtl, ytl = AseUtilities.imageFromSel(
                mask, activeSprite, srcFrame.frameNumber)
        else
            -- Default to active layer.
            local srcLayer <const> = site.layer
            if not srcLayer then
                app.alert {
                    title = "Error",
                    text = "There is no active layer."
                }
                return
            end

            if srcLayer.isReference then
                app.alert {
                    title = "Error",
                    text = "Reference layers are not supported."
                }
                return
            end

            if srcLayer.isGroup then
                local includeLocked <const> = true
                local includeHidden <const> = true
                local includeTiles <const> = true
                local includeBkg <const> = true
                local boundingRect = Rectangle()
                srcImg, boundingRect = AseUtilities.flattenGroup(
                    srcLayer, srcFrame,
                    colorMode, colorSpace, alphaIndex,
                    includeLocked, includeHidden, includeTiles, includeBkg)
                xtl = boundingRect.x
                ytl = boundingRect.y
            else
                local srcCel <const> = srcLayer:cel(srcFrame)
                if not srcCel then
                    app.alert {
                        title = "Error",
                        text = "There is no active cel."
                    }
                    return
                end

                if srcLayer.isTilemap then
                    srcImg = AseUtilities.tileMapToImage(
                        srcCel.image, srcLayer.tileset, colorMode)
                else
                    srcImg = srcCel.image
                end

                local srcPos <const> = srcCel.position
                xtl = srcPos.x
                ytl = srcPos.y
            end
        end
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