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

    -- [Port] ImPlot3DPoint/ImVec2 statics -> 1-based arrays for SliderFloat3/SliderFloat2; ImVec4 tints edited in place
    S.DemoImagePlots = { tint1 = ImVec4(1, 1, 1, 1), tint2 = ImVec4(1, 1, 1, 1), center1 = { 0, 0, 1 }, axis_u1 = { 1, 0, 0 },
        axis_v1 = { 0, 1, 0 }, uv0_1 = { 0, 0 }, uv1_1 = { 1, 1 }, p0 = { -1, -1, 0 }, p1 = { 1, -1, 0 }, p2 = { 1, 1, 0 },
        p3 = { -1, 1, 0 }, uv0 = { 0, 0 }, uv1 = { 1, 0 }, uv2 = { 1, 1 }, uv3 = { 0, 1 } }
    function D.DemoImagePlots()
        IMGUI_DEMO_MARKER("Plots/Image Plots")
        local s = S.DemoImagePlots
        ImGui.BulletText("Below we are displaying the font texture, which is the only texture we have\naccess to in this demo.")
        ImGui.BulletText("Use the 'ImTextureID' type as storage to pass pointers or identifiers to your\nown texture data.")
        ImGui.BulletText("See ImGui Wiki page 'Image Loading and Displaying Examples'.")
        ImGui.Dummy(ImVec2(0, 10))
        if ImGui.TreeNodeEx("Image 1 Controls: Center + Axes") then
            ImGui.SliderFloat3("Center", s.center1, -2, 2, "%.1f")
            ImGui.SliderFloat3("Axis U", s.axis_u1, -2, 2, "%.1f")
            ImGui.SliderFloat3("Axis V", s.axis_v1, -2, 2, "%.1f")
            ImGui.SliderFloat2("UV0", s.uv0_1, 0, 1, "%.2f")
            ImGui.SliderFloat2("UV1", s.uv1_1, 0, 1, "%.2f")
            ImGui.ColorEdit4("Tint", s.tint1)
            ImGui.TreePop()
        end
        if ImGui.TreeNodeEx("Image 2 Controls: Full Quad") then
            ImGui.SliderFloat3("P0", s.p0, -2, 2, "%.1f")
            ImGui.SliderFloat3("P1", s.p1, -2, 2, "%.1f")
            ImGui.SliderFloat3("P2", s.p2, -2, 2, "%.1f")
            ImGui.SliderFloat3("P3", s.p3, -2, 2, "%.1f")
            ImGui.SliderFloat2("UV0", s.uv0, 0, 1, "%.2f")
            ImGui.SliderFloat2("UV1", s.uv1, 0, 1, "%.2f")
            ImGui.SliderFloat2("UV2", s.uv2, 0, 1, "%.2f")
            ImGui.SliderFloat2("UV3", s.uv3, 0, 1, "%.2f")
            ImGui.ColorEdit4("Tint##2", s.tint2)
            ImGui.TreePop()
        end
        if ImPlot3D.BeginPlot("Image Plot", ImVec2(-1, 0), Flags.NoClip) then
            -- We use the font atlas texture for this demo; your own loaded textures work just as well.
            local tex = ImGui.GetIO().Fonts.TexRef
            local function p3(a) return P(a[1], a[2], a[3]) end
            local function v2(a) return ImVec2(a[1], a[2]) end
            ImPlot3D.PlotImage("Image 1", tex, p3(s.center1), p3(s.axis_u1), p3(s.axis_v1), v2(s.uv0_1), v2(s.uv1_1), s.tint1)
            ImPlot3D.PlotImage("Image 2", tex, p3(s.p0), p3(s.p1), p3(s.p2), p3(s.p3), v2(s.uv0), v2(s.uv1), v2(s.uv2), v2(s.uv3), s.tint2)
            ImPlot3D.EndPlot()
        end
    end

    S.DemoRealtimePlots = { sdata1 = ScrollingBuffer(), sdata2 = ScrollingBuffer(), sdata3 = ScrollingBuffer(),
        flags = AxisFlags.NoTickLabels, t = 0.0, last_t = -1.0 }
    function D.DemoRealtimePlots()
        IMGUI_DEMO_MARKER("Plots/Realtime Plots")
        local s = S.DemoRealtimePlots
        ImGui.BulletText("Move your mouse to change the data!")
        if ImPlot3D.BeginPlot("Scrolling Plot") then
            -- Pool mouse data every 10 ms
            s.t += ImGui.GetIO().DeltaTime
            if s.t - s.last_t > 0.01 then
                s.last_t = s.t
                local mouse = ImGui.GetMousePos()
                if math.abs(mouse.x) < 1e4 and math.abs(mouse.y) < 1e4 then
                    local pos, size = ImPlot3D.GetFramePos(), ImPlot3D.GetFrameSize()
                    AddPoint(s.sdata1, s.t)
                    AddPoint(s.sdata2, mouse.x - (pos.x + size.x / 2))
                    AddPoint(s.sdata3, mouse.y - (pos.y + size.y / 2))
                end
            end
            ImPlot3D.SetupAxes("Time", "Mouse X", "Mouse Y", s.flags, s.flags, s.flags)
            ImPlot3D.SetupAxisLimits(ImAxis3D.X, s.t - 10.0, s.t, Cond.Always)
            ImPlot3D.SetupAxisLimits(ImAxis3D.Y, -400, 400, Cond.Once)
            ImPlot3D.SetupAxisLimits(ImAxis3D.Z, -400, 400, Cond.Once)
            ImPlot3D.PlotLine("Mouse", s.sdata1.Data, s.sdata2.Data, s.sdata3.Data, #s.sdata1.Data, { Offset = s.sdata1.Offset })
            ImPlot3D.EndPlot()
        end
    end

    local plot_flag_list = {
        { "NoTitle", "Hide plot title" }, { "NoLegend", "Hide plot legend" },
        { "NoMouseText", "Hide mouse position in plot coordinates" }, { "NoClip", "Disable 3D box clipping" },
        { "NoMenus", "The user will not be able to open context menus" },
        { "Equal", "X, Y, and Z axes will be constrained to have the same units/pixel" },
        { "NoRotate", "Lock rotation interaction" }, { "NoPan", "Lock panning/translation interaction" },
        { "NoZoom", "Lock zooming interaction" }, { "NoInputs", "Disable all user inputs" },
    }
    S.DemoPlotFlags = { flags = Flags.None, x = {}, y = {}, z = {} }
    for i = 0, 99 do
        local t = i * 0.1
        S.DemoPlotFlags.x[i + 1], S.DemoPlotFlags.y[i + 1], S.DemoPlotFlags.z[i + 1] = 3.0 * math.cos(t), 3.0 * math.sin(t), t - 5.0
    end
    local corner_xs, corner_ys, corner_zs = { -10, 10, -10, 10, -10, 10, -10, 10 }, { -10, -10, 10, 10, -10, -10, 10, 10 }, { -5, -5, -5, -5, 5, 5, 5, 5 }
    function D.DemoPlotFlags()
        IMGUI_DEMO_MARKER("Plots/Plot Flags")
        local s = S.DemoPlotFlags
        -- [Port] the repeated CHECKBOX_FLAG + "(?)" tooltip blocks folded into a loop
        for _, f in plot_flag_list do
            s.flags = CHECKBOX_FLAG(s.flags, "ImPlot3DFlags_" .. f[1], Flags[f[1]])
            ImGui.SameLine()
            ImGui.TextDisabled("(?)")
            if ImGui.IsItemHovered() then ImGui.SetTooltip(f[2]) end
        end
        if ImPlot3D.BeginPlot("Plot Flags Demo", ImVec2(-1, 0), s.flags) then
            ImPlot3D.SetupAxes("X-axis", "Y-axis", "Z-axis")
            ImPlot3D.SetupAxesLimits(-10, 10, -10, 10, -5, 5)
            ImPlot3D.PlotLine("Helix", s.x, s.y, s.z, 100)
            -- Add some scatter points to show equal scaling effect
            ImPlot3D.PlotScatter("Cube corners", corner_xs, corner_ys, corner_zs, 8)
            ImPlot3D.EndPlot()
        end
    end

    S.DemoOffsetAndStride = { offset = 0, data = {} }
    function D.DemoOffsetAndStride()
        IMGUI_DEMO_MARKER("Plots/Offset and Stride")
        local s = S.DemoOffsetAndStride
        local k_spirals, k_points_per = 11, 50
        local data = s.data
        for p = 0, k_points_per - 1 do
            for sp = 0, k_spirals - 1 do
                local r = sp / (k_spirals - 1) * 0.2 + 0.2
                local theta = p / k_points_per * 6.28
                local base = p * 3 * k_spirals + 3 * sp + 1
                data[base], data[base + 1], data[base + 2] = 0.5 + r * math.cos(theta), 0.5 + r * math.sin(theta), 0.5 + 0.5 * math.sin(2.0 * theta)
            end
        end
        ImGui.BulletText("Offsetting is useful for realtime plots (see above) and circular buffers.")
        ImGui.BulletText("Striding is useful for interleaved data (e.g. audio) or plotting structs.")
        ImGui.BulletText("Here, all spiral data is stored in a single interleaved buffer:")
        ImGui.BulletText("[s0.x0 s0.y0 s0.z0 ... sn.x0 sn.y0 sn.z0 s0.x1 s0.y1 s0.z1 ... sn.x1 sn.y1 sn.z1 ... sn.xm sn.ym sn.zm]")
        ImGui.BulletText("The offset value indicates which spiral point index is considered the first.")
        ImGui.BulletText("Offsets can be negative and/or larger than the actual data count.")
        s.offset = ImGui.SliderInt("Offset", s.offset, -2 * k_points_per, 2 * k_points_per)
        if ImPlot3D.BeginPlot("##strideoffset", ImVec2(-1, 0)) then
            ImPlot3D.PushColormap(Colormap.Jet)
            for sp = 0, k_spirals - 1 do
                -- [Port] &data[s*3+k] -> Ptr proxy; Stride is in elements (3*k_spirals doubles)
                ImPlot3D.PlotLine(string.format("Spiral %d", sp), Ptr(data, sp * 3), Ptr(data, sp * 3 + 1), Ptr(data, sp * 3 + 2),
                    k_points_per, { Offset = s.offset, Stride = 3 * k_spirals })
            end
            ImPlot3D.EndPlot()
            ImPlot3D.PopColormap()
        end
    end

    local Location, LegendFlags = ImPlot3D.ImPlot3DLocation, ImPlot3D.ImPlot3DLegendFlags
    S.DemoLegendOptions = { loc = Location.East, flags = 0, num_dummy_items = 25, t = 0,
        xs1 = {}, ys1 = {}, zs1 = {}, xs2 = {}, ys2 = {}, zs2 = {}, xs3 = {}, ys3 = {}, zs3 = {} }
    local legend_flag_list = {
        { "Horizontal", "Legend entries will be displayed horizontally" },
        { "NoButtons", "Legend icons will not function as hide/show buttons" },
        { "NoHighlightItem", "Plot items will not be highlighted when their legend entry is hovered" },
    }
    function D.DemoLegendOptions()
        IMGUI_DEMO_MARKER("Plots/Legend Options")
        local s = S.DemoLegendOptions
        for i, l in { "North", "South", "West", "East" } do
            if i > 1 then ImGui.SameLine() end
            _, s.loc = ImGui.CheckboxFlags(l, s.loc, Location[l])
        end
        for _, f in legend_flag_list do
            s.flags = CHECKBOX_FLAG(s.flags, "ImPlot3DLegendFlags_" .. f[1], LegendFlags[f[1]])
            ImGui.SameLine()
            ImGui.TextDisabled("(?)")
            if ImGui.IsItemHovered() then ImGui.SetTooltip(f[2]) end
        end
        local style = ImPlot3D.GetStyle()
        ImGui.SliderFloat2("LegendPadding", style.LegendPadding, 0.0, 20.0, "%.0f")
        ImGui.SliderFloat2("LegendInnerPadding", style.LegendInnerPadding, 0.0, 10.0, "%.0f")
        ImGui.SliderFloat2("LegendSpacing", style.LegendSpacing, 0.0, 5.0, "%.0f")
        s.num_dummy_items = ImGui.SliderInt("Num Dummy Items (Demo Scrolling)", s.num_dummy_items, 0, 100)
        if ImPlot3D.BeginPlot("Legend Options Demo", ImVec2(-1, 0)) then
            ImPlot3D.SetupAxes("X-Axis", "Y-Axis", "Z-Axis")
            ImPlot3D.SetupAxesLimits(-1, 1, -1, 1, -1, 1)
            ImPlot3D.SetupLegend(s.loc, s.flags)
            -- Generate some 3D line data
            s.t += ImGui.GetIO().DeltaTime * 0.5
            local count = 50
            for i = 1, count do
                local phase = (i - 1) * 0.1 + s.t
                s.xs1[i], s.ys1[i], s.zs1[i] = 0.8 * math.cos(phase), 0.8 * math.sin(phase), 0.5 * math.sin(phase * 2)
                s.xs2[i], s.ys2[i], s.zs2[i] = 0.6 * math.cos(phase + 1.0), 0.6 * math.sin(phase + 1.0), -0.3 * math.cos(phase * 1.5)
                s.xs3[i], s.ys3[i], s.zs3[i] = 0.4 * math.sin(phase), 0.4 * math.cos(phase), 0.7 * math.cos(phase * 0.8)
            end
            ImPlot3D.PlotLine("Helix A", s.xs1, s.ys1, s.zs1, count)
            ImPlot3D.PlotLine("Helix B##IDText", s.xs2, s.ys2, s.zs2, count) -- Text after ## used for ID only
            ImPlot3D.PlotLine("##NotListed", s.xs3, s.ys3, s.zs3, count) -- Plotted, but not added to legend
            -- Add dummy items to demonstrate legend scrolling (scroll the mouse wheel over the legend)
            for i = 0, s.num_dummy_items - 1 do
                ImPlot3D.PlotDummy(string.format("Item %03d", i))
            end
            ImPlot3D.EndPlot()
        end
    end

    S.DemoMarkersAndText = {}
    function D.DemoMarkersAndText()
        IMGUI_DEMO_MARKER("Plots/Markers and Text")
        local s = S.DemoMarkersAndText
        if s.mk_size == nil then s.mk_size, s.mk_weight = ImPlot3D.GetStyle().MarkerSize, ImPlot3D.GetStyle().LineWeight end
        s.mk_size = ImGui.DragFloat("Marker Size", s.mk_size, 0.1, 2.0, 10.0, "%.2f px")
        s.mk_weight = ImGui.DragFloat("Marker Weight", s.mk_weight, 0.05, 0.5, 3.0, "%.2f px")
        if ImPlot3D.BeginPlot("##MarkerStyles", ImVec2(-1, 0), Flags.CanvasOnly) then
            local nd = AxisFlags.NoDecorations
            ImPlot3D.SetupAxes(nil, nil, nil, nd, nd, nd)
            local COUNT = Marker.COUNT
            ImPlot3D.SetupAxesLimits(-0.5, 1.5, -0.5, 1.5, 0, COUNT + 1)
            local xs, ys, zs = { 0, 0 }, { 0, 0 }, { COUNT, COUNT + 1 }
            -- Filled markers
            for m = 0, COUNT - 1 do
                xs[2] = xs[1] + math.cos(zs[1] / COUNT * 2 * IM_PI) * 0.5
                ys[2] = ys[1] + math.sin(zs[1] / COUNT * 2 * IM_PI) * 0.5
                ImGui.PushID(m)
                ImPlot3D.PlotLine("##Filled", xs, ys, zs, 2, { Marker = m, MarkerSize = s.mk_size, LineWeight = s.mk_weight })
                ImGui.PopID()
                zs[1] -= 1; zs[2] -= 1
            end
            xs[1], ys[1], zs[1] = 1, 1, COUNT
            zs[2] = zs[1] + 1
            -- Open markers
            for m = 0, COUNT - 1 do
                xs[2] = xs[1] + math.cos(zs[1] / COUNT * 2 * IM_PI) * 0.5
                ys[2] = ys[1] - math.sin(zs[1] / COUNT * 2 * IM_PI) * 0.5
                ImGui.PushID(m)
                ImPlot3D.PlotLine("##Open", xs, ys, zs, 2, { Marker = m, MarkerSize = s.mk_size, LineWeight = s.mk_weight, FillColor = ImVec4(0, 0, 0, 0) })
                ImGui.PopID()
                zs[1] -= 1; zs[2] -= 1
            end
            ImPlot3D.PlotText("Filled Markers", 0.0, 0.0, 6.0)
            ImPlot3D.PlotText("Open Markers", 1.0, 1.0, 6.0)
            ImPlot3D.PushStyleColor(ImPlot3D.ImPlot3DCol.InlayText, ImVec4(1, 0, 1, 1))
            ImPlot3D.PlotText("Rotated Text", 0.5, 0.5, 6.0, IM_PI / 4, ImVec2(0, 0))
            ImPlot3D.PopStyleColor()
            ImPlot3D.EndPlot()
        end
    end

    S.DemoNaNValues = { include_nan = true, flags = 0 }
    function D.DemoNaNValues()
        IMGUI_DEMO_MARKER("Plots/NaN Values")
        local s = S.DemoNaNValues
        local data1, data2, data3 = { 0.0, 0.25, 0.5, 0.75, 1.0 }, { 0.0, 0.25, 0.5, 0.75, 1.0 }, { 0.0, 0.25, 0.5, 0.75, 1.0 }
        if s.include_nan then data1[3] = 0 / 0 end
        _, s.include_nan = ImGui.Checkbox("Include NaN", s.include_nan)
        ImGui.SameLine()
        _, s.flags = ImGui.CheckboxFlags("Skip NaN", s.flags, LineFlags.SkipNaN)
        if ImPlot3D.BeginPlot("##NaNValues") then
            ImPlot3D.PlotLine("Line", data1, data2, data3, 5, { Flags = s.flags, Marker = Marker.Square })
            ImPlot3D.EndPlot()
        end
    end

    -- Cube [0,1]^3 as quads (+x, -x, +y, -y, +z, -z)
    -- stylua: ignore
    local unit_quads = {
        xs = { 1, 1, 1, 1,  0, 0, 0, 0,  0, 1, 1, 0,  0, 1, 1, 0,  0, 1, 1, 0,  0, 1, 1, 0 },
        ys = { 0, 1, 1, 0,  0, 1, 1, 0,  1, 1, 1, 1,  0, 0, 0, 0,  0, 0, 1, 1,  0, 0, 1, 1 },
        zs = { 0, 0, 1, 1,  0, 0, 1, 1,  0, 0, 1, 1,  0, 0, 1, 1,  1, 1, 1, 1,  0, 0, 0, 0 },
    }

    -- Gouraud-shaded duck: per-vertex normals -> point light + ambient, mapped to index-buffer slots
    local function BuildDuckColors()
        local m = Meshes.Duck
        local X, Y, Z, idx = m.VtxXs, m.VtxYs, m.VtxZs, m.Idx
        local nx, ny, nz = table.create(m.VtxCount, 0), table.create(m.VtxCount, 0), table.create(m.VtxCount, 0)
        -- Accumulate area-weighted face normals into each vertex
        for i = 1, m.IdxCount, 3 do
            local a, b, c = idx[i] + 1, idx[i + 1] + 1, idx[i + 2] + 1
            local ux, uy, uz = X[b] - X[a], Y[b] - Y[a], Z[b] - Z[a]
            local vx, vy, vz = X[c] - X[a], Y[c] - Y[a], Z[c] - Z[a]
            local fx, fy, fz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
            for _, v in { a, b, c } do nx[v] += fx; ny[v] += fy; nz[v] += fz end
        end
        local function norm(x, y, z)
            local len = math.sqrt(x * x + y * y + z * z)
            if len > 1e-8 then return x / len, y / len, z / len end
            return 0, 0, 1
        end
        -- Lighting: yellow duck (1, 0.85, 0.1), warm white light (1, 0.95, 0.8) at (2, 2, 3), dim warm ambient (0.15, 0.12, 0.03)
        local vtx_colors = {}
        for v = 1, m.VtxCount do
            local ax, ay, az = norm(nx[v], ny[v], nz[v])
            local lx, ly, lz = norm(2 - X[v], 2 - Y[v], 3 - Z[v])
            local diff = math.max(0, ax * lx + ay * ly + az * lz)
            local r = math.min(1, 0.15 + 1.0 * 1.0 * diff)
            local g = math.min(1, 0.12 + 0.85 * 0.95 * diff)
            local b = math.min(1, 0.03 + 0.1 * 0.8 * diff)
            vtx_colors[v] = IM_COL32(math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), 255)
        end
        local out = {}
        for i = 1, m.IdxCount do out[i] = vtx_colors[idx[i] + 1] end
        return out
    end

    S.Demo_PerIndexColors = { xs1 = {}, ys1 = {}, zs1 = {}, colors1 = {}, xs2 = {}, ys2 = {}, zs2 = {}, colors2 = {} }
    function D.Demo_PerIndexColors()
        IMGUI_DEMO_MARKER("Plots/Per-Index Colors")
        local s = S.Demo_PerIndexColors
        local Viridis = Colormap.Viridis
        local function cm(t, c) return ImGui.GetColorU32(ImPlot3D.SampleColormap(t, c)) end
        -- Colorful Lines
        local t = ImGui.GetTime()
        for i = 1, 1001 do
            local x = (i - 1) * 0.001
            s.xs1[i], s.ys1[i], s.zs1[i] = x, 0.5 + 0.5 * math.sin(50 * (x + t / 10)), 0.5 + 0.5 * math.cos(50 * (x + t / 10))
            s.colors1[i] = HSV_U32((i - 1) / 1000.0, 0.8, 0.9) -- Rainbow colors
        end
        for i = 1, 20 do
            local x = (i - 1) / 19.0
            s.xs2[i], s.ys2[i], s.zs2[i] = x, x * x, x * x * x
            s.colors2[i] = cm((i - 1) / 19.0, Viridis) -- Colormap colors (Viridis)
        end
        if ImPlot3D.BeginPlot("Colorful Lines") then
            ImPlot3D.PlotLine("f(x)", s.xs1, s.ys1, s.zs1, 1001, { LineColors = s.colors1 })
            ImPlot3D.PlotLine("g(x)", s.xs2, s.ys2, s.zs2, 20, { Marker = Marker.Circle, Flags = LineFlags.Segments, LineColors = s.colors2,
                MarkerFillColors = s.colors2, MarkerLineColors = s.colors2 })
            ImPlot3D.EndPlot()
        end

        -- Colorful Scatter
        if s.sc == nil then
            srand(0)
            local sc = { xs1 = {}, ys1 = {}, zs1 = {}, fill1 = {}, line1 = {}, sizes1 = {}, xs2 = {}, ys2 = {}, zs2 = {}, colors2 = {}, sizes2 = {} }
            for i = 1, 100 do
                local x = (i - 1) * 0.01
                sc.xs1[i], sc.ys1[i], sc.zs1[i] = x, x + 0.1 * rand01(), x + 0.1 * rand01()
                local hue = (i - 1) / 99.0 -- Rainbow hue colors
                sc.fill1[i], sc.line1[i] = HSV_U32(hue, 0.8, 0.9), HSV_U32(hue, 0.9, 0.7)
                sc.sizes1[i] = 2.0 + 4.0 * rand01() -- Random sizes between 2 and 6
            end
            for i = 1, 50 do
                sc.xs2[i], sc.ys2[i], sc.zs2[i] = 0.25 + 0.2 * rand01(), 0.50 + 0.2 * rand01(), 0.75 + 0.2 * rand01()
                sc.colors2[i] = cm((i - 1) / 49.0, Viridis)
                sc.sizes2[i] = 2.0 + 4.0 * rand01()
            end
            -- Colorful Triangles (pyramid, Hot colormap sampled by z) / Colorful Quads (R=x, G=y, B=z)
            sc.tx, sc.ty, sc.tz = Pyramid()
            sc.tri_colors, sc.quad_colors = {}, {}
            for i = 1, 18 do sc.tri_colors[i] = cm(0.5 * sc.tz[i], Colormap.Hot) end
            local q = unit_quads
            for i = 1, 24 do sc.quad_colors[i] = IM_COL32(q.xs[i] * 255, q.ys[i] * 255, q.zs[i] * 255, 255) end
            sc.duck_fill_colors = BuildDuckColors()
            s.sc = sc
        end
        local sc = s.sc
        if ImPlot3D.BeginPlot("Colorful Scatter") then
            ImPlot3D.PlotScatter("Data 1", sc.xs1, sc.ys1, sc.zs1, 100, { MarkerFillColors = sc.fill1, MarkerLineColors = sc.line1, MarkerSizes = sc.sizes1 })
            ImPlot3D.PlotScatter("Data 2", sc.xs2, sc.ys2, sc.zs2, 50, { Marker = Marker.Square, MarkerFillColors = sc.colors2,
                MarkerLineColors = sc.colors2, MarkerSizes = sc.sizes2, FillAlpha = 0.5 })
            ImPlot3D.EndPlot()
        end
        if ImPlot3D.BeginPlot("Colorful Triangles") then
            ImPlot3D.SetupAxesLimits(-1, 1, -1, 1, -0.5, 1.5)
            ImPlot3D.PlotTriangle("Pyramid", sc.tx, sc.ty, sc.tz, 18, { FillColors = sc.tri_colors, FillAlpha = 0.8 })
            ImPlot3D.EndPlot()
        end
        if ImPlot3D.BeginPlot("Colorful Quads") then
            ImPlot3D.SetupAxesLimits(-0.5, 1.5, -0.5, 1.5, -0.5, 1.5)
            ImPlot3D.PlotQuad("Cube", unit_quads.xs, unit_quads.ys, unit_quads.zs, 24, { FillColors = sc.quad_colors, FillAlpha = 0.8 })
            ImPlot3D.EndPlot()
        end
        if ImPlot3D.BeginPlot("Gouraud Duck") then
            ImPlot3D.SetupAxesLimits(-1, 1, -1, 1, -1, 1)
            local m = Meshes.Duck
            ImPlot3D.PlotMesh("Duck", m.VtxXs, m.VtxYs, m.VtxZs, m.Idx, m.VtxCount, m.IdxCount, { FillColors = sc.duck_fill_colors, Flags = MeshFlags.NoLines })
            ImPlot3D.EndPlot()
        end
    end

    ---------------------------------------------------------------------------
    -- [SECTION] Axes
    ---------------------------------------------------------------------------

    S.DemoBoxScale = { scale = { 1.0, 1.0, 1.0 }, xs = {}, ys = {}, zs = {} }
    function D.DemoBoxScale()
        IMGUI_DEMO_MARKER("Axes/Box Scale")
        local s = S.DemoBoxScale
        local N = 100
        for i = 1, N do
            local t = (i - 1) / (N - 1)
            s.xs[i], s.ys[i], s.zs[i] = math.sin(t * 2 * IM_PI), math.cos(t * 4 * IM_PI), t * 2 - 1
        end
        ImGui.SliderFloat3("Box Scale", s.scale, 0.1, 2.0, "%.2f")
        if ImPlot3D.BeginPlot("##BoxScale") then
            ImPlot3D.SetupBoxScale(s.scale[1], s.scale[2], s.scale[3])
            ImPlot3D.PlotLine("3D Curve", s.xs, s.ys, s.zs, N)
            ImPlot3D.EndPlot()
        end
    end

    S.DemoBoxRotation = { elevation = 45.0, azimuth = -135.0, animate = false, init_elevation = 45.0, init_azimuth = -135.0 }
    function D.DemoBoxRotation()
        IMGUI_DEMO_MARKER("Axes/Box Rotation")
        local s = S.DemoBoxRotation
        local origin, axis = { 0.0, 0.0 }, { 0.0, 1.0 }
        ImGui.Text("Rotation")
        local c1, c2
        s.elevation, c1 = ImGui.SliderFloat("Elevation", s.elevation, -90.0, 90.0, "%.1f degrees")
        s.azimuth, c2 = ImGui.SliderFloat("Azimuth", s.azimuth, -180.0, 180.0, "%.1f degrees")
        local changed = c1 or c2
        _, s.animate = ImGui.Checkbox("Animate", s.animate)
        ImGui.Text("Initial Rotation")
        ImGui.SameLine()
        HelpMarker("The rotation will be reset to the initial rotation when you double right-click")
        s.init_elevation = ImGui.SliderFloat("Initial Elevation", s.init_elevation, -90.0, 90.0, "%.1f degrees")
        s.init_azimuth = ImGui.SliderFloat("Initial Azimuth", s.init_azimuth, -180.0, 180.0, "%.1f degrees")
        if ImPlot3D.BeginPlot("##BoxRotation") then
            ImPlot3D.SetupAxesLimits(-1, 1, -1, 1, -1, 1, Cond.Always)
            ImPlot3D.SetupBoxInitialRotation(s.init_elevation, s.init_azimuth)
            if changed then ImPlot3D.SetupBoxRotation(s.elevation, s.azimuth, s.animate, Cond.Always) end
            ImPlot3D.PlotLine("X-Axis", axis, origin, origin, 2, { LineColor = ImVec4(0.8, 0.2, 0.2, 1) })
            ImPlot3D.PlotLine("Y-Axis", origin, axis, origin, 2, { LineColor = ImVec4(0.2, 0.8, 0.2, 1) })
            ImPlot3D.PlotLine("Z-Axis", origin, origin, axis, 2, { LineColor = ImVec4(0.2, 0.2, 0.8, 1) })
            ImPlot3D.EndPlot()
        end
    end

    -- @@TAIL@@
end
