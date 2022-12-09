-- Numpad keybind 4 doesn't work when a selection is active.
app.command.GotoPreviousFrame()

-- local activeSprite = app.activeSprite
-- if not activeSprite then return end
-- local activeFrame = app.activeFrame --[[@as Frame]]
-- if activeFrame then
--     local frameNo = activeFrame.frameNumber - 1
--     local lenFrames = #activeSprite.frames
--     if app.preferences.editor.play_once then
--         app.activeFrame = activeSprite.frames[1
--             + math.min(math.max(frameNo - 1, 0), lenFrames - 1)]
--     else
--         app.activeFrame = activeSprite.frames[1 + (frameNo - 1) % lenFrames]
--     end
-- else
--     app.activeFrame = activeSprite.frames[1]
-- end