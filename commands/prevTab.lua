dofile("../support/aseutilities.lua")
local appTool <const> = app.tool
if appTool then
    local toolName <const> = appTool.id
    if toolName == "slice" then
        app.tool = "hand"
    end
end
AseUtilities.preserveForeBack()
app.command.GotoPreviousTab()