dofile("../../support/aseutilities.lua")
local appTool <const> = app.tool --[[@as Tool]]
if appTool then
    if appTool.id == "slice"
        or appTool.id == "text" then
        app.tool = "hand"
    end
end
AseUtilities.preserveForeBack()
app.command.GotoPreviousTab()