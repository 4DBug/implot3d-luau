-- ImPlot3D for imgui-luau. Port of https://github.com/brenocq/implot3d (7913cf11684730119bd284fd8e7052d140e72f61).
-- Usage: local ImPlot3D = require(path.to.ImPlot3D)(require(path.to.ImGui))
return function(G)
    local ImGui, ImVec2, ImVec4 = G.ImGui, G.ImVec2, G.ImVec4
    local ImPlot3D = {}
    -- [Port] TODO: port from tools/upstream
    return ImPlot3D
end
