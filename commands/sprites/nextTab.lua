dofile("../../support/aseutilities.lua")
local appTool <const> = app.tool
if appTool then
    if appTool.id == "slice"
        or appTool.id == "text" then
        app.tool = "hand"
    end
end
AseUtilities.preserveForeBack()
app.command.GotoNextTab()