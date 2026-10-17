-- ImPlot3D for imgui-luau. Port of https://github.com/brenocq/implot3d (7913cf11684730119bd284fd8e7052d140e72f61).
-- Usage: local ImPlot3D = require(path.to.ImPlot3D)(require(path.to.ImGui))
return function(G)
    local ImGui, ImVec2, ImVec4 = G.ImGui, G.ImVec2, G.ImVec4
    local IM_COL32, IM_ASSERT = G.IM_COL32, G.IM_ASSERT
    local ImPlot3D = {}
    -- [Port] internal API (implot3d_internal.h). Exposed as ImPlot3D.internal for later milestones.
    local internal = {}
    ImPlot3D.internal = internal

    -- [Port] module-level context pointer (C++ global GImPlot3D)
    local GImPlot3D = nil

    ImPlot3D.IMPLOT3D_VERSION = "0.5 WIP" -- ImPlot3D version
    ImPlot3D.IMPLOT3D_VERSION_NUM = 500 -- Integer encoded version
    ImPlot3D.IMPLOT3D_AUTO = -1 -- Deduce variable automatically
    -- [Port] function instead of macro so each use gets a fresh ImVec4
    local function IMPLOT3D_AUTO_COL() return ImVec4(0, 0, 0, -1) end -- Deduce color automatically
    ImPlot3D.IMPLOT3D_AUTO_COL = IMPLOT3D_AUTO_COL

    --------------------------------------------------------------------------
    -- [SECTION] Flags & Enumerations (implot3d.h)
    -- [Port] ImPlot3DFlags_NoTitle -> ImPlot3D.ImPlot3DFlags.NoTitle; values identical to upstream.
    --------------------------------------------------------------------------
    do
        -- Plotting properties. These provide syntactic sugar for creating ImPlot3DSpec from (ImPlot3DProp,value) pairs
        ImPlot3D.ImPlot3DProp = {
            LineColor = 0, -- Line color; IMPLOT3D_AUTO_COL will use next Colormap color
            LineColors = 1, -- Array of line colors (ImU32*); if nullptr, use LineColor for all
            LineWeight = 2, -- Line weight in pixels
            FillColor = 3, -- Fill color (applies to shaded regions); IMPLOT3D_AUTO_COL will use next Colormap color
            FillColors = 4, -- Array of fill colors (ImU32*); if nullptr, use FillColor for all
            FillAlpha = 5, -- Alpha multiplier (applies to FillColor, FillColors, MarkerFillColor, and MarkerFillColors)
            Marker = 6, -- Marker type
            MarkerSize = 7, -- Size of markers (radius) *in pixels*
            MarkerSizes = 8, -- Array of marker sizes (float*); if nullptr, use MarkerSize for all
            MarkerLineColor = 9, -- Marker outline color; IMPLOT3D_AUTO_COL will use next LineColor
            MarkerLineColors = 10, -- Array of marker outline colors (ImU32*); if nullptr, use MarkerLineColor for all
            MarkerFillColor = 11, -- Marker fill color; IMPLOT3D_AUTO_COL will use LineColor
            MarkerFillColors = 12, -- Array of marker fill colors (ImU32*); if nullptr, use MarkerFillColor for all
            Offset = 13, -- Data index offset
            Stride = 14, -- Data stride in bytes; IMPLOT3D_AUTO will result in sizeof(T) where T is the type passed to PlotX
            Flags = 15, -- Optional item flags; can be composed from common ImPlot3DItemFlags and/or specialized ImPlot3DXFlags
        }
        -- Flags for ImPlot3D::BeginPlot()
        ImPlot3D.ImPlot3DFlags = {
            None = 0, -- Default
            NoTitle = 1, -- Hide plot title
            NoLegend = 2, -- Hide plot legend
            NoMouseText = 4, -- Hide mouse position in plot coordinates
            NoClip = 8, -- Disable 3D box clipping
            NoMenus = 16, -- The user will not be able to open context menus
            Equal = 32, -- X, Y, and Z axes will be constrained to have the same units/pixel
            NoRotate = 64, -- Lock rotation interaction
            NoPan = 128, -- Lock panning/translation interaction
            NoZoom = 256, -- Lock zoom interaction
            NoInputs = 512, -- Disable all user inputs
            CanvasOnly = 7,
        }
        -- Represents a condition for SetupAxisLimits etc. (same as ImGuiCond, but we only support a subset of those enums)
        ImPlot3D.ImPlot3DCond = {
            None = 0, -- No condition (always set the variable), same as _Always
            Always = 1, -- No condition (always set the variable)
            Once = 2, -- Set the variable once per runtime session (only the first call will succeed)
        }
        ImPlot3D.ImPlot3DCol = {
            -- Plot colors
            TitleText = 0, -- Title color
            InlayText = 1, -- Color for texts appearing inside of plots
            FrameBg = 2, -- Frame background color
            PlotBg = 3, -- Plot area background color
            PlotBorder = 4, -- Plot area border color
            -- Legend colors
            LegendBg = 5, -- Legend background color
            LegendBorder = 6, -- Legend border color
            LegendText = 7, -- Legend text color
            -- Axis colors
            AxisText = 8, -- Axis label and tick lables color
            AxisGrid = 9, -- Axis grid color
            AxisTick = 10, -- Axis tick color (defaults to AxisGrid)
            AxisBg = 11, -- Background color of axis hover region (defaults to transparent)
            AxisBgHovered = 12, -- Axis hover color (defaults to ImGuiCol_ButtonHovered)
            AxisBgActive = 13, -- Axis active color (defaults to ImGuiCol_ButtonActive)
            COUNT = 14,
        }
        -- Plot styling variables
        ImPlot3D.ImPlot3DStyleVar = {
            -- Item style
            LineWeight = 0, -- float, plot item line weight in pixels
            Marker = 1, -- int,   marker specification
            MarkerSize = 2, -- float, marker size in pixels (roughly the marker's "radius")
            FillAlpha = 3, -- float, alpha modifier applied to all plot item fills
            -- Plot style
            PlotDefaultSize = 4, -- ImVec2, default size used when ImVec2(0,0) is passed to BeginPlot
            PlotMinSize = 5, -- ImVec2, minimum size plot frame can be when shrunk
            PlotPadding = 6, -- ImVec2, padding between widget frame and plot area, labels, or outside legends (i.e. main padding)
            LabelPadding = 7, -- ImVec2, padding between axes labels, tick labels, and plot edge
            ViewScaleFactor = 8, -- float, scale factor for 3D view, you can use it to make the whole plot larger or smaller
            -- Legend style
            LegendPadding = 9, -- ImVec2, legend padding from plot edges
            LegendInnerPadding = 10, -- ImVec2, legend inner padding from legend edges
            LegendSpacing = 11, -- ImVec2, spacing between legend entries
            COUNT = 12,
        }
        ImPlot3D.ImPlot3DMarker = {
            Invalid = -3, -- [Port] ImPlot3DMarkerInternal_ (implot3d_internal.h)
            None = -2, -- No marker
            Auto = -1, -- Automatic marker selection
            Circle = 0, -- Circle marker (default)
            Square = 1, -- Square maker
            Diamond = 2, -- Diamond marker
            Up = 3, -- Upward-pointing triangle marker
            Down = 4, -- Downward-pointing triangle marker
            Left = 5, -- Leftward-pointing triangle marker
            Right = 6, -- Rightward-pointing triangle marker
            Cross = 7, -- Cross marker (not fillable)
            Plus = 8, -- Plus marker (not fillable)
            Asterisk = 9, -- Asterisk marker (not fillable)
            COUNT = 10,
        }
        -- Flags for items
        ImPlot3D.ImPlot3DItemFlags = {
            None = 0, -- Default
            NoLegend = 1, -- The item won't have a legend entry displayed
            NoFit = 2, -- The item won't be considered for plot fits
        }
        -- Flags for PlotScatter
        ImPlot3D.ImPlot3DScatterFlags = {
            None = 0, -- Default
            NoLegend = 1,
            NoFit = 2,
        }
        -- Flags for PlotLine
        ImPlot3D.ImPlot3DLineFlags = {
            None = 0, -- Default
            NoLegend = 1,
            NoFit = 2,
            Segments = 1024, -- A line segment will be rendered from every two consecutive points
            Loop = 2048, -- The last and first point will be connected to form a closed loop
            SkipNaN = 4096, -- NaNs values will be skipped instead of rendered as missing data
        }
        -- [Port] Triangle/Quad/Surface/Mesh flags share identical values upstream
        local function FillFlags()
            return {
                None = 0, -- Default
                NoLegend = 1,
                NoFit = 2,
                NoLines = 1024, -- No lines will be rendered
                NoFill = 2048, -- No fill will be rendered
                NoMarkers = 4096, -- No markers will be rendered
            }
        end
        ImPlot3D.ImPlot3DTriangleFlags = FillFlags() -- Flags for PlotTriangle
        ImPlot3D.ImPlot3DQuadFlags = FillFlags() -- Flags for PlotQuad
        ImPlot3D.ImPlot3DSurfaceFlags = FillFlags() -- Flags for PlotSurface
        ImPlot3D.ImPlot3DMeshFlags = FillFlags() -- Flags for PlotMesh
        -- Flags for PlotImage
        ImPlot3D.ImPlot3DImageFlags = {
            None = 0, -- Default
            NoLegend = 1,
            NoFit = 2,
        }
        -- Flags for PlotDummy
        ImPlot3D.ImPlot3DDummyFlags = {
            None = 0, -- Default
        }
        -- Flags for legends
        ImPlot3D.ImPlot3DLegendFlags = {
            None = 0, -- Default
            NoButtons = 1, -- Legend icons will not function as hide/show buttons
            NoHighlightItem = 2, -- Plot items will not be highlighted when their legend entry is hovered
            Horizontal = 4, -- Legend entries will be displayed horizontally
        }
        -- Used to position legend on a plot
        ImPlot3D.ImPlot3DLocation = {
            Center = 0, -- Center-center
            North = 1, -- Top-center
            South = 2, -- Bottom-center
            West = 4, -- Center-left
            East = 8, -- Center-right
            NorthWest = 5, -- Top-left
            NorthEast = 9, -- Top-right
            SouthWest = 6, -- Bottom-left
            SouthEast = 10, -- Bottom-right
        }
        -- Flags for axis
        ImPlot3D.ImPlot3DAxisFlags = {
            None = 0, -- Default
            NoLabel = 1, -- No axis label will be displayed
            NoGridLines = 2, -- No grid lines will be displayed
            NoTickMarks = 4, -- No tick marks will be displayed
            NoTickLabels = 8, -- No tick labels will be displayed
            LockMin = 16, -- The axis minimum value will be locked when panning/zooming
            LockMax = 32, -- The axis maximum value will be locked when panning/zooming
            AutoFit = 64, -- Axis will be auto-fitting to data extents
            Invert = 128, -- The axis will be inverted
            PanStretch = 256, -- Panning in a locked or constrained state will cause the axis to stretch if possible
            Lock = 48,
            NoDecorations = 11,
        }
        -- Axis indices
        ImPlot3D.ImAxis3D = {
            X = 0, -- X-axis
            Y = 1, -- Y-axis
            Z = 2, -- Z-axis
            COUNT = 3,
        }
        -- Plane indices
        ImPlot3D.ImPlane3D = {
            YZ = 0, -- YZ plane (perpendicular to X-axis)
            XZ = 1, -- XZ plane (perpendicular to Y-axis)
            XY = 2, -- XY plane (perpendicular to Z-axis)
            COUNT = 3,
        }
        -- Axis scale
        ImPlot3D.ImPlot3DScale = {
            Linear = 0, -- Default linear scale
            Log10 = 1, -- Base 10 log scale
            SymLog = 2, -- Symmetric base 10 log scale
        }
        -- Colormaps
        ImPlot3D.ImPlot3DColormap = {
            Deep = 0, -- Same as seaborn "deep"
            Dark = 1, -- Same as matplotlib "Set1"
            Pastel = 2, -- Same as matplotlib "Pastel1"
            Paired = 3, -- Same as matplotlib "Paired"
            Viridis = 4, -- Same as matplotlib "viridis"
            Plasma = 5, -- Same as matplotlib "plasma"
            Hot = 6, -- Same as matplotlib/MATLAB "hot"
            Cool = 7, -- Same as matplotlib/MATLAB "cool"
            Pink = 8, -- Same as matplotlib/MATLAB "pink"
            Jet = 9, -- Same as matplotlib/MATLAB "jet"
            Twilight = 10, -- Same as matplotlib "twilight"
            RdBu = 11, -- Same as matplotlib "RdBu"
            BrBG = 12, -- Same as matplotlib "BrGB"
            PiYG = 13, -- Same as matplotlib "PiYG"
            Spectral = 14, -- Same as matplotlib "Spectral"
            Greys = 15, -- White/black
        }
    end

    local ImPlot3DCol = ImPlot3D.ImPlot3DCol
    local ImPlot3DStyleVar = ImPlot3D.ImPlot3DStyleVar
    local ImGuiCol = G.ImGuiCol

    --------------------------------------------------------------------------
    -- [SECTION] Generic Helpers (implot3d_internal.h)
    --------------------------------------------------------------------------
    do
        -- Returns true if val is NAN
        function internal.ImNan(val) return val ~= val end
        -- Returns always positive modulo (assumes r != 0)
        function internal.ImPosMod(l, r) return (l % r + r) % r end
    end

    --------------------------------------------------------------------------
    -- [SECTION] ImPlot3DPoint, ImPlot3DRay, ImPlot3DPlane, ImPlot3DBox, ImPlot3DRange, ImPlot3DQuat
    -- [Port] Operators map to metamethods. Compound assignments (a += b) rebind to a new value, as Luau does natively.
    --------------------------------------------------------------------------
    do
        local sqrt, sin, cos, acos, abs = math.sqrt, math.sin, math.cos, math.acos, math.abs

        -- ImPlot3DPoint: 3D vector to store points in 3D space
        local PointMT = {}
        local PointMethods = {}
        local function ImPlot3DPoint(x, y, z)
            return setmetatable({ x = x or 0.0, y = y or 0.0, z = z or 0.0 }, PointMT)
        end
        ImPlot3D.ImPlot3DPoint = ImPlot3DPoint

        -- Accessors
        -- [Port] operator[]: 0 -> x, 1 -> y, 2 -> z
        local idx_keys = { [0] = "x", [1] = "y", [2] = "z" }
        PointMT.__index = function(self, k)
            local f = idx_keys[k]
            if f then return rawget(self, f) end
            return PointMethods[k]
        end
        PointMT.__newindex = function(self, k, v)
            local f = idx_keys[k]
            IM_ASSERT(f ~= nil)
            rawset(self, f, v)
        end

        -- Binary operators
        -- [Port] operator*(double) / operator*(ImPlot3DPoint) / friend operator*(double, ImPlot3DPoint) overloads
        PointMT.__mul = function(a, b)
            if type(a) == "number" then return ImPlot3DPoint(a * b.x, a * b.y, a * b.z) end
            if type(b) == "number" then return ImPlot3DPoint(a.x * b, a.y * b, a.z * b) end
            return ImPlot3DPoint(a.x * b.x, a.y * b.y, a.z * b.z)
        end
        PointMT.__div = function(a, b)
            if type(b) == "number" then return ImPlot3DPoint(a.x / b, a.y / b, a.z / b) end
            return ImPlot3DPoint(a.x / b.x, a.y / b.y, a.z / b.z)
        end
        PointMT.__add = function(a, b) return ImPlot3DPoint(a.x + b.x, a.y + b.y, a.z + b.z) end
        PointMT.__sub = function(a, b) return ImPlot3DPoint(a.x - b.x, a.y - b.y, a.z - b.z) end

        -- Unary operator
        PointMT.__unm = function(a) return ImPlot3DPoint(-a.x, -a.y, -a.z) end

        -- Comparison operators
        PointMT.__eq = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end

        PointMT.__tostring = function(a) return string.format("ImPlot3DPoint(%g, %g, %g)", a.x, a.y, a.z) end

        -- Dot product
        function PointMethods:Dot(rhs) return self.x * rhs.x + self.y * rhs.y + self.z * rhs.z end

        -- Cross product
        function PointMethods:Cross(rhs)
            return ImPlot3DPoint(self.y * rhs.z - self.z * rhs.y, self.z * rhs.x - self.x * rhs.z, self.x * rhs.y - self.y * rhs.x)
        end

        -- Get vector length
        function PointMethods:Length() return sqrt(self.x * self.x + self.y * self.y + self.z * self.z) end

        -- Get vector squared length
        function PointMethods:LengthSquared() return self.x * self.x + self.y * self.y + self.z * self.z end

        -- Normalize to unit length
        function PointMethods:Normalize()
            local l = self:Length()
            self.x /= l
            self.y /= l
            self.z /= l
        end

        -- Return vector normalized to unit length
        function PointMethods:Normalized()
            local l = self:Length()
            return ImPlot3DPoint(self.x / l, self.y / l, self.z / l)
        end

        -- Check if the point is NaN
        function PointMethods:IsNaN() return internal.ImNan(self.x) or internal.ImNan(self.y) or internal.ImNan(self.z) end

        -- [Port] copy helper replacing C++ value semantics
        function PointMethods:Copy() return ImPlot3DPoint(self.x, self.y, self.z) end

        -- ImPlot3DRay: Represents a ray in 3D space with an origin and direction
        function ImPlot3D.ImPlot3DRay(origin, direction)
            return { Origin = origin or ImPlot3DPoint(), Direction = direction or ImPlot3DPoint() }
        end

        -- ImPlot3DPlane: Represents a plane in 3D space defined by a point and normal vector
        function ImPlot3D.ImPlot3DPlane(point, normal)
            return { Point = point or ImPlot3DPoint(), Normal = normal or ImPlot3DPoint() }
        end

        -- ImPlot3DBox: Axis-aligned bounding box in 3D space
        local BoxMT = {}
        BoxMT.__index = BoxMT
        function ImPlot3D.ImPlot3DBox(min, max)
            return setmetatable({ Min = min or ImPlot3DPoint(), Max = max or ImPlot3DPoint() }, BoxMT)
        end

        -- Method to expand the box to include a point
        function BoxMT:Expand(point)
            local Min, Max = self.Min, self.Max
            Min.x = math.min(Min.x, point.x)
            Min.y = math.min(Min.y, point.y)
            Min.z = math.min(Min.z, point.z)
            Max.x = math.max(Max.x, point.x)
            Max.y = math.max(Max.y, point.y)
            Max.z = math.max(Max.z, point.z)
        end

        -- Method to check if a point is inside the box
        function BoxMT:Contains(point)
            local Min, Max = self.Min, self.Max
            return (point.x >= Min.x and point.x <= Max.x) and (point.y >= Min.y and point.y <= Max.y) and (point.z >= Min.z and point.z <= Max.z)
        end

        -- Method to clip a line segment against the box
        -- [Port] returns p0_clipped, p1_clipped, result (clipped points are nil when result is false)
        function BoxMT:ClipLineSegment(p0, p1)
            -- Check if the line segment is completely inside the box
            if self:Contains(p0) and self:Contains(p1) then
                return p0:Copy(), p1:Copy(), true
            end

            -- Perform Liang-Barsky 3D clipping
            local t0 = 0.0
            local t1 = 1.0
            local d = p1 - p0

            -- Define the clipping boundaries
            local xmin, xmax = self.Min.x, self.Max.x
            local ymin, ymax = self.Min.y, self.Max.y
            local zmin, zmax = self.Min.z, self.Max.z

            -- Lambda function to update t0 and t1
            local function update(p, q)
                if p == 0.0 then
                    if q < 0.0 then
                        return false -- Line is parallel and outside the boundary
                    else
                        return true -- Line is parallel and inside or coincident with boundary
                    end
                end
                local r = q / p
                if p < 0.0 then
                    if r > t1 then return false end -- Line is outside
                    if r > t0 then t0 = r end -- Move up t0
                else
                    if r < t0 then return false end -- Line is outside
                    if r < t1 then t1 = r end -- Move down t1
                end
                return true
            end

            -- Clip against each boundary
            if not update(-d.x, p0.x - xmin) then return nil, nil, false end -- Left
            if not update(d.x, xmax - p0.x) then return nil, nil, false end -- Right
            if not update(-d.y, p0.y - ymin) then return nil, nil, false end -- Bottom
            if not update(d.y, ymax - p0.y) then return nil, nil, false end -- Top
            if not update(-d.z, p0.z - zmin) then return nil, nil, false end -- Near
            if not update(d.z, zmax - p0.z) then return nil, nil, false end -- Far

            -- Compute clipped points
            return p0 + d * t0, p0 + d * t1, true
        end

        -- ImPlot3DRange: Represents a 1D range with min and max values
        local RangeMT = {}
        RangeMT.__index = RangeMT
        function ImPlot3D.ImPlot3DRange(min, max)
            return setmetatable({ Min = min or 0.0, Max = max or 0.0 }, RangeMT)
        end
        -- Expand range to include value
        function RangeMT:Expand(value)
            self.Min = math.min(self.Min, value)
            self.Max = math.max(self.Max, value)
        end
        -- Check if value is within range
        function RangeMT:Contains(value) return value >= self.Min and value <= self.Max end
        -- Get range size
        function RangeMT:Size() return self.Max - self.Min end

        -- ImPlot3DQuat: Quaternion for representing 3D rotations
        local QuatMT = {}
        QuatMT.__index = QuatMT
        -- [Port] ImPlot3DQuat() / (x, y, z, w) / (angle, axis) constructor overloads
        local function ImPlot3DQuat(a, b, c, d)
            if type(b) == "table" then
                -- Construct quaternion from angle-axis representation (angle in radians)
                local half_angle = a * 0.5
                local s = sin(half_angle)
                return setmetatable({ x = s * b.x, y = s * b.y, z = s * b.z, w = cos(half_angle) }, QuatMT)
            end
            if a == nil then
                return setmetatable({ x = 0.0, y = 0.0, z = 0.0, w = 1.0 }, QuatMT)
            end
            return setmetatable({ x = a, y = b, z = c, w = d }, QuatMT)
        end
        -- [Port] callable table so statics work as ImPlot3D.ImPlot3DQuat.FromTwoVectors(...) (also reachable via instances)
        ImPlot3D.ImPlot3DQuat = setmetatable({}, {
            __index = QuatMT,
            __call = function(_, ...) return ImPlot3DQuat(...) end,
        })

        -- Create quaternion that rotates from v0 to v1
        function QuatMT.FromTwoVectors(v0, v1)
            local q = ImPlot3DQuat()

            -- Compute the dot product and lengths of the vectors
            local dot = v0:Dot(v1)
            local length_v0 = v0:Length()
            local length_v1 = v1:Length()

            -- Normalize the dot product
            local normalized_dot = dot / (length_v0 * length_v1)

            -- Handle edge cases: if vectors are very close or identical
            local epsilon = 1e-6
            if abs(normalized_dot - 1.0) < epsilon then
                -- v0 and v1 are nearly identical; return an identity quaternion
                return q
            end

            -- Handle edge case: if vectors are opposite
            if abs(normalized_dot + 1.0) < epsilon then
                -- v0 and v1 are opposite; choose an arbitrary orthogonal axis
                local arbitrary_axis
                if abs(v0.x) > abs(v0.z) then
                    arbitrary_axis = ImPlot3DPoint(-v0.y, v0.x, 0.0)
                else
                    arbitrary_axis = ImPlot3DPoint(0.0, -v0.z, v0.y)
                end
                arbitrary_axis:Normalize()
                q.x = arbitrary_axis.x
                q.y = arbitrary_axis.y
                q.z = arbitrary_axis.z
                q.w = 0.0
                return q
            end

            -- General case
            local axis = v0:Cross(v1)
            axis:Normalize()
            local angle = acos(normalized_dot)
            local half_angle = angle * 0.5
            local s = sin(half_angle)
            q.x = s * axis.x
            q.y = s * axis.y
            q.z = s * axis.z
            q.w = cos(half_angle)

            return q
        end

        -- Create quaternion from elevation and azimuth angles (in radians)
        function QuatMT.FromElAz(elevation, azimuth)
            -- Create quaternions for azimuth and elevation
            local azimuth_quat = ImPlot3DQuat(azimuth, ImPlot3DPoint(0.0, 0.0, 1.0)) -- Rotate around Z-axis
            local elevation_quat = ImPlot3DQuat(elevation, ImPlot3DPoint(1.0, 0.0, 0.0)) -- Rotate around X-axis
            local zero_quat = ImPlot3DQuat(-math.pi / 2, ImPlot3DPoint(1.0, 0.0, 0.0)) -- Rotate to zero azimuth/elevation orientation

            -- Combine rotations
            return elevation_quat * zero_quat * azimuth_quat
        end

        -- Get quaternion length
        function QuatMT:Length() return sqrt(self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w) end

        -- Get normalized quaternion
        function QuatMT:Normalized()
            local l = self:Length()
            return ImPlot3DQuat(self.x / l, self.y / l, self.z / l, self.w / l)
        end

        -- Conjugate of the quaternion
        function QuatMT:Conjugate() return ImPlot3DQuat(-self.x, -self.y, -self.z, self.w) end

        -- Inverse of the quaternion
        function QuatMT:Inverse()
            local l_squared = self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w
            return ImPlot3DQuat(-self.x / l_squared, -self.y / l_squared, -self.z / l_squared, self.w / l_squared)
        end

        -- Binary operators
        -- [Port] operator*(ImPlot3DQuat) quaternion multiplication / operator*(ImPlot3DPoint) rotate a 3D point
        QuatMT.__mul = function(q, rhs)
            local x, y, z, w = q.x, q.y, q.z, q.w
            if getmetatable(rhs) == PointMT then
                -- Extract vector part of the quaternion
                local qv = ImPlot3DPoint(x, y, z)

                -- Compute the cross products needed for rotation
                local uv = qv:Cross(rhs) -- uv = qv x point
                local uuv = qv:Cross(uv) -- uuv = qv x uv

                -- Compute the rotated vector
                return rhs + (uv * w * 2.0) + (uuv * 2.0)
            end
            return ImPlot3DQuat(w * rhs.x + x * rhs.w + y * rhs.z - z * rhs.y, w * rhs.y - x * rhs.z + y * rhs.w + z * rhs.x,
                w * rhs.z + x * rhs.y - y * rhs.x + z * rhs.w, w * rhs.w - x * rhs.x - y * rhs.y - z * rhs.z)
        end

        -- Normalize the quaternion in place
        function QuatMT:Normalize()
            local l = self:Length()
            self.x /= l
            self.y /= l
            self.z /= l
            self.w /= l
            return self
        end

        -- Comparison operators
        QuatMT.__eq = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z and a.w == b.w end

        QuatMT.__tostring = function(q) return string.format("ImPlot3DQuat(%g, %g, %g, %g)", q.x, q.y, q.z, q.w) end

        -- Spherical linear interpolation between two quaternions (t in [0,1])
        function QuatMT.Slerp(q1, q2, t)
            -- Clamp t to [0, 1]
            t = math.clamp(t, 0.0, 1.0)

            -- Compute the dot product (cosine of the angle between quaternions)
            local dot = q1.x * q2.x + q1.y * q2.y + q1.z * q2.z + q1.w * q2.w

            -- If the dot product is negative, negate one quaternion to take the shorter path
            local q2_ = q2
            if dot < 0.0 then
                q2_ = ImPlot3DQuat(-q2.x, -q2.y, -q2.z, -q2.w)
                dot = -dot
            end

            -- If the quaternions are very close, use linear interpolation to avoid numerical instability
            if dot > 0.9995 then
                return ImPlot3DQuat(q1.x + t * (q2_.x - q1.x), q1.y + t * (q2_.y - q1.y), q1.z + t * (q2_.z - q1.z), q1.w + t * (q2_.w - q1.w)):Normalized()
            end

            -- Compute the angle and the interpolation factors
            local theta_0 = acos(dot) -- Angle between input quaternions
            local theta = theta_0 * t -- Interpolated angle
            local sin_theta = sin(theta) -- Sine of interpolated angle
            local sin_theta_0 = sin(theta_0) -- Sine of original angle

            local s1 = cos(theta) - dot * sin_theta / sin_theta_0
            local s2 = sin_theta / sin_theta_0

            -- Interpolate and return the result
            return ImPlot3DQuat(s1 * q1.x + s2 * q2_.x, s1 * q1.y + s2 * q2_.y, s1 * q1.z + s2 * q2_.z, s1 * q1.w + s2 * q2_.w)
        end

        -- Get quaternion dot product
        function QuatMT:Dot(rhs) return self.x * rhs.x + self.y * rhs.y + self.z * rhs.z + self.w * rhs.w end
    end

    --------------------------------------------------------------------------
    -- [SECTION] ImPlot3DStyle
    --------------------------------------------------------------------------
    do
        function ImPlot3D.ImPlot3DStyle()
            local s = {}
            -- Item style
            s.LineWeight = 1.0
            s.Marker = ImPlot3D.ImPlot3DMarker.None
            s.MarkerSize = 4.0
            s.FillAlpha = 1.0
            -- Plot style
            s.PlotDefaultSize = ImVec2(400, 400)
            s.PlotMinSize = ImVec2(200, 200)
            s.PlotPadding = ImVec2(10, 10)
            s.LabelPadding = ImVec2(5, 5)
            s.ViewScaleFactor = 1.0
            -- Legend style
            s.LegendPadding = ImVec2(10, 10)
            s.LegendInnerPadding = ImVec2(5, 5)
            s.LegendSpacing = ImVec2(5, 0)
            -- Colors
            -- [Port] Colors is keyed by 0-based ImPlot3DCol values: Colors[ImPlot3DCol.FrameBg]
            s.Colors = {}
            ImPlot3D.StyleColorsAuto(s)
            s.Colormap = ImPlot3D.ImPlot3DColormap.Deep
            return s
        end
    end

    --------------------------------------------------------------------------
    -- [SECTION] Styles
    --------------------------------------------------------------------------
    do
        -- [Port] ImPlot3DStyleVarInfo: { Type, Count, Field }, keyed by 0-based ImPlot3DStyleVar
        local GPlot3DStyleVarInfo = {
            -- Item style
            [ImPlot3DStyleVar.LineWeight] = { Type = "Float", Count = 1, Field = "LineWeight" },
            [ImPlot3DStyleVar.Marker] = { Type = "S32", Count = 1, Field = "Marker" },
            [ImPlot3DStyleVar.MarkerSize] = { Type = "Float", Count = 1, Field = "MarkerSize" },
            [ImPlot3DStyleVar.FillAlpha] = { Type = "Float", Count = 1, Field = "FillAlpha" },

            -- Plot style
            [ImPlot3DStyleVar.PlotDefaultSize] = { Type = "Float", Count = 2, Field = "PlotDefaultSize" },
            [ImPlot3DStyleVar.PlotMinSize] = { Type = "Float", Count = 2, Field = "PlotMinSize" },
            [ImPlot3DStyleVar.PlotPadding] = { Type = "Float", Count = 2, Field = "PlotPadding" },
            [ImPlot3DStyleVar.LabelPadding] = { Type = "Float", Count = 2, Field = "LabelPadding" },
            [ImPlot3DStyleVar.ViewScaleFactor] = { Type = "Float", Count = 1, Field = "ViewScaleFactor" },

            -- Legend style
            [ImPlot3DStyleVar.LegendPadding] = { Type = "Float", Count = 2, Field = "LegendPadding" },
            [ImPlot3DStyleVar.LegendInnerPadding] = { Type = "Float", Count = 2, Field = "LegendInnerPadding" },
            [ImPlot3DStyleVar.LegendSpacing] = { Type = "Float", Count = 2, Field = "LegendSpacing" },
        }

        local function GetPlotStyleVarInfo(idx)
            IM_ASSERT(idx >= 0 and idx < ImPlot3DStyleVar.COUNT)
            return GPlot3DStyleVarInfo[idx]
        end

        function ImPlot3D.GetStyle()
            IM_ASSERT(GImPlot3D ~= nil, "No current context. Did you call ImPlot3D::CreateContext() or ImPlot3D::SetCurrentContext()?")
            return GImPlot3D.Style
        end
        function ImPlot3D.SetStyle(style)
            -- [Port] copy assignment
            local s = table.clone(style)
            s.Colors = table.clone(style.Colors)
            GImPlot3D.Style = s
        end

        -- [Port] C++ `dst ? dst : &ImPlot3D::GetStyle()`
        local function StyleOrCurrent(dst)
            if dst then return dst end
            return ImPlot3D.GetStyle()
        end

        function ImPlot3D.StyleColorsAuto(dst)
            local style = StyleOrCurrent(dst)
            local colors = style.Colors

            colors[ImPlot3DCol.TitleText] = IMPLOT3D_AUTO_COL()
            colors[ImPlot3DCol.InlayText] = IMPLOT3D_AUTO_COL()
            colors[ImPlot3DCol.FrameBg] = IMPLOT3D_AUTO_COL()
            colors[ImPlot3DCol.PlotBg] = IMPLOT3D_AUTO_COL()
            colors[ImPlot3DCol.PlotBorder] = IMPLOT3D_AUTO_COL()
            colors[ImPlot3DCol.LegendBg] = IMPLOT3D_AUTO_COL()
            colors[ImPlot3DCol.LegendBorder] = IMPLOT3D_AUTO_COL()
            colors[ImPlot3DCol.LegendText] = IMPLOT3D_AUTO_COL()
            colors[ImPlot3DCol.AxisText] = IMPLOT3D_AUTO_COL()
            colors[ImPlot3DCol.AxisGrid] = IMPLOT3D_AUTO_COL()
            colors[ImPlot3DCol.AxisTick] = IMPLOT3D_AUTO_COL()
            colors[ImPlot3DCol.AxisBg] = IMPLOT3D_AUTO_COL()
            colors[ImPlot3DCol.AxisBgHovered] = IMPLOT3D_AUTO_COL()
            colors[ImPlot3DCol.AxisBgActive] = IMPLOT3D_AUTO_COL()
        end

        function ImPlot3D.StyleColorsDark(dst)
            local style = StyleOrCurrent(dst)
            local colors = style.Colors

            colors[ImPlot3DCol.TitleText] = ImVec4(1.00, 1.00, 1.00, 1.00)
            colors[ImPlot3DCol.InlayText] = ImVec4(1.00, 1.00, 1.00, 1.00)
            colors[ImPlot3DCol.FrameBg] = ImVec4(1.00, 1.00, 1.00, 0.07)
            colors[ImPlot3DCol.PlotBg] = ImVec4(0.00, 0.00, 0.00, 0.50)
            colors[ImPlot3DCol.PlotBorder] = ImVec4(0.43, 0.43, 0.50, 0.50)
            colors[ImPlot3DCol.LegendBg] = ImVec4(0.08, 0.08, 0.08, 0.94)
            colors[ImPlot3DCol.LegendBorder] = ImVec4(0.43, 0.43, 0.50, 0.50)
            colors[ImPlot3DCol.LegendText] = ImVec4(1.00, 1.00, 1.00, 1.00)
            colors[ImPlot3DCol.AxisText] = ImVec4(1.00, 1.00, 1.00, 1.00)
            colors[ImPlot3DCol.AxisGrid] = ImVec4(1.00, 1.00, 1.00, 0.25)
            colors[ImPlot3DCol.AxisTick] = IMPLOT3D_AUTO_COL()
            colors[ImPlot3DCol.AxisBg] = IMPLOT3D_AUTO_COL()
            colors[ImPlot3DCol.AxisBgHovered] = IMPLOT3D_AUTO_COL()
            colors[ImPlot3DCol.AxisBgActive] = IMPLOT3D_AUTO_COL()
        end

        function ImPlot3D.StyleColorsLight(dst)
            local style = StyleOrCurrent(dst)
            local colors = style.Colors

            colors[ImPlot3DCol.TitleText] = ImVec4(0.00, 0.00, 0.00, 1.00)
            colors[ImPlot3DCol.InlayText] = ImVec4(0.00, 0.00, 0.00, 1.00)
            colors[ImPlot3DCol.FrameBg] = ImVec4(1.00, 1.00, 1.00, 1.00)
            colors[ImPlot3DCol.PlotBg] = ImVec4(0.42, 0.57, 1.00, 0.13)
            colors[ImPlot3DCol.PlotBorder] = ImVec4(0.00, 0.00, 0.00, 0.00)
            colors[ImPlot3DCol.LegendBg] = ImVec4(1.00, 1.00, 1.00, 0.98)
            colors[ImPlot3DCol.LegendBorder] = ImVec4(0.82, 0.82, 0.82, 0.80)
            colors[ImPlot3DCol.LegendText] = ImVec4(0.00, 0.00, 0.00, 1.00)
            colors[ImPlot3DCol.AxisText] = ImVec4(0.00, 0.00, 0.00, 1.00)
            colors[ImPlot3DCol.AxisGrid] = ImVec4(1.00, 1.00, 1.00, 1.00)
            colors[ImPlot3DCol.AxisTick] = IMPLOT3D_AUTO_COL()
            colors[ImPlot3DCol.AxisBg] = IMPLOT3D_AUTO_COL()
            colors[ImPlot3DCol.AxisBgHovered] = IMPLOT3D_AUTO_COL()
            colors[ImPlot3DCol.AxisBgActive] = IMPLOT3D_AUTO_COL()
        end

        function ImPlot3D.StyleColorsClassic(dst)
            local style = StyleOrCurrent(dst)
            local colors = style.Colors

            colors[ImPlot3DCol.TitleText] = ImVec4(0.90, 0.90, 0.90, 1.00)
            colors[ImPlot3DCol.InlayText] = ImVec4(0.90, 0.90, 0.90, 1.00)
            colors[ImPlot3DCol.FrameBg] = ImVec4(0.43, 0.43, 0.43, 0.39)
            colors[ImPlot3DCol.PlotBg] = ImVec4(0.00, 0.00, 0.00, 0.35)
            colors[ImPlot3DCol.PlotBorder] = ImVec4(0.50, 0.50, 0.50, 0.50)
            colors[ImPlot3DCol.LegendBg] = ImVec4(0.11, 0.11, 0.14, 0.92)
            colors[ImPlot3DCol.LegendBorder] = ImVec4(0.50, 0.50, 0.50, 0.50)
            colors[ImPlot3DCol.LegendText] = ImVec4(0.90, 0.90, 0.90, 1.00)
            colors[ImPlot3DCol.AxisText] = ImVec4(0.90, 0.90, 0.90, 1.00)
            colors[ImPlot3DCol.AxisGrid] = ImVec4(0.90, 0.90, 0.90, 0.25)
            colors[ImPlot3DCol.AxisTick] = IMPLOT3D_AUTO_COL()
            colors[ImPlot3DCol.AxisBg] = IMPLOT3D_AUTO_COL()
            colors[ImPlot3DCol.AxisBgHovered] = IMPLOT3D_AUTO_COL()
            colors[ImPlot3DCol.AxisBgActive] = IMPLOT3D_AUTO_COL()
        end

        -- [Port] PushStyleColor(idx, ImU32) / PushStyleColor(idx, ImVec4) overloads
        function ImPlot3D.PushStyleColor(idx, col)
            local gp = GImPlot3D
            local b = gp.Style.Colors[idx]
            table.insert(gp.ColorModifiers, { Col = idx, BackupValue = ImVec4(b.x, b.y, b.z, b.w) })
            if type(col) == "number" then
                gp.Style.Colors[idx] = ImGui.ColorConvertU32ToFloat4(col)
            else
                gp.Style.Colors[idx] = ImVec4(col.x, col.y, col.z, col.w)
            end
        end

        function ImPlot3D.PopStyleColor(count)
            if count == nil then count = 1 end
            local gp = GImPlot3D
            IM_ASSERT(count <= #gp.ColorModifiers, "You can't pop more modifiers than have been pushed!")
            while count > 0 do
                local backup = table.remove(gp.ColorModifiers)
                gp.Style.Colors[backup.Col] = backup.BackupValue
                count = count - 1
            end
        end

        -- [Port] float/int/ImVec2 overloads merged: number -> Count 1 (Float or S32), table -> Count 2.
        -- Luau has one number type, so the int overload's float fallback is implicit.
        function ImPlot3D.PushStyleVar(idx, val)
            local gp = GImPlot3D
            local var_info = GetPlotStyleVarInfo(idx)
            if type(val) == "number" then
                if var_info.Count == 1 then
                    table.insert(gp.StyleModifiers, { VarIdx = idx, Backup = gp.Style[var_info.Field] })
                    gp.Style[var_info.Field] = val
                    return
                end
                IM_ASSERT(false, "Called PushStyleVar() float variant but variable is not a float!")
            else
                if var_info.Type == "Float" and var_info.Count == 2 then
                    local p = gp.Style[var_info.Field]
                    table.insert(gp.StyleModifiers, { VarIdx = idx, Backup = ImVec2(p.x, p.y) })
                    gp.Style[var_info.Field] = ImVec2(val.x, val.y)
                    return
                end
                IM_ASSERT(false, "Called PushStyleVar() ImVec2 variant but variable is not a ImVec2!")
            end
        end

        function ImPlot3D.PopStyleVar(count)
            if count == nil then count = 1 end
            local gp = GImPlot3D
            IM_ASSERT(count <= #gp.StyleModifiers, "You can't pop more modifiers than have been pushed!")
            while count > 0 do
                local backup = table.remove(gp.StyleModifiers)
                local info = GetPlotStyleVarInfo(backup.VarIdx)
                gp.Style[info.Field] = backup.Backup
                count = count - 1
            end
        end

        -- [SECTION] Style Utils
        function internal.IsColorAuto(col)
            -- [Port] IsColorAuto(ImVec4) / IsColorAuto(ImPlot3DCol) overloads
            if type(col) == "number" then col = GImPlot3D.Style.Colors[col] end
            return col.w == -1
        end

        function internal.GetAutoColor(idx)
            if idx == ImPlot3DCol.TitleText then return ImGui.GetStyleColorVec4(ImGuiCol.Text) end
            if idx == ImPlot3DCol.InlayText then return ImGui.GetStyleColorVec4(ImGuiCol.Text) end
            if idx == ImPlot3DCol.FrameBg then return ImGui.GetStyleColorVec4(ImGuiCol.FrameBg) end
            if idx == ImPlot3DCol.PlotBg then return ImGui.GetStyleColorVec4(ImGuiCol.WindowBg) end
            if idx == ImPlot3DCol.PlotBorder then return ImGui.GetStyleColorVec4(ImGuiCol.Border) end
            if idx == ImPlot3DCol.LegendBg then return ImGui.GetStyleColorVec4(ImGuiCol.PopupBg) end
            if idx == ImPlot3DCol.LegendBorder then return ImGui.GetStyleColorVec4(ImGuiCol.Border) end
            if idx == ImPlot3DCol.LegendText then return ImGui.GetStyleColorVec4(ImGuiCol.Text) end
            if idx == ImPlot3DCol.AxisText then return ImGui.GetStyleColorVec4(ImGuiCol.Text) end
            if idx == ImPlot3DCol.AxisGrid then
                local c = ImGui.GetStyleColorVec4(ImGuiCol.Text)
                return ImVec4(c.x, c.y, c.z, c.w * 0.25)
            end
            if idx == ImPlot3DCol.AxisTick then return ImPlot3D.GetStyleColorVec4(ImPlot3DCol.AxisGrid) end
            if idx == ImPlot3DCol.AxisBg then return ImVec4(0, 0, 0, 0) end
            if idx == ImPlot3DCol.AxisBgHovered then return ImGui.GetStyleColorVec4(ImGuiCol.ButtonHovered) end
            if idx == ImPlot3DCol.AxisBgActive then return ImGui.GetStyleColorVec4(ImGuiCol.ButtonActive) end
            return IMPLOT3D_AUTO_COL()
        end

        local color_names = {
            "TitleText", "InlayText", "FrameBg", "PlotBg", "PlotBorder", "LegendBg", "LegendBorder",
            "LegendText", "AxisText", "AxisGrid", "AxisTick", "AxisBg", "AxisBgHovered", "AxisBgActive",
        }
        function internal.GetStyleColorName(idx)
            return color_names[idx + 1] -- [Port] 0-based idx
        end

        -- Returns white or black text given background color
        -- [Port] CalcTextColor(ImVec4) / CalcTextColor(ImU32) overloads
        function internal.CalcTextColor(bg)
            if type(bg) == "number" then bg = ImGui.ColorConvertU32ToFloat4(bg) end
            if (bg.x * 0.299 + bg.y * 0.587 + bg.z * 0.114) > 0.5 then return G.IM_COL32_BLACK end
            return G.IM_COL32_WHITE
        end

        -- Get color
        function ImPlot3D.GetStyleColorVec4(idx)
            if internal.IsColorAuto(idx) then return internal.GetAutoColor(idx) end
            local c = GImPlot3D.Style.Colors[idx]
            return ImVec4(c.x, c.y, c.z, c.w) -- [Port] by-value copy
        end

        function ImPlot3D.GetStyleColorU32(idx) return ImGui.ColorConvertFloat4ToU32(ImPlot3D.GetStyleColorVec4(idx)) end
    end

    --------------------------------------------------------------------------
    -- [SECTION] Colormap data storage (implot3d_internal.h ImPlot3DColormapData)
    -- [Port] ImVectors -> 1-based Lua arrays; offsets/indices stay 0-based values (array[off + idx + 1]).
    -- [Port] Text/TextOffsets -> Names[cmap + 1]; ImGuiStorage Map keyed by ImHashStr -> Lua table keyed by name.
    --------------------------------------------------------------------------
    do
        local band, bor, rshift = bit32.band, bit32.bor, bit32.rshift

        -- Mix color a and b by factor s in [0 256]
        local function ImMixU32(a, b, s)
            local af = 256 - s
            local bf = s
            local al = band(a, 0x00ff00ff)
            local ah = rshift(band(a, 0xff00ff00), 8)
            local bl = band(b, 0x00ff00ff)
            local bh = rshift(band(b, 0xff00ff00), 8)
            local ml = al * af + bl * bf
            local mh = ah * af + bh * bf
            return bor(band(mh, 0xff00ff00), rshift(band(ml, 0xff00ff00), 8))
        end
        internal.ImMixU32 = ImMixU32

        local CM = {}
        CM.__index = CM

        function internal.ImPlot3DColormapData()
            return setmetatable({
                Keys = {}, KeyCounts = {}, KeyOffsets = {},
                Tables = {}, TableSizes = {}, TableOffsets = {},
                Names = {}, Quals = {}, Map = {}, Count = 0,
            }, CM)
        end

        function CM:Append(name, keys, count, qual)
            if self:GetIndex(name) ~= -1 then
                return -1
            end
            table.insert(self.KeyOffsets, #self.Keys)
            table.insert(self.KeyCounts, count)
            for i = 1, count do
                table.insert(self.Keys, keys[i])
            end
            table.insert(self.Names, name)
            table.insert(self.Quals, qual)
            local idx = self.Count
            self.Count = self.Count + 1
            self.Map[name] = idx
            self:_AppendTable(idx)
            return idx
        end

        function CM:_AppendTable(cmap)
            local key_count = self:GetKeyCount(cmap)
            local koff = self.KeyOffsets[cmap + 1]
            local keys = self.Keys
            local tables = self.Tables
            local off = #tables
            table.insert(self.TableOffsets, off)
            if self:IsQual(cmap) then
                for i = 0, key_count - 1 do
                    table.insert(tables, keys[koff + i + 1])
                end
                table.insert(self.TableSizes, key_count)
            else
                local max_size = 255 * (key_count - 1) + 1
                for i = 0, key_count - 2 do
                    for s = 0, 254 do
                        local a = keys[koff + i + 1]
                        local b = keys[koff + i + 2]
                        table.insert(tables, ImMixU32(a, b, s))
                    end
                end
                table.insert(tables, keys[koff + key_count])
                table.insert(self.TableSizes, max_size)
            end
        end

        function CM:RebuildTables()
            table.clear(self.Tables)
            table.clear(self.TableSizes)
            table.clear(self.TableOffsets)
            for i = 0, self.Count - 1 do
                self:_AppendTable(i)
            end
        end

        function CM:IsQual(cmap) return self.Quals[cmap + 1] end
        function CM:GetName(cmap)
            if cmap < self.Count then return self.Names[cmap + 1] end
            return nil
        end
        function CM:GetIndex(name)
            local v = self.Map[name]
            if v == nil then return -1 end
            return v
        end

        -- [Port] GetKeys/GetTable return (array, 0-based offset) instead of a pointer
        function CM:GetKeys(cmap) return self.Keys, self.KeyOffsets[cmap + 1] end
        function CM:GetKeyCount(cmap) return self.KeyCounts[cmap + 1] end
        function CM:GetKeyColor(cmap, idx) return self.Keys[self.KeyOffsets[cmap + 1] + idx + 1] end
        function CM:SetKeyColor(cmap, idx, value)
            self.Keys[self.KeyOffsets[cmap + 1] + idx + 1] = value
            self:RebuildTables()
        end

        function CM:GetTable(cmap) return self.Tables, self.TableOffsets[cmap + 1] end
        function CM:GetTableSize(cmap) return self.TableSizes[cmap + 1] end
        function CM:GetTableColor(cmap, idx) return self.Tables[self.TableOffsets[cmap + 1] + idx + 1] end

        function CM:LerpTable(cmap, t)
            local off = self.TableOffsets[cmap + 1]
            local siz = self.TableSizes[cmap + 1]
            local idx
            if self.Quals[cmap + 1] then
                idx = math.clamp(math.floor(siz * t), 0, siz - 1) -- [Port] (int) truncation; t >= 0 in practice
            else
                idx = math.floor((siz - 1) * t + 0.5)
            end
            return self.Tables[off + idx + 1]
        end
    end

    --------------------------------------------------------------------------
    -- [SECTION] Context / Context Utils
    --------------------------------------------------------------------------
    do
        -- [Port] only Style and Colormap fields so far; later milestones add the rest.
        function internal.ImPlot3DContext()
            return {
                Plots = nil, -- [Port] ImPool<ImPlot3DPlot>, added with BeginPlot/EndPlot
                CurrentPlot = nil,
                CurrentItems = nil,
                CurrentItem = nil,
                NextItemData = nil,
                Style = ImPlot3D.ImPlot3DStyle(),
                ColorModifiers = {},
                StyleModifiers = {},
                ColormapModifiers = {},
                ColormapData = internal.ImPlot3DColormapData(),
            }
        end

        -- Creates a new ImPlot3D context. Call this after ImGui::CreateContext
        function ImPlot3D.CreateContext()
            local ctx = internal.ImPlot3DContext()
            if GImPlot3D == nil then
                ImPlot3D.SetCurrentContext(ctx)
            end
            internal.InitializeContext(ctx)
            return ctx
        end

        -- Destroys an ImPlot3D context. Call this before ImGui::DestroyContext. nullptr = destroy current context
        function ImPlot3D.DestroyContext(ctx)
            if ctx == nil then
                ctx = GImPlot3D
            end
            if GImPlot3D == ctx then
                ImPlot3D.SetCurrentContext(nil)
            end
        end

        -- Returns the current ImPlot3D context. nullptr if no context has been set
        function ImPlot3D.GetCurrentContext() return GImPlot3D end

        -- Sets the current ImPlot3D context
        function ImPlot3D.SetCurrentContext(ctx) GImPlot3D = ctx end

        local function IM_RGB(r, g, b) return IM_COL32(r, g, b, 255) end

        -- [Port] {name, qual, keys} in IMPLOT3D_APPEND_CMAP order
        local cmaps = {
            { "Deep", true, { 4289753676, 4283598045, 4285048917, 4283584196, 4289950337, 4284512403, 4291005402, 4287401100, 4285839820, 4291671396 } },
            { "Dark", true, { 4280031972, 4290281015, 4283084621, 4288892568, 4278222847, 4281597951, 4280833702, 4290740727, 4288256409 } },
            { "Pastel", true, { 4289639675, 4293119411, 4291161036, 4293184478, 4289124862, 4291624959, 4290631909, 4293712637, 4294111986 } },
            { "Paired", true, { 4293119554, 4290017311, 4287291314, 4281114675, 4288256763, 4280031971,
                4285513725, 4278222847, 4292260554, 4288298346, 4288282623, 4280834481 } },
            { "Viridis", false, { 4283695428, 4285867080, 4287054913, 4287455029, 4287526954, 4287402273,
                4286883874, 4285579076, 4283552122, 4280737725, 4280674301 } },
            { "Plasma", false, { 4287039501, 4288480321, 4289200234, 4288941455, 4287638193, 4286072780,
                4284638433, 4283139314, 4281771772, 4280667900, 4280416752 } },
            { "Hot", false, { 4278190144, 4278190208, 4278190271, 4278190335, 4278206719, 4278223103,
                4278239231, 4278255615, 4283826175, 4289396735, 4294967295 } },
            { "Cool", false, { 4294967040, 4294960666, 4294954035, 4294947661, 4294941030, 4294934656,
                4294928025, 4294921651, 4294915020, 4294908646, 4294902015 } },
            { "Pink", false, { 4278190154, 4282532475, 4284308894, 4285690554, 4286879686, 4287870160,
                4288794330, 4289651940, 4291685869, 4293392118, 4294967295 } },
            { "Jet", false, { 4289331200, 4294901760, 4294923520, 4294945280, 4294967040, 4289396565,
                4283826090, 4278255615, 4278233855, 4278212095, 4278190335 } },
            { "Twilight", false, { IM_RGB(226, 217, 226), IM_RGB(166, 191, 202), IM_RGB(109, 144, 192), IM_RGB(95, 88, 176),
                IM_RGB(83, 30, 124), IM_RGB(47, 20, 54), IM_RGB(100, 25, 75), IM_RGB(159, 60, 80),
                IM_RGB(192, 117, 94), IM_RGB(208, 179, 158), IM_RGB(226, 217, 226) } },
            { "RdBu", false, { IM_RGB(103, 0, 31), IM_RGB(178, 24, 43), IM_RGB(214, 96, 77), IM_RGB(244, 165, 130),
                IM_RGB(253, 219, 199), IM_RGB(247, 247, 247), IM_RGB(209, 229, 240), IM_RGB(146, 197, 222),
                IM_RGB(67, 147, 195), IM_RGB(33, 102, 172), IM_RGB(5, 48, 97) } },
            { "BrBG", false, { IM_RGB(84, 48, 5), IM_RGB(140, 81, 10), IM_RGB(191, 129, 45), IM_RGB(223, 194, 125),
                IM_RGB(246, 232, 195), IM_RGB(245, 245, 245), IM_RGB(199, 234, 229), IM_RGB(128, 205, 193),
                IM_RGB(53, 151, 143), IM_RGB(1, 102, 94), IM_RGB(0, 60, 48) } },
            { "PiYG", false, { IM_RGB(142, 1, 82), IM_RGB(197, 27, 125), IM_RGB(222, 119, 174), IM_RGB(241, 182, 218),
                IM_RGB(253, 224, 239), IM_RGB(247, 247, 247), IM_RGB(230, 245, 208), IM_RGB(184, 225, 134),
                IM_RGB(127, 188, 65), IM_RGB(77, 146, 33), IM_RGB(39, 100, 25) } },
            { "Spectral", false, { IM_RGB(158, 1, 66), IM_RGB(213, 62, 79), IM_RGB(244, 109, 67), IM_RGB(253, 174, 97),
                IM_RGB(254, 224, 139), IM_RGB(255, 255, 191), IM_RGB(230, 245, 152), IM_RGB(171, 221, 164),
                IM_RGB(102, 194, 165), IM_RGB(50, 136, 189), IM_RGB(94, 79, 162) } },
            { "Greys", false, { G.IM_COL32_WHITE, G.IM_COL32_BLACK } },
        }

        -- Initialize ImPlot3DContext
        function internal.InitializeContext(ctx)
            internal.ResetContext(ctx)
            for _, c in ipairs(cmaps) do
                ctx.ColormapData:Append(c[1], c[3], #c[3], c[2])
            end
        end

        -- Reset ImPlot3DContext
        function internal.ResetContext(ctx)
            ctx.CurrentPlot = nil
            ctx.CurrentItems = nil
            ctx.CurrentItem = nil
            ctx.Style = ImPlot3D.ImPlot3DStyle()
        end
    end

    --------------------------------------------------------------------------
    -- [SECTION] Colormaps
    --------------------------------------------------------------------------
    do
        local IMPLOT3D_AUTO = ImPlot3D.IMPLOT3D_AUTO

        -- [Port] ImVec4* / ImU32* overloads: `colormap` is a 1-based array of ImVec4 or ImU32; size defaults to #colormap
        function ImPlot3D.AddColormap(name, colormap, size, qual)
            local gp = GImPlot3D
            size = size or #colormap
            if qual == nil then qual = true end
            IM_ASSERT(size > 1, "The colormap size must be greater than 1!")
            IM_ASSERT(gp.ColormapData:GetIndex(name) == -1, "The colormap name has already been used!")
            local buffer = table.create(size)
            for i = 1, size do
                local c = colormap[i]
                if type(c) == "number" then
                    buffer[i] = c
                else
                    buffer[i] = ImGui.ColorConvertFloat4ToU32(c)
                end
            end
            return gp.ColormapData:Append(name, buffer, size, qual)
        end

        function ImPlot3D.GetColormapCount() return GImPlot3D.ColormapData.Count end

        function ImPlot3D.GetColormapName(colormap) return GImPlot3D.ColormapData:GetName(colormap) end

        function ImPlot3D.GetColormapIndex(name) return GImPlot3D.ColormapData:GetIndex(name) end

        -- [Port] PushColormap(ImPlot3DColormap) / PushColormap(const char*) overloads
        function ImPlot3D.PushColormap(colormap)
            local gp = GImPlot3D
            if type(colormap) == "string" then
                local idx = gp.ColormapData:GetIndex(colormap)
                IM_ASSERT(idx ~= -1, "The colormap name is invalid!")
                colormap = idx
            end
            IM_ASSERT(colormap >= 0 and colormap < gp.ColormapData.Count, "The colormap index is invalid!")
            table.insert(gp.ColormapModifiers, gp.Style.Colormap)
            gp.Style.Colormap = colormap
        end

        function ImPlot3D.PopColormap(count)
            if count == nil then count = 1 end
            local gp = GImPlot3D
            IM_ASSERT(count <= #gp.ColormapModifiers, "You can't pop more modifiers than have been pushed!")
            while count > 0 do
                gp.Style.Colormap = table.remove(gp.ColormapModifiers)
                count = count - 1
            end
        end

        function internal.NextColormapColorU32()
            local gp = GImPlot3D
            IM_ASSERT(gp.CurrentItems ~= nil, "NextColormapColor() needs to be called between BeginPlot() and EndPlot()!")
            local idx = gp.CurrentItems.ColormapIdx % gp.ColormapData:GetKeyCount(gp.Style.Colormap)
            local col = gp.ColormapData:GetKeyColor(gp.Style.Colormap, idx)
            gp.CurrentItems.ColormapIdx = gp.CurrentItems.ColormapIdx + 1
            return col
        end

        function ImPlot3D.NextColormapColor() return ImGui.ColorConvertU32ToFloat4(internal.NextColormapColorU32()) end

        local function ResolveCmap(gp, cmap)
            if cmap == nil or cmap == IMPLOT3D_AUTO then cmap = gp.Style.Colormap end
            IM_ASSERT(cmap >= 0 and cmap < gp.ColormapData.Count, "Invalid colormap index!")
            return cmap
        end

        function ImPlot3D.GetColormapSize(cmap)
            local gp = GImPlot3D
            cmap = ResolveCmap(gp, cmap)
            return gp.ColormapData:GetKeyCount(cmap)
        end

        function internal.GetColormapColorU32(idx, cmap)
            local gp = GImPlot3D
            cmap = ResolveCmap(gp, cmap)
            idx = idx % gp.ColormapData:GetKeyCount(cmap)
            return gp.ColormapData:GetKeyColor(cmap, idx)
        end

        function ImPlot3D.GetColormapColor(idx, cmap) return ImGui.ColorConvertU32ToFloat4(internal.GetColormapColorU32(idx, cmap)) end

        function internal.SampleColormapU32(t, cmap)
            local gp = GImPlot3D
            cmap = ResolveCmap(gp, cmap)
            return gp.ColormapData:LerpTable(cmap, t)
        end

        function ImPlot3D.SampleColormap(t, cmap) return ImGui.ColorConvertU32ToFloat4(internal.SampleColormapU32(t, cmap)) end
    end

    return ImPlot3D
end
