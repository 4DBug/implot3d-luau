-- ImPlot3D demo (Luau port of implot3d_demo.cpp). Optional: ImPlot3D.lua never calls into this file.
-- Usage: require(path.to.ImPlot3DDemo)(G, ImPlot3D) -- defines ImPlot3D.ShowDemoWindow(p_open) -> new p_open,
-- ImPlot3D.ShowAllDemos(), ImPlot3D.ShowStyleEditor(ref), ImPlot3D.ShowAboutWindow(p_open) -> new p_open
-- [Port] Lua has no function-level 'static': they are fields of the file-level table S (S.FunctionName.x).
-- [Port] Demo* functions live in the table D (keeps the file chunk under the 200-locals limit).
-- [Port] Specs are plain tables of ImPlot3DSpec fields; arrays are 1-based; Stride/Offset are in elements.
return function(G, ImPlot3D)
    local ImGui, ImVec2, ImVec4 = G.ImGui, G.ImVec2, G.ImVec4
    local IM_COL32 = G.IM_COL32
    local IM_PI = math.pi
    local P = ImPlot3D.ImPlot3DPoint
    local ImAxis3D = ImPlot3D.ImAxis3D
    local Flags = ImPlot3D.ImPlot3DFlags
    local AxisFlags = ImPlot3D.ImPlot3DAxisFlags
    local Marker = ImPlot3D.ImPlot3DMarker
    local Cond = ImPlot3D.ImPlot3DCond
    local Colormap = ImPlot3D.ImPlot3DColormap
    local LineFlags = ImPlot3D.ImPlot3DLineFlags
    local TriFlags = ImPlot3D.ImPlot3DTriangleFlags
    local QuadFlags = ImPlot3D.ImPlot3DQuadFlags
    local SurfFlags = ImPlot3D.ImPlot3DSurfaceFlags
    local MeshFlags = ImPlot3D.ImPlot3DMeshFlags
    local Meshes = ImPlot3D.Meshes
    local band, bor = bit32.band, bit32.bor
    local _

    local S = {}
    local D = {}

    -- [Port] IMGUI_DEMO_MARKER: forwarded to ImGui.DemoMarker when available (no __LINE__ in Lua: line is 0)
    local function IMGUI_DEMO_MARKER(section)
        if ImGui.DemoMarker then ImGui.DemoMarker("implot3d_demo.cpp", 0, section) end
    end

    -- [Port] CHECKBOX_FLAG(flags, flag) macro: label is the upstream flag name; returns the new flags
    local function CHECKBOX_FLAG(flags, name, flag)
        local _, v = ImGui.CheckboxFlags(name, flags, flag)
        return v
    end

    local function HelpMarker(desc)
        ImGui.TextDisabled("(?)")
        if ImGui.BeginItemTooltip() then
            ImGui.PushTextWrapPos(ImGui.GetFontSize() * 35.0)
            ImGui.TextUnformatted(desc)
            ImGui.PopTextWrapPos()
            ImGui.EndTooltip()
        end
    end

    -- [Port] rand()/RAND_MAX -> deterministic LCG so srand(0) sections repeat every frame like upstream
    local seed = 0
    local function srand(s) seed = s end
    local function rand01()
        seed = (seed * 1103515245 + 12345) % 2147483648
        return seed / 2147483647
    end

    -- [Port] &arr[base] pointer arithmetic -> read-only proxy (0-based base)
    local function Ptr(arr, base)
        return setmetatable({}, { __index = function(_, i) return arr[i + base] end })
    end

    -- Utility structure for realtime plot
    local function ScrollingBuffer(max_size) return { MaxSize = max_size or 2000, Offset = 0, Data = {} } end
    local function AddPoint(b, x)
        if #b.Data < b.MaxSize then
            table.insert(b.Data, x)
        else
            b.Data[b.Offset + 1] = x
            b.Offset = (b.Offset + 1) % b.MaxSize
        end
    end

    -- Custom axis formatter that adds metric prefixes (G, M, k, m, u, n)
    -- [Port] ImPlot3DFormatter is function(value, data) -> string
    local metric_v = { 1000000000, 1000000, 1000, 1, 0.001, 0.000001, 0.000000001 }
    local metric_p = { "G", "M", "k", "", "m", "u", "n" }
    local function MetricFormatter(value, unit)
        if value == 0 then return "0 " .. unit end
        for i = 1, 7 do
            if math.abs(value) >= metric_v[i] then return string.format("%g %s%s", value / metric_v[i], metric_p[i], unit) end
        end
        return string.format("%g %s%s", value / metric_v[7], metric_p[7], unit)
    end

    local function HSV_U32(h, s, v) return G.ImColor.HSV(h, s, v):U32() end

    ---------------------------------------------------------------------------
    -- [SECTION] Plots
    ---------------------------------------------------------------------------

    S.DemoLinePlots = { xs1 = {}, ys1 = {}, zs1 = {}, xs2 = {}, ys2 = {}, zs2 = {} }
    function D.DemoLinePlots()
        IMGUI_DEMO_MARKER("Plots/Line Plots")
        local s = S.DemoLinePlots
        local t = ImGui.GetTime()
        for i = 1, 1001 do
            local x = (i - 1) * 0.001
            s.xs1[i], s.ys1[i], s.zs1[i] = x, 0.5 + 0.5 * math.cos(50 * (x + t / 10)), 0.5 + 0.5 * math.sin(50 * (x + t / 10))
        end
        for i = 1, 20 do
            local x = (i - 1) / 19.0
            s.xs2[i], s.ys2[i], s.zs2[i] = x, x * x, x * x * x
        end
        if ImPlot3D.BeginPlot("Line Plots") then
            ImPlot3D.SetupAxes("x", "y", "z")
            ImPlot3D.PlotLine("f(x)", s.xs1, s.ys1, s.zs1, 1001)
            ImPlot3D.PlotLine("g(x)", s.xs2, s.ys2, s.zs2, 20, { Marker = Marker.Circle, Flags = LineFlags.Segments })
            ImPlot3D.EndPlot()
        end
    end

    S.DemoScatterPlots = { xs1 = {}, ys1 = {}, zs1 = {}, xs2 = {}, ys2 = {}, zs2 = {} }
    function D.DemoScatterPlots()
        IMGUI_DEMO_MARKER("Plots/Scatter Plots")
        local s = S.DemoScatterPlots
        srand(0)
        for i = 1, 100 do
            local x = (i - 1) * 0.01
            s.xs1[i], s.ys1[i], s.zs1[i] = x, x + 0.1 * rand01(), x + 0.1 * rand01()
        end
        for i = 1, 50 do
            s.xs2[i], s.ys2[i], s.zs2[i] = 0.25 + 0.2 * rand01(), 0.50 + 0.2 * rand01(), 0.75 + 0.2 * rand01()
        end
        if ImPlot3D.BeginPlot("Scatter Plots") then
            ImPlot3D.PlotScatter("Data 1", s.xs1, s.ys1, s.zs1, 100)
            local c = ImPlot3D.GetColormapColor(1)
            ImPlot3D.PlotScatter("Data 2", s.xs2, s.ys2, s.zs2, 50,
                { Marker = Marker.Square, MarkerSize = 6, MarkerLineColor = c, MarkerFillColor = c, FillAlpha = 0.25 })
            ImPlot3D.EndPlot()
        end
    end

    -- Pyramid: 6 triangles (4 sides + 2 base), 18 vertices
    local function Pyramid()
        local cx, cy = { -0.5, 0.5, 0.5, -0.5 }, { -0.5, -0.5, 0.5, 0.5 }
        local xs, ys, zs = {}, {}, {}
        local function V(x, y, z) table.insert(xs, x); table.insert(ys, y); table.insert(zs, z) end
        local function C(i) V(cx[i + 1], cy[i + 1], 0) end
        for k = 0, 3 do V(0, 0, 1); C(k); C((k + 1) % 4) end -- sides: apex, corner k, corner k+1
        C(0); C(1); C(2) -- base
        C(0); C(2); C(3)
        return xs, ys, zs
    end

    S.DemoTrianglePlots = { flags = TriFlags.None }
    function D.DemoTrianglePlots()
        IMGUI_DEMO_MARKER("Plots/Triangle Plots")
        local s = S.DemoTrianglePlots
        if s.xs == nil then s.xs, s.ys, s.zs = Pyramid() end
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlot3DTriangleFlags_NoLines", TriFlags.NoLines)
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlot3DTriangleFlags_NoFill", TriFlags.NoFill)
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlot3DTriangleFlags_NoMarkers", TriFlags.NoMarkers)
        if ImPlot3D.BeginPlot("Triangle Plots") then
            ImPlot3D.SetupAxesLimits(-1, 1, -1, 1, -0.5, 1.5)
            ImPlot3D.PlotTriangle("Pyramid", s.xs, s.ys, s.zs, 6 * 3, {
                FillColor = ImPlot3D.GetColormapColor(0), LineColor = ImPlot3D.GetColormapColor(1),
                Marker = Marker.Square, MarkerSize = 3, Flags = s.flags,
            })
            ImPlot3D.EndPlot()
        end
    end

    -- Cube faces as quads: +x, -x, +y, -y, +z, -z (4 vertices each)
    -- stylua: ignore
    local cube_quads = {
        xs = { 1, 1, 1, 1,  -1, -1, -1, -1,  -1, 1, 1, -1,  -1, 1, 1, -1,  -1, 1, 1, -1,  -1, 1, 1, -1 },
        ys = { -1, 1, 1, -1,  -1, 1, 1, -1,  1, 1, 1, 1,  -1, -1, -1, -1,  -1, -1, 1, 1,  -1, -1, 1, 1 },
        zs = { -1, -1, 1, 1,  -1, -1, 1, 1,  -1, -1, 1, 1,  -1, -1, 1, 1,  1, 1, 1, 1,  -1, -1, -1, -1 },
    }
    S.DemoQuadPlots = { flags = QuadFlags.None, colorX = ImVec4(0.8, 0.2, 0.2, 0.8), colorY = ImVec4(0.2, 0.8, 0.2, 0.8),
        colorZ = ImVec4(0.2, 0.2, 0.8, 0.8) }
    function D.DemoQuadPlots()
        IMGUI_DEMO_MARKER("Plots/Quad Plots")
        local s, q = S.DemoQuadPlots, cube_quads
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlot3DQuadFlags_NoLines", QuadFlags.NoLines)
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlot3DQuadFlags_NoFill", QuadFlags.NoFill)
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlot3DQuadFlags_NoMarkers", QuadFlags.NoMarkers)
        if ImPlot3D.BeginPlot("Quad Plots") then
            ImPlot3D.SetupAxesLimits(-1.5, 1.5, -1.5, 1.5, -1.5, 1.5)
            for k, e in { { "X", s.colorX }, { "Y", s.colorY }, { "Z", s.colorZ } } do
                local base = (k - 1) * 8 -- [Port] &xs[base]
                ImPlot3D.PlotQuad(e[1], Ptr(q.xs, base), Ptr(q.ys, base), Ptr(q.zs, base), 8,
                    { Marker = Marker.Square, MarkerSize = 3, Flags = s.flags, FillColor = e[2], LineColor = e[2] })
            end
            ImPlot3D.EndPlot()
        end
    end

    local surface_colormaps = { "Viridis", "Plasma", "Hot", "Cool", "Pink", "Jet", "Twilight", "RdBu", "BrBG", "PiYG", "Spectral", "Greys" }
    S.DemoSurfacePlots = { xs = {}, ys = {}, zs = {}, custom_colors = {}, t = 0, selected_fill = 1, solid_color = ImVec4(0.8, 0.8, 0.2, 0.6),
        sel_colormap = 5, custom_range = false, range_min = -1.0, range_max = 1.0, flags = SurfFlags.NoMarkers }
    function D.DemoSurfacePlots()
        IMGUI_DEMO_MARKER("Plots/Surface Plots")
        local s = S.DemoSurfacePlots
        local N = 20
        s.t += ImGui.GetIO().DeltaTime
        -- Define the range for X and Y
        local min_val, max_val = -1.0, 1.0
        local step = (max_val - min_val) / (N - 1)
        for i = 0, N - 1 do
            for j = 0, N - 1 do
                local idx = i * N + j + 1
                local x, y = min_val + j * step, min_val + i * step -- X constant along rows, Y along columns
                local z = math.sin(2 * s.t + math.sqrt(x * x + y * y)) -- z = sin(2t + sqrt(x^2 + y^2))
                s.xs[idx], s.ys[idx], s.zs[idx] = x, y, z
                -- Custom per-point color: R=x, G=y, B=z (each remapped from [-1,1] to [0,1])
                s.custom_colors[idx] = IM_COL32(math.floor((x + 1) * 0.5 * 255), math.floor((y + 1) * 0.5 * 255), math.floor((z + 1) * 0.5 * 255), 255)
            end
        end

        -- Choose fill color
        ImGui.Text("Fill color")
        ImGui.Indent()
        _, s.selected_fill = ImGui.RadioButton("Solid", s.selected_fill, 0)
        if s.selected_fill == 0 then
            ImGui.SameLine()
            ImGui.ColorEdit4("##SurfaceSolidColor", s.solid_color)
        end
        _, s.selected_fill = ImGui.RadioButton("Colormap", s.selected_fill, 1)
        if s.selected_fill == 1 then
            ImGui.SameLine()
            s.sel_colormap = ImGui.Combo("##SurfaceColormap", s.sel_colormap, surface_colormaps)
        end
        _, s.selected_fill = ImGui.RadioButton("Custom Per-Point", s.selected_fill, 2)
        if s.selected_fill == 2 then
            ImGui.SameLine(); ImGui.TextDisabled("R=x, G=y, B=z")
        end
        ImGui.Unindent()

        -- Choose range (only applies to Colormap mode)
        if s.selected_fill ~= 1 then ImGui.BeginDisabled() end
        _, s.custom_range = ImGui.Checkbox("Custom range", s.custom_range)
        ImGui.Indent()
        if not s.custom_range then ImGui.BeginDisabled() end
        s.range_min = ImGui.SliderFloat("Range min", s.range_min, -1.0, s.range_max - 0.01)
        s.range_max = ImGui.SliderFloat("Range max", s.range_max, s.range_min + 0.01, 1.0)
        if not s.custom_range then ImGui.EndDisabled() end
        ImGui.Unindent()
        if s.selected_fill ~= 1 then ImGui.EndDisabled() end

        -- Select flags
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlot3DSurfaceFlags_NoLines", SurfFlags.NoLines)
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlot3DSurfaceFlags_NoFill", SurfFlags.NoFill)
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlot3DSurfaceFlags_NoMarkers", SurfFlags.NoMarkers)

        if s.selected_fill == 1 then ImPlot3D.PushColormap(surface_colormaps[s.sel_colormap + 1]) end
        if ImPlot3D.BeginPlot("Surface Plots", ImVec2(-1, 0), Flags.NoClip) then
            ImPlot3D.SetupAxesLimits(-1, 1, -1, 1, -1.5, 1.5)
            local spec = { FillAlpha = 0.8, Flags = s.flags, Marker = Marker.Square, LineColor = ImPlot3D.GetColormapColor(1) }
            if s.selected_fill == 0 then
                spec.FillColor = s.solid_color
            elseif s.selected_fill == 2 then
                spec.FillColors = s.custom_colors
            end
            local lo, hi = 0.0, 0.0
            if s.custom_range then lo, hi = s.range_min, s.range_max end
            ImPlot3D.PlotSurface("Wave Surface", s.xs, s.ys, s.zs, N, N, lo, hi, spec)
            ImPlot3D.EndPlot()
        end
        if s.selected_fill == 1 then ImPlot3D.PopColormap() end
    end

    S.DemoMeshPlots = { mesh_id = 0, line_color = ImVec4(0.5, 0.5, 0.2, 0.6), fill_color = ImVec4(0.8, 0.8, 0.2, 0.6),
        marker_color = ImVec4(0.5, 0.5, 0.2, 0.6), flags = MeshFlags.NoMarkers }
    function D.DemoMeshPlots()
        IMGUI_DEMO_MARKER("Plots/Mesh Plots")
        local s = S.DemoMeshPlots
        s.mesh_id = ImGui.Combo("Mesh", s.mesh_id, "Duck\0Sphere\0Cube\0\0")
        ImGui.ColorEdit4("Line Color##Mesh", s.line_color)
        ImGui.ColorEdit4("Fill Color##Mesh", s.fill_color)
        ImGui.ColorEdit4("Marker Color##Mesh", s.marker_color)
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlot3DMeshFlags_NoLines", MeshFlags.NoLines)
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlot3DMeshFlags_NoFill", MeshFlags.NoFill)
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlot3DMeshFlags_NoMarkers", MeshFlags.NoMarkers)
        if ImPlot3D.BeginPlot("Mesh Plots") then
            ImPlot3D.SetupAxesLimits(-1, 1, -1, 1, -1, 1)
            local spec = { Flags = s.flags, FillColor = s.fill_color, LineColor = s.line_color, Marker = Marker.Square, MarkerSize = 3.0,
                MarkerLineColor = s.marker_color, MarkerFillColor = s.marker_color }
            -- [Port] ImPlot3D.Meshes keep upstream's 0-based indices
            local name = ({ [0] = "Duck", "Sphere", "Cube" })[s.mesh_id]
            local m = Meshes[name]
            ImPlot3D.PlotMesh(name, m.VtxXs, m.VtxYs, m.VtxZs, m.Idx, m.VtxCount, m.IdxCount, spec)
            ImPlot3D.EndPlot()
        end
    end

    -- @@TAIL@@
end
