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
        -- Returns true if flag is set
        function internal.ImHasFlag(set, flag) return bit32.band(set, flag) == flag end
        local DBL_MAX = G.DBL_MAX
        -- Returns true if val is NAN or INFINITY
        function internal.ImNanOrInf(val) return not (val >= -DBL_MAX and val <= DBL_MAX) end
        -- Turns NANs to 0s
        function internal.ImConstrainNan(val) if val ~= val then return 0 end return val end
        -- Turns infinity to floating point maximums (half DBL_MAX to prevent overflow)
        function internal.ImConstrainInf(val)
            local max_val = DBL_MAX * 0.5
            if val >= max_val then return max_val elseif val <= -max_val then return -max_val end
            return val
        end
        internal.DBL_MIN = 2.2250738585072014e-308
        internal.DBL_EPSILON = 2.220446049250313e-16
        -- True if two numbers are approximately equal using units in the last place.
        function internal.ImAlmostEqual(v1, v2, ulp)
            ulp = ulp or 2
            local d = math.abs(v1 - v2)
            return d < internal.DBL_EPSILON * math.abs(v1 + v2) * ulp or d < internal.DBL_MIN
        end
        internal.IMPLOT3D_LABEL_FORMAT = "%g"
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
        function internal.ImPlot3DContext()
            return {
                Plots = G.ImPool(function() return internal.ImPlot3DPlot() end), -- ImPool<ImPlot3DPlot>
                CurrentPlot = nil,
                CurrentItems = nil,
                CurrentItem = nil,
                NextItemData = internal.ImPlot3DNextItemData(),
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

    --------------------------------------------------------------------------
    -- [SECTION] ImPlot3DTicker, Formatter, Locator
    -- [Port] ImPlot3DFormatter is `function(value, data) -> string` (no char buffer).
    --------------------------------------------------------------------------
    do
        -- Tick mark info
        function internal.ImPlot3DTick(value, major, show_label)
            return { PlotPos = value, Major = major, ShowLabel = show_label, LabelSize = ImVec2(0, 0), TextOffset = -1, Idx = 0, Label = nil }
        end

        local Ticker = {}
        Ticker.__index = Ticker

        -- Collection of ticks
        -- [Port] TextBuffer replaced by per-tick Label strings; TextOffset kept (0 when labelled) for parity.
        function internal.ImPlot3DTicker() return setmetatable({ Ticks = {} }, Ticker) end

        -- [Port] AddTick(value, major, show_label, label) / (..., formatter, data) / (tick) overloads
        function Ticker:AddTick(value, major, show_label, fmt, data)
            local tick
            if type(value) == "table" then
                tick = value
            else
                tick = internal.ImPlot3DTick(value, major, show_label)
                local label
                if show_label and type(fmt) == "string" then
                    label = fmt
                elseif show_label and fmt ~= nil then
                    label = fmt(tick.PlotPos, data)
                end
                if label ~= nil then
                    tick.TextOffset = 0
                    tick.Label = label
                    tick.LabelSize = ImGui.CalcTextSize(label)
                end
            end
            tick.Idx = #self.Ticks
            table.insert(self.Ticks, tick)
            return tick
        end

        -- [Port] accepts 0-based index or tick
        function Ticker:GetText(idx)
            if type(idx) == "table" then idx = idx.Idx end
            return self.Ticks[idx + 1].Label or ""
        end
        function Ticker:Reset() table.clear(self.Ticks) end
        function Ticker:TickCount() return #self.Ticks end

        -- Formatter_Default: data is a printf format string
        function internal.Formatter_Default(value, data) return string.format(data, value) end

        local function IM_ROUND(x) return math.floor(x + 0.5) end

        function internal.NiceNum(x, round)
            local expv = math.floor(math.log10(x))
            local f = x / 10 ^ expv
            local nf
            if round then
                if f < 1.5 then nf = 1 elseif f < 3 then nf = 2 elseif f < 7 then nf = 5 else nf = 10 end
            else
                if f <= 1 then nf = 1 elseif f <= 2 then nf = 2 elseif f <= 5 then nf = 5 else nf = 10 end
            end
            return nf * 10 ^ expv
        end

        function internal.Locator_Default(ticker, range, pixels, formatter, formatter_data)
            if range.Min == range.Max then return end
            local nMinor = math.min(math.max(1, IM_ROUND(pixels / 30.0)), 5)
            local nMajor = math.max(2, IM_ROUND(pixels / 80.0))
            local max_ticks_labels = 7
            local nice_range = internal.NiceNum(range:Size() * 0.99, false)
            local interval = internal.NiceNum(nice_range / (nMajor - 1), true)
            local graphmin = math.floor(range.Min / interval) * interval
            local graphmax = math.ceil(range.Max / interval) * interval
            local first_major_set = false
            local first_major_idx = 0
            local idx0 = ticker:TickCount() -- Ticker may have user custom ticks
            local major = graphmin
            while major < graphmax + 0.5 * interval do
                -- Is this zero? combat zero formatting issues
                if major - interval < 0 and major + interval > 0 then major = 0 end
                if range:Contains(major) then
                    if not first_major_set then
                        first_major_idx = ticker:TickCount()
                        first_major_set = true
                    end
                    ticker:AddTick(major, true, true, formatter, formatter_data)
                end
                for i = 1, nMinor - 1 do
                    local minor = major + i * interval / nMinor
                    if range:Contains(minor) then
                        ticker:AddTick(minor, false, true, formatter, formatter_data)
                    end
                end
                major += interval
            end
            -- Prune tick labels
            if ticker:TickCount() > max_ticks_labels then
                for i = first_major_idx - 1, idx0, -2 do ticker.Ticks[i + 1].ShowLabel = false end
                for i = first_major_idx + 1, ticker:TickCount() - 1, 2 do ticker.Ticks[i + 1].ShowLabel = false end
            end
        end

        -- [Port] values/labels are 1-based arrays
        function internal.AddTicksCustom(values, labels, n, ticker, formatter, data)
            for i = 1, n do
                if labels ~= nil then
                    ticker:AddTick(values[i], false, true, labels[i])
                else
                    ticker:AddTick(values[i], false, true, formatter, data)
                end
            end
        end
    end

    --------------------------------------------------------------------------
    -- [SECTION] ImPlot3DAxis
    -- [Port] ImPlot3DTransform is `function(value, data) -> number`.
    --------------------------------------------------------------------------
    do
        local ImPlot3DRange = ImPlot3D.ImPlot3DRange
        local AxisFlags = ImPlot3D.ImPlot3DAxisFlags
        local Cond = ImPlot3D.ImPlot3DCond
        local ImHasFlag, ImNanOrInf = internal.ImHasFlag, internal.ImNanOrInf
        local ImConstrainNan, ImConstrainInf = internal.ImConstrainNan, internal.ImConstrainInf
        local HUGE_VAL = math.huge

        local Axis = {}
        Axis.__index = Axis

        -- Holds axis information
        function internal.ImPlot3DAxis()
            return setmetatable({
                Flags = AxisFlags.None, PreviousFlags = AxisFlags.None,
                Range = ImPlot3DRange(0.0, 1.0), RangeCond = Cond.None,
                NDCScale = 1.0, Scale = ImPlot3D.ImPlot3DScale.Linear,
                Label = "", -- [Port] ImGuiTextBuffer -> string
                Ticker = internal.ImPlot3DTicker(),
                Formatter = nil, FormatterData = nil, Locator = nil, ShowDefaultTicks = true,
                TransformForward = nil, TransformInverse = nil, TransformData = nil,
                ScaledRange = ImPlot3DRange(),
                FitThisFrame = true, FitExtents = ImPlot3DRange(HUGE_VAL, -HUGE_VAL),
                ConstraintRange = ImPlot3DRange(-HUGE_VAL, HUGE_VAL),
                ConstraintZoom = ImPlot3DRange(internal.DBL_MIN, HUGE_VAL),
                Hovered = false, Held = false,
                ColorBg = 0, ColorHov = 0, ColorAct = 0, -- IM_COL32_BLACK_TRANS
            }, Axis)
        end

        function Axis:Reset()
            self.RangeCond = Cond.None
            self.Scale = ImPlot3D.ImPlot3DScale.Linear
            self.TransformForward, self.TransformInverse, self.TransformData = nil, nil, nil
            self.Ticker:Reset()
            self.Formatter, self.FormatterData, self.Locator = nil, nil, nil
            self.ShowDefaultTicks = true
            self.FitExtents = ImPlot3DRange(HUGE_VAL, -HUGE_VAL)
            self.ConstraintRange = ImPlot3DRange(-HUGE_VAL, HUGE_VAL)
            self.ConstraintZoom = ImPlot3DRange(internal.DBL_MIN, HUGE_VAL)
        end

        function Axis:SetRange(v1, v2)
            v1 = ImConstrainNan(ImConstrainInf(v1))
            v2 = ImConstrainNan(ImConstrainInf(v2))
            self.Range.Min = math.min(v1, v2)
            self.Range.Max = math.max(v1, v2)
            self:Constrain()
            self:UpdateTransformCache()
        end

        function Axis:SetMin(_min, force)
            if not force and self:IsLockedMin() then return false end
            _min = ImConstrainNan(ImConstrainInf(_min))
            -- Constraints
            if _min < self.ConstraintRange.Min then _min = self.ConstraintRange.Min end
            local zoom = self.Range.Max - _min
            if zoom < self.ConstraintZoom.Min then _min = self.Range.Max - self.ConstraintZoom.Min end
            if zoom > self.ConstraintZoom.Max then _min = self.Range.Max - self.ConstraintZoom.Max end
            -- Ensure min is less than max
            if _min >= self.Range.Max then return false end
            self.Range.Min = _min
            self:UpdateTransformCache()
            return true
        end

        function Axis:SetMax(_max, force)
            if not force and self:IsLockedMax() then return false end
            _max = ImConstrainNan(ImConstrainInf(_max))
            -- Constraints
            if _max > self.ConstraintRange.Max then _max = self.ConstraintRange.Max end
            local zoom = _max - self.Range.Min
            if zoom < self.ConstraintZoom.Min then _max = self.Range.Min + self.ConstraintZoom.Min end
            if zoom > self.ConstraintZoom.Max then _max = self.Range.Min + self.ConstraintZoom.Max end
            -- Ensure max is greater than min
            if _max <= self.Range.Min then return false end
            self.Range.Max = _max
            self:UpdateTransformCache()
            return true
        end

        function Axis:Constrain()
            local r, cr, cz = self.Range, self.ConstraintRange, self.ConstraintZoom
            r.Min = ImConstrainNan(ImConstrainInf(r.Min))
            r.Max = ImConstrainNan(ImConstrainInf(r.Max))
            if r.Min < cr.Min then r.Min = cr.Min end
            if r.Max > cr.Max then r.Max = cr.Max end
            local zoom = r:Size()
            if zoom < cz.Min then
                local delta = (cz.Min - zoom) * 0.5
                r.Min -= delta
                r.Max += delta
            end
            if zoom > cz.Max then
                local delta = (zoom - cz.Max) * 0.5
                r.Min += delta
                r.Max -= delta
            end
            if r.Max <= r.Min then r.Max = r.Min + internal.DBL_EPSILON end
        end

        function Axis:UpdateTransformCache()
            if self.TransformForward ~= nil then
                self.ScaledRange.Min = self.TransformForward(self.Range.Min, self.TransformData)
                self.ScaledRange.Max = self.TransformForward(self.Range.Max, self.TransformData)
            else
                self.ScaledRange.Min = self.Range.Min
                self.ScaledRange.Max = self.Range.Max
            end
        end

        function Axis:PlotToNDC(plt)
            if self.TransformForward ~= nil then
                local s = self.TransformForward(plt, self.TransformData)
                return (s - self.ScaledRange.Min) / (self.ScaledRange.Max - self.ScaledRange.Min)
            end
            return (plt - self.Range.Min) / (self.Range.Max - self.Range.Min)
        end

        function Axis:NDCToPlot(t)
            if self.TransformInverse ~= nil then
                local s = t * (self.ScaledRange.Max - self.ScaledRange.Min) + self.ScaledRange.Min
                return self.TransformInverse(s, self.TransformData)
            end
            return self.Range.Min + t * (self.Range.Max - self.Range.Min)
        end

        function Axis:IsRangeLocked() return self.RangeCond == Cond.Always end
        function Axis:IsLockedMin() return self:IsRangeLocked() or ImHasFlag(self.Flags, AxisFlags.LockMin) end
        function Axis:IsLockedMax() return self:IsRangeLocked() or ImHasFlag(self.Flags, AxisFlags.LockMax) end
        function Axis:IsLocked() return self:IsLockedMin() and self:IsLockedMax() end
        function Axis:IsInputLockedMin() return self:IsLockedMin() or self:IsAutoFitting() end
        function Axis:IsInputLockedMax() return self:IsLockedMax() or self:IsAutoFitting() end
        function Axis:IsInputLocked() return self:IsLocked() or self:IsAutoFitting() end

        function Axis:IsPanLocked(increasing)
            if ImHasFlag(self.Flags, AxisFlags.PanStretch) then
                return self:IsInputLocked()
            end
            if self:IsLockedMin() or self:IsLockedMax() or self:IsAutoFitting() then return false end
            if increasing then return self.Range.Max == self.ConstraintRange.Max end
            return self.Range.Min == self.ConstraintRange.Min
        end

        function Axis:SetLabel(label)
            -- [Port] FindRenderedTextEnd: label text up to "##"
            if label and (string.find(label, "##", 1, true) or #label + 1) > 1 then
                self.Label = label
            else
                self.Label = ""
            end
        end
        function Axis:GetLabel() return self.Label end

        -- By default, the axis span from NDC -0.5 to 0.5, so size is 1.0 (scaled by NDCScale)
        function Axis:NDCSize() return self.NDCScale end

        function Axis:SetAspect(units_per_ndc_unit)
            local new_size = units_per_ndc_unit * self:NDCSize()
            local delta = (new_size - self.Range:Size()) * 0.5
            local lmin, lmax = self:IsLockedMin(), self:IsLockedMax()
            if lmin and lmax then
                return
            elseif lmin then
                self:SetRange(self.Range.Min, self.Range.Max + 2 * delta)
            elseif lmax then
                self:SetRange(self.Range.Min - 2 * delta, self.Range.Max)
            else
                self:SetRange(self.Range.Min - delta, self.Range.Max + delta)
            end
        end
        function Axis:GetAspect() return self.Range:Size() / self:NDCSize() end

        function Axis:HasLabel() return self.Label ~= "" and not ImHasFlag(self.Flags, AxisFlags.NoLabel) end
        function Axis:HasGridLines() return not ImHasFlag(self.Flags, AxisFlags.NoGridLines) end
        function Axis:HasTickLabels() return not ImHasFlag(self.Flags, AxisFlags.NoTickLabels) end
        function Axis:HasTickMarks() return not ImHasFlag(self.Flags, AxisFlags.NoTickMarks) end
        function Axis:IsAutoFitting() return ImHasFlag(self.Flags, AxisFlags.AutoFit) end

        function Axis:ExtendFit(value)
            -- Only extend fit with values within the constraint range (log scale ignores <= 0)
            if not ImNanOrInf(value) and value >= self.ConstraintRange.Min and value <= self.ConstraintRange.Max then
                self.FitExtents.Min = math.min(self.FitExtents.Min, value)
                self.FitExtents.Max = math.max(self.FitExtents.Max, value)
            end
        end

        function Axis:ApplyFit()
            if not self:IsLockedMin() and not ImNanOrInf(self.FitExtents.Min) then self.Range.Min = self.FitExtents.Min end
            if not self:IsLockedMax() and not ImNanOrInf(self.FitExtents.Max) then self.Range.Max = self.FitExtents.Max end
            if internal.ImAlmostEqual(self.Range.Min, self.Range.Max) then
                self.Range.Max += 0.5
                self.Range.Min -= 0.5
            end
            self:Constrain()
            self:UpdateTransformCache()
            self.FitExtents.Min = HUGE_VAL
            self.FitExtents.Max = -HUGE_VAL
        end
    end

    --------------------------------------------------------------------------
    -- [SECTION] ImPlot3DLegend, ImPlot3DItemGroup (data only), ImPlot3DPlot
    --------------------------------------------------------------------------
    do
        local P, Q = ImPlot3D.ImPlot3DPoint, ImPlot3D.ImPlot3DQuat
        local ImHasFlag, ImNanOrInf = internal.ImHasFlag, internal.ImNanOrInf
        local ImRect = G.ImRect

        -- Holds legend state
        function internal.ImPlot3DLegend()
            local loc = ImPlot3D.ImPlot3DLocation.NorthWest
            return {
                Flags = 0, PreviousFlags = 0, Location = loc, PreviousLocation = loc,
                Scroll = ImVec2(0, 0), Indices = {}, LabelList = {}, -- [Port] Labels text buffer -> LabelList
                Rect = ImRect(), RectClamped = ImRect(), Hovered = false, Held = false,
            }
        end

        -- Holds items
        -- [Port] item methods live in internal.ItemGroup (GetItem, GetOrAddItem, ...)
        function internal.ImPlot3DItemGroup()
            return { ID = 0, ItemPool = G.ImPool(function() return internal.ImPlot3DItem() end), Legend = internal.ImPlot3DLegend(), ColormapIdx = 0, MarkerIdx = 0 }
        end

        local Plot = {}
        Plot.__index = Plot

        -- Holds plot state information that must persist after EndPlot
        function internal.ImPlot3DPlot()
            local rot = Q(0.0, 0.0, 0.0, 1.0)
            return setmetatable({
                ID = 0, Flags = 0, PreviousFlags = 0, Title = "",
                JustCreated = true, Initialized = false,
                FrameRect = ImRect(), CanvasRect = ImRect(), PlotRect = ImRect(),
                InitialRotation = Q(-0.513269, -0.212596, -0.318184, 0.76819),
                Rotation = rot, RotationCond = ImPlot3D.ImPlot3DCond.None,
                Axes = { [0] = internal.ImPlot3DAxis(), internal.ImPlot3DAxis(), internal.ImPlot3DAxis() }, -- [Port] 0-based like ImAxis3D
                AnimationTime = 0.0, RotationAnimationEnd = rot,
                SetupLocked = false, Hovered = false, Held = false,
                HeldEdgeIdx = -1, HeldPlaneIdx = -1, DragRotationAxis = P(0.0, 0.0, 0.0),
                FitThisFrame = true,
                Items = internal.ImPlot3DItemGroup(),
                DrawList = internal.ImDrawList3D(),
                ContextClick = false, OpenContextThisFrame = false,
            }, Plot)
        end

        function Plot:SetTitle(title)
            if title and (string.find(title, "##", 1, true) or #title + 1) > 1 then self.Title = title else self.Title = "" end
        end
        function Plot:HasTitle() return self.Title ~= "" and not ImHasFlag(self.Flags, ImPlot3D.ImPlot3DFlags.NoTitle) end
        function Plot:GetTitle() return self.Title end
        function Plot:IsRotationLocked() return self.RotationCond == ImPlot3D.ImPlot3DCond.Always end

        -- Extends the fit range of all three axes to include the provided point
        function Plot:ExtendFit(point)
            for i = 0, 2 do
                if not ImNanOrInf(point[i]) and self.Axes[i].FitThisFrame then self.Axes[i]:ExtendFit(point[i]) end
            end
        end

        function Plot:RangeMin() local a = self.Axes return P(a[0].Range.Min, a[1].Range.Min, a[2].Range.Min) end
        function Plot:RangeMax() local a = self.Axes return P(a[0].Range.Max, a[1].Range.Max, a[2].Range.Max) end
        function Plot:RangeCenter()
            local a = self.Axes
            return P((a[0].Range.Min + a[0].Range.Max) * 0.5, (a[1].Range.Min + a[1].Range.Max) * 0.5, (a[2].Range.Min + a[2].Range.Max) * 0.5)
        end

        function Plot:SetRange(min, max)
            self.Axes[0]:SetRange(min.x, max.x)
            self.Axes[1]:SetRange(min.y, max.y)
            self.Axes[2]:SetRange(min.z, max.z)
        end

        -- Constant to convert from NDC coordinates to pixels coordinates
        function Plot:GetViewScale()
            return math.min(self.PlotRect:GetWidth(), self.PlotRect:GetHeight()) / 1.8 * GImPlot3D.Style.ViewScaleFactor
        end

        function Plot:GetBoxScale() return P(self.Axes[0]:NDCSize(), self.Axes[1]:NDCSize(), self.Axes[2]:NDCSize()) end

        -- Applies equal aspect ratio constraint using the specified axis as reference.
        function Plot:ApplyEqualAspect(ref_axis)
            local aspect = self.Axes[ref_axis]:GetAspect()
            for i = 0, 2 do
                if i ~= ref_axis and not self.Axes[i]:IsInputLocked() then self.Axes[i]:SetAspect(aspect) end
            end
        end

        function internal.GetCurrentPlot() return GImPlot3D.CurrentPlot end
        function internal.BustPlotCache() GImPlot3D.Plots:Clear() end
    end

    --------------------------------------------------------------------------
    -- [SECTION] Setup / Plot Utils (coordinate helpers)
    --------------------------------------------------------------------------
    do
        local P, Q = ImPlot3D.ImPlot3DPoint, ImPlot3D.ImPlot3DQuat
        local Cond, AxisFlags = ImPlot3D.ImPlot3DCond, ImPlot3D.ImPlot3DAxisFlags
        local ImHasFlag = internal.ImHasFlag
        local IM_PI = math.pi

        local function CurrentPlotForSetup(name)
            local gp = GImPlot3D
            IM_ASSERT(gp.CurrentPlot ~= nil and not gp.CurrentPlot.SetupLocked,
                name .. "() needs to be called after BeginPlot() and before any setup locking functions (e.g. PlotX)!")
            return gp.CurrentPlot
        end

        local ANIMATION_ANGULAR_VELOCITY = 2 * 3.1415
        function internal.CalcAnimationTime(q0, q1)
            -- Compute the angular distance between orientations
            local dot_product = math.clamp(q0:Dot(q1), -1.0, 1.0)
            return 2.0 * math.acos(math.abs(dot_product)) / ANIMATION_ANGULAR_VELOCITY
        end

        function ImPlot3D.SetupAxis(idx, label, flags)
            flags = flags or 0
            local axis = CurrentPlotForSetup("SetupAxis").Axes[idx]
            if axis.PreviousFlags ~= flags then axis.Flags = flags end
            axis.PreviousFlags = flags
            axis:SetLabel(label)
        end

        function ImPlot3D.SetupAxisLimits(idx, min_lim, max_lim, cond)
            cond = cond or Cond.Once
            local plot = CurrentPlotForSetup("SetupAxisLimits")
            local axis = plot.Axes[idx]
            if not plot.Initialized or cond == Cond.Always then
                axis:SetRange(min_lim, max_lim)
                axis.RangeCond = cond
                axis.FitThisFrame = false
                -- Apply equal aspect ratio constraint if needed
                if ImHasFlag(plot.Flags, ImPlot3D.ImPlot3DFlags.Equal) then plot:ApplyEqualAspect(idx) end
            end
        end

        function ImPlot3D.SetupAxisFormat(idx, formatter, data)
            local axis = CurrentPlotForSetup("SetupAxisFormat").Axes[idx]
            -- [Port] string formatter = printf format (C++ users pass Formatter_Default + fmt implicitly)
            if type(formatter) == "string" then formatter, data = internal.Formatter_Default, formatter end
            axis.Formatter = formatter
            axis.FormatterData = data
        end

        -- [Port] SetupAxisTicks(idx, values, n_ticks, labels, keep_default) / (idx, v_min, v_max, n_ticks, labels, keep_default)
        function ImPlot3D.SetupAxisTicks(idx, a, b, c, d, e)
            local values, n_ticks, labels, keep_default
            if type(a) == "table" then
                values, n_ticks, labels, keep_default = a, b or #a, c, d
            else
                n_ticks = math.max(c, 2)
                values = table.create(n_ticks)
                local step = (b - a) / (n_ticks - 1)
                for i = 0, n_ticks - 1 do values[i + 1] = a + i * step end -- FillRange
                labels, keep_default = d, e
            end
            local axis = CurrentPlotForSetup("SetupAxisTicks").Axes[idx]
            axis.ShowDefaultTicks = keep_default or false
            local fmt = axis.Formatter or internal.Formatter_Default
            local data = (axis.Formatter and axis.FormatterData) or internal.IMPLOT3D_LABEL_FORMAT
            internal.AddTicksCustom(values, labels, n_ticks, axis.Ticker, fmt, data)
        end

        function ImPlot3D.SetupAxes(x_label, y_label, z_label, x_flags, y_flags, z_flags)
            ImPlot3D.SetupAxis(0, x_label, x_flags)
            ImPlot3D.SetupAxis(1, y_label, y_flags)
            ImPlot3D.SetupAxis(2, z_label, z_flags)
        end

        function ImPlot3D.SetupAxesLimits(x_min, x_max, y_min, y_max, z_min, z_max, cond)
            cond = cond or Cond.Once
            ImPlot3D.SetupAxisLimits(0, x_min, x_max, cond)
            ImPlot3D.SetupAxisLimits(1, y_min, y_max, cond)
            ImPlot3D.SetupAxisLimits(2, z_min, z_max, cond)
            if cond == Cond.Once then GImPlot3D.CurrentPlot.FitThisFrame = false end
        end

        -- [Port] (elevation, azimuth [deg], animate, cond) / (quat, animate, cond) overloads
        function ImPlot3D.SetupBoxRotation(a, b, c, d)
            local rotation, animate, cond
            if type(a) == "number" then
                rotation, animate, cond = Q.FromElAz(a * IM_PI / 180.0, b * IM_PI / 180.0), c, d
            else
                rotation, animate, cond = a, b, c
            end
            cond = cond or Cond.Once
            local plot = CurrentPlotForSetup("SetupBoxRotation")
            if not plot.Initialized or cond == Cond.Always then
                if not animate then
                    plot.Rotation = rotation
                    plot.AnimationTime = 0.0 -- Force any running rotation animation to stop
                else
                    plot.RotationAnimationEnd = rotation
                    plot.AnimationTime = internal.CalcAnimationTime(plot.Rotation, plot.RotationAnimationEnd)
                end
                plot.RotationCond = cond
            end
        end

        -- [Port] (elevation, azimuth [deg]) / (quat) overloads
        function ImPlot3D.SetupBoxInitialRotation(a, b)
            local rotation = a
            if type(a) == "number" then rotation = Q.FromElAz(a * IM_PI / 180.0, b * IM_PI / 180.0) end
            CurrentPlotForSetup("SetupBoxInitialRotation").InitialRotation = rotation
        end

        function ImPlot3D.SetupBoxScale(x, y, z)
            local plot = CurrentPlotForSetup("SetupBoxScale")
            IM_ASSERT(x > 0.0 and y > 0.0 and z > 0.0, "SetupBoxScale() requires all aspect ratios to be greater than 0!")
            plot.Axes[0].NDCScale = x
            plot.Axes[1].NDCScale = y
            plot.Axes[2].NDCScale = z
        end

        function ImPlot3D.SetupLegend(location, flags)
            flags = flags or 0
            CurrentPlotForSetup("SetupLegend")
            local gp = GImPlot3D
            IM_ASSERT(gp.CurrentItems ~= nil, "SetupLegend() needs to be called within an itemized context!")
            local legend = gp.CurrentItems.Legend
            if legend.PreviousLocation ~= location then legend.Location = location end
            legend.PreviousLocation = location
            if legend.PreviousFlags ~= flags then legend.Flags = flags end
            legend.PreviousFlags = flags
        end

        -- Convert a position in the plot's NDC to pixels
        function internal.NDCToPixels(plot, point)
            local center = plot.PlotRect:GetCenter()
            local point_pix = plot:GetViewScale() * (plot.Rotation * point)
            return ImVec2(point_pix.x + center.x, -point_pix.y + center.y) -- Invert y-axis
        end

        -- Convert a position in the plot's coordinate system to NDC
        function internal.PlotToNDC(plot, point)
            local ndc = P(0, 0, 0)
            for i = 0, 2 do
                local axis = plot.Axes[i]
                local t = axis:PlotToNDC(point[i]) -- normalize to [0, 1]
                -- Convert to NDC range [-0.5*NDCScale, 0.5*NDCScale]
                ndc[i] = (if ImHasFlag(axis.Flags, AxisFlags.Invert) then 0.5 - t else t - 0.5) * axis.NDCScale
            end
            return ndc
        end

        -- [Port] body of upstream ImPlot3D::NDCToPlot, split out so it works on an explicit plot
        function internal.NDCToPlot(plot, point)
            local out = P(0, 0, 0)
            for i = 0, 2 do
                local axis = plot.Axes[i]
                local ndc_range = 0.5 * axis.NDCScale
                local t = if ImHasFlag(axis.Flags, AxisFlags.Invert) then ndc_range - point[i] else point[i] + ndc_range
                out[i] = axis:NDCToPlot(t / axis.NDCScale)
            end
            return out
        end

        function internal.PlotToPixels(plot, point) return internal.NDCToPixels(plot, internal.PlotToNDC(plot, point)) end

        local function CurrentPlot(name)
            local gp = GImPlot3D
            IM_ASSERT(gp.CurrentPlot ~= nil, name .. "() needs to be called between BeginPlot() and EndPlot()!")
            ImPlot3D.SetupLock()
            return gp.CurrentPlot
        end

        local MOUSE_CURSOR_DRAG_THRESHOLD = 5.0
        local axis_contexts = { [0] = "##XAxisContext", "##YAxisContext", "##ZAxisContext" }
        local plane_contexts = { [0] = "##YZPlaneContext", "##XZPlaneContext", "##XYPlaneContext" }
        internal.axis_contexts, internal.plane_contexts = axis_contexts, plane_contexts
        -- Map edge index to the two faces it belongs to, and corresponding plane: {face_index, plane}
        local edge_to_faces = {
            [0] = { { 1, 1 }, { 2, 2 } }, { { 2, 2 }, { 3, 0 } }, { { 2, 2 }, { 4, 1 } }, { { 0, 0 }, { 2, 2 } },
            { { 1, 1 }, { 5, 2 } }, { { 3, 0 }, { 5, 2 } }, { { 4, 1 }, { 5, 2 } }, { { 0, 0 }, { 5, 2 } },
            { { 0, 0 }, { 1, 1 } }, { { 1, 1 }, { 3, 0 } }, { { 3, 0 }, { 4, 1 } }, { { 0, 0 }, { 4, 1 } },
        }

        -- [Port] translates plot.Axes[i] along the interaction plane by reprojecting its range extremes (pan) or
        -- scaling them around the mouse (zoom); shared body of upstream's two identical inline blocks
        local function ReprojectRange(plot, i, mouse_pos_plot, mouse_plane, f)
            local axis = plot.Axes[i]
            local p_min, p_max = mouse_pos_plot:Copy(), mouse_pos_plot:Copy()
            p_min[i], p_max[i] = axis.Range.Min, axis.Range.Max
            local pix_min, pix_max = f(internal.PlotToPixels(plot, p_min), internal.PlotToPixels(plot, p_max))
            return ImPlot3D.PixelsToPlotPlane(pix_min, mouse_plane, false)[i], ImPlot3D.PixelsToPlotPlane(pix_max, mouse_plane, false)[i]
        end

        -- [Port] ROTATION part of upstream HandleInput, split out for size
        function internal.HandleInputRotation(plot, hovered_plane, active_faces, allow_rotate)
            local MB = G.ImGuiMouseButton
            -- Handle reset rotation with right mouse double click (animate to face the hovered plane)
            if plot.Held and ImGui.IsMouseDoubleClicked(MB.Right) and not plot:IsRotationLocked() and allow_rotate then
                local rot_end = plot.Rotation
                if hovered_plane == -1 then
                    rot_end = plot.InitialRotation
                else
                    -- Compute plane normal
                    local axis_normal = P(0, 0, 0)
                    axis_normal[hovered_plane] = if active_faces[hovered_plane] == 1 then -1.0 else 1.0
                    if ImHasFlag(plot.Axes[hovered_plane].Flags, AxisFlags.Invert) then axis_normal[hovered_plane] *= -1 end
                    -- Compute rotation to align the plane normal with the z-axis
                    rot_end = Q.FromTwoVectors(rot_end * axis_normal, P(0, 0, 1)) * rot_end
                    if hovered_plane ~= 2 then
                        -- Compute rotation to point z-axis up
                        rot_end = Q.FromTwoVectors(rot_end * P(0, 0, 1), P(0, 1, 0)) * rot_end
                    else
                        -- Find the axis most aligned with the up direction
                        local up = P(0, 1, 0)
                        local best, best_dot = nil, -math.huge
                        for _, v in { P(1, 0, 0), P(0, 1, 0), P(-1, 0, 0), P(0, -1, 0) } do
                            local a = rot_end * v
                            local d = a:Dot(up)
                            if d > best_dot then best, best_dot = a, d end
                        end
                        rot_end = Q.FromTwoVectors(best, up) * rot_end
                    end
                end
                plot.RotationAnimationEnd = rot_end
                plot.AnimationTime = internal.CalcAnimationTime(plot.Rotation, plot.RotationAnimationEnd)
            end
            -- Handle rotation with right mouse dragging
            if plot.Held and ImGui.IsMouseDown(MB.Right) and not plot:IsRotationLocked() and allow_rotate then
                local delta = ImGui.GetIO().MouseDelta
                -- Map delta to rotation angles (in radians)
                local angle_x, angle_y = delta.x * (3.1415 / 180.0), delta.y * (3.1415 / 180.0)
                -- If drag just started, determine and store the rotation axis
                if plot.DragRotationAxis == P(0, 0, 0) then
                    local is_upside_down = (plot.Rotation * P(0, 0, 1)).z < 0.0
                    plot.DragRotationAxis = if is_upside_down then P(0, 0, -1) else P(0, 0, 1)
                end
                plot.Rotation = Q(angle_y, P(1, 0, 0)) * plot.Rotation * Q(angle_x, plot.DragRotationAxis)
                plot.Rotation:Normalize()
            else
                -- Reset drag rotation axis when not dragging
                plot.DragRotationAxis = P(0, 0, 0)
            end
        end

        function internal.HandleInput(plot)
            local Flags, MB = ImPlot3D.ImPlot3DFlags, G.ImGuiMouseButton
            if ImHasFlag(plot.Flags, Flags.NoInputs) then return end
            local IO = ImGui.GetIO()
            local BF = G.ImGuiButtonFlags
            local plot_button_flags = bit32.bor(BF.AllowOverlap, BF.PressedOnClick, BF.PressedOnDoubleClick, BF.MouseButtonLeft,
                BF.MouseButtonRight, BF.MouseButtonMiddle)
            local plot_clicked
            plot_clicked, plot.Hovered, plot.Held = ImGui.ButtonBehavior(plot.PlotRect, plot.ID, plot_button_flags)
            -- State
            local rot_drag = ImGui.GetMouseDragDelta(MB.Right)
            local rotating = rot_drag.x * rot_drag.x + rot_drag.y * rot_drag.y > MOUSE_CURSOR_DRAG_THRESHOLD
            local axis_equal = ImHasFlag(plot.Flags, Flags.Equal)
            local allow_rotate = not ImHasFlag(plot.Flags, Flags.NoRotate)
            local allow_pan = not ImHasFlag(plot.Flags, Flags.NoPan)
            local allow_zoom = not ImHasFlag(plot.Flags, Flags.NoZoom)
            local A = plot.Axes

            -- HOVERING STATE
            local active_faces, corners_pix, _, plane_2d, axis_corners = internal.GetAxesParameters(plot)
            local hovered_plane = internal.GetMouseOverPlane(active_faces, corners_pix)
            local hovered_plane_idx = hovered_plane
            local hovered_axis, hovered_edge_idx = internal.GetMouseOverAxis(plot, corners_pix, plane_2d, axis_corners)
            if hovered_axis ~= -1 then hovered_plane_idx, hovered_plane = -1, -1 end
            -- If the user is no longer pressing the translation/zoom buttons, set axes as not held
            if not ImGui.IsMouseDown(MB.Left) and not ImGui.IsMouseDown(MB.Middle) then
                for i = 0, 2 do A[i].Held = false end
            end
            -- Reset held edge/plane indices (it will be set if mouse button is down)
            if not plot.Held then plot.HeldEdgeIdx, plot.HeldPlaneIdx = -1, -1 end
            -- Check which axes should be transformed (fit/zoom/translate)
            local any_axis_held = A[0].Held or A[1].Held or A[2].Held
            if not any_axis_held then
                -- Only update the transformation axes if the user is not already performing a transformation
                for i = 0, 2 do
                    A[i].Hovered = if hovered_axis ~= -1 then i == hovered_axis elseif hovered_plane ~= -1 then i ~= hovered_plane else true
                end
            end
            -- Compute plane that is being hovered by mouse
            local mouse_plane = 2
            if plane_2d ~= -1 then
                mouse_plane = plane_2d
            elseif A[1].Hovered and A[2].Hovered then
                mouse_plane = 0
            elseif A[0].Hovered and A[2].Hovered then
                mouse_plane = 1
            elseif A[0].Hovered and A[1].Hovered then
                mouse_plane = 2
            elseif plot.HeldEdgeIdx ~= -1 or hovered_edge_idx ~= -1 then
                -- Single axis hovered: pick the visible (active) face of the two faces sharing the edge
                local ef = edge_to_faces[if plot.HeldEdgeIdx ~= -1 then plot.HeldEdgeIdx else hovered_edge_idx]
                local function face_active(f) return if f < 3 then active_faces[f] == 0 else active_faces[f - 3] == 1 end
                mouse_plane = if not face_active(ef[1][1]) and face_active(ef[2][1]) then ef[2][2] else ef[1][2]
            end
            local mouse_pos = ImGui.GetMousePos()
            local mouse_pos_plot = ImPlot3D.PixelsToPlotPlane(mouse_pos, mouse_plane, false)
            local function SetHeldIndices()
                if not any_axis_held then plot.HeldEdgeIdx, plot.HeldPlaneIdx = hovered_edge_idx, hovered_plane_idx end
            end

            -- AUTO FIT: translation/zoom fit with double click
            if plot_clicked and (ImGui.IsMouseDoubleClicked(MB.Left) or ImGui.IsMouseDoubleClicked(MB.Middle)) and allow_pan and allow_zoom then
                plot.FitThisFrame = true
                for i = 0, 2 do A[i].FitThisFrame = A[i].Hovered end
            end
            -- Handle auto fit
            for i = 0, 2 do
                if A[i]:IsAutoFitting() then
                    plot.FitThisFrame = true
                    A[i].FitThisFrame = true
                end
            end

            -- TRANSLATION with left mouse button
            if plot.Held and ImGui.IsMouseDown(MB.Left) and allow_pan then
                local delta = IO.MouseDelta
                if A[0].Hovered and A[1].Hovered and A[2].Hovered then
                    -- Unconstrained translation on the viewer's plane
                    local delta_NDC = plot.Rotation:Inverse() * (P(delta.x, -delta.y, 0.0) / plot:GetViewScale())
                    local p_min_ndc, p_max_ndc = P(0, 0, 0), P(0, 0, 0)
                    for i = 0, 2 do
                        local half_scale = 0.5 * A[i].NDCScale
                        p_min_ndc[i] = -half_scale - delta_NDC[i]
                        p_max_ndc[i] = half_scale - delta_NDC[i]
                    end
                    local p_min_plt, p_max_plt = internal.NDCToPlot(plot, p_min_ndc), internal.NDCToPlot(plot, p_max_ndc)
                    for i = 0, 2 do
                        local axis = A[i]
                        local new_min, new_max = math.min(p_min_plt[i], p_max_plt[i]), math.max(p_min_plt[i], p_max_plt[i])
                        local increasing = new_min > axis.Range.Min
                        if (new_min ~= axis.Range.Min or new_max ~= axis.Range.Max) and not axis:IsPanLocked(increasing) then
                            axis:SetRange(new_min, new_max)
                            if axis_equal then plot:ApplyEqualAspect(i) end
                        end
                        axis.Held = true
                    end
                    SetHeldIndices()
                elseif A[0].Hovered or A[1].Hovered or A[2].Hovered then
                    -- Translate along plane/axis
                    for i = 0, 2 do
                        local axis = A[i]
                        if axis.Hovered then
                            local new_min, new_max = ReprojectRange(plot, i, mouse_pos_plot, mouse_plane, function(a, b)
                                return a - delta, b - delta
                            end)
                            local increasing = new_min < axis.Range.Min
                            if (new_min ~= axis.Range.Min or new_max ~= axis.Range.Max) and not axis:IsPanLocked(increasing) then
                                axis:SetRange(new_min, new_max)
                                if axis_equal then plot:ApplyEqualAspect(i) end
                            end
                            axis.Held = true
                        end
                    end
                    SetHeldIndices()
                end
            end

            -- ROTATION
            internal.HandleInputRotation(plot, hovered_plane, active_faces, allow_rotate)

            -- ZOOM with mouse wheel / middle drag
            if plot.Hovered and allow_zoom then
                ImGui.SetKeyOwner(G.ImGuiKey.MouseWheelY, plot.ID)
                if ImGui.IsMouseDown(MB.Middle) or IO.MouseWheel ~= 0.0 then
                    local zoom_rate = if ImGui.IsMouseDown(MB.Middle) then -0.01 * IO.MouseDelta.y else -0.1 * IO.MouseWheel
                    local zoom_around_mouse = hovered_axis ~= -1 or hovered_plane ~= -1
                    local ref_axis = 0
                    for i = 0, 2 do
                        local axis = A[i]
                        if axis.Hovered and not axis:IsInputLocked() then
                            local mouse_pix = internal.PlotToPixels(plot, mouse_pos_plot)
                            local dmin, dmax
                            local new_min, new_max = ReprojectRange(plot, i, mouse_pos_plot, mouse_plane, function(a, b)
                                dmin, dmax = a - mouse_pix, b - mouse_pix
                                return mouse_pix + dmin * (1.0 + zoom_rate), mouse_pix + dmax * (1.0 + zoom_rate)
                            end)
                            local moved = dmin.x ~= 0 or dmin.y ~= 0 or dmax.x ~= 0 or dmax.y ~= 0
                            if zoom_around_mouse and moved then
                                axis:SetRange(new_min, new_max)
                            else
                                -- Zoom around center
                                local ndc_limit = 0.5 * axis.NDCScale * (1.0 + zoom_rate)
                                local ndc_min, ndc_max = P(0, 0, 0), P(0, 0, 0)
                                ndc_min[i], ndc_max[i] = -ndc_limit, ndc_limit
                                axis:SetRange(internal.NDCToPlot(plot, ndc_min)[i], internal.NDCToPlot(plot, ndc_max)[i])
                            end
                            axis.Held = true
                            ref_axis = i
                        end
                    end
                    if axis_equal then plot:ApplyEqualAspect(ref_axis) end
                    SetHeldIndices()
                end
            end

            -- CONTEXT MENU with right mouse button
            if plot.Held and ImGui.IsMouseClicked(MB.Right) and not ImHasFlag(plot.Flags, Flags.NoMenus) then plot.ContextClick = true end
            if rotating or (ImGui.IsMouseDoubleClicked(MB.Right) and allow_rotate) then plot.ContextClick = false end
            -- Should not happen if it is a double click action
            local not_double_click = not allow_rotate or (ImGui.GetTime() - IO.MouseClickedTime[MB.Right]) > IO.MouseDoubleClickTime
            if plot.Hovered and plot.ContextClick and not_double_click and not ImGui.IsMouseDown(MB.Right) then
                plot.ContextClick = false
                plot.OpenContextThisFrame = true
            end
            if plot.OpenContextThisFrame then
                if plot.Items.Legend.Hovered then
                    ImGui.OpenPopup("##LegendContext")
                elseif hovered_axis ~= -1 then
                    ImGui.OpenPopup(axis_contexts[hovered_axis])
                elseif hovered_plane ~= -1 then
                    ImGui.OpenPopup(plane_contexts[hovered_plane])
                elseif plot.Hovered then
                    ImGui.OpenPopup("##PlotContext")
                end
            end
        end

        local axis_labels = { [0] = "X-Axis", "Y-Axis", "Z-Axis" }
        local plane_labels = { [0] = "YZ-Plane", "XZ-Plane", "XY-Plane" }
        local short_legend_location = { [0] = "C", [1] = "N", [2] = "S", [4] = "W", [8] = "E", [5] = "NW", [9] = "NE", [6] = "SW", [10] = "SE" }
        function internal.GetShortLegendLocationName(loc) return short_legend_location[loc] end

        -- [Port] returns true when "Show" toggled (visible passed by value)
        function internal.ShowLegendContextMenu(legend, visible)
            local Loc, LF = ImPlot3D.ImPlot3DLocation, ImPlot3D.ImPlot3DLegendFlags
            local s = ImGui.GetFrameHeight()
            local ret = ImGui.Checkbox("Show", visible)
            local horiz = ImHasFlag(legend.Flags, LF.Horizontal)
            if ImGui.RadioButton("H", horiz) then legend.Flags = bit32.bor(legend.Flags, LF.Horizontal) end
            ImGui.SameLine()
            if ImGui.RadioButton("V", not horiz) then legend.Flags = bit32.band(legend.Flags, bit32.bnot(LF.Horizontal)) end
            ImGui.PushStyleVar(G.ImGuiStyleVar.ItemSpacing, ImVec2(2, 2))
            local size = ImVec2(1.5 * s, s)
            local rows = { { Loc.NorthWest, Loc.North, Loc.NorthEast }, { Loc.West, Loc.Center, Loc.East }, { Loc.SouthWest, Loc.South, Loc.SouthEast } }
            for _, row in rows do
                for j, loc in row do
                    if loc == Loc.Center then
                        ImGui.InvisibleButton(short_legend_location[loc], size)
                    elseif ImGui.Button(short_legend_location[loc], size) then
                        legend.Location = loc
                    end
                    if j < 3 then ImGui.SameLine() end
                end
            end
            ImGui.PopStyleVar()
            return ret
        end

        local function FlipFlag(t, k, flag) t[k] = bit32.bxor(t[k], flag) end

        function internal.ShowAxisContextMenu(plot, axis_id)
            ImGui.PushItemWidth(75)
            local axis = plot.Axes[axis_id]
            local always_locked = axis:IsRangeLocked() or axis:IsAutoFitting()
            local size = axis.Range:Size()
            local drag_speed = if size <= 2.220446049250313e-16 then 2.220446049250313e-16 * 1.0e+13 else 0.01 * size -- Recover from almost equal axis limits
            local equal_aspect = ImHasFlag(plot.Flags, ImPlot3D.ImPlot3DFlags.Equal)
            local Double = G.ImGuiDataType.Double

            ImGui.BeginDisabled(always_locked)
            local _, fl = ImGui.CheckboxFlags("##LockMin", axis.Flags, AxisFlags.LockMin); axis.Flags = fl
            ImGui.EndDisabled()
            ImGui.SameLine()
            ImGui.BeginDisabled(axis:IsLockedMin() or always_locked)
            local v, changed = ImGui.DragScalar("Min", Double, axis.Range.Min, drag_speed, axis.ConstraintRange.Min, axis.Range.Max)
            if changed then
                axis:SetMin(v, true)
                if equal_aspect then plot:ApplyEqualAspect(axis_id) end
            end
            ImGui.EndDisabled()

            ImGui.BeginDisabled(always_locked)
            _, fl = ImGui.CheckboxFlags("##LockMax", axis.Flags, AxisFlags.LockMax); axis.Flags = fl
            ImGui.EndDisabled()
            ImGui.SameLine()
            ImGui.BeginDisabled(axis:IsLockedMax() or always_locked)
            v, changed = ImGui.DragScalar("Max", Double, axis.Range.Max, drag_speed, axis.Range.Min, axis.ConstraintRange.Max)
            if changed then
                axis:SetMax(v, true)
                if equal_aspect then plot:ApplyEqualAspect(axis_id) end
            end
            ImGui.EndDisabled()
            ImGui.Separator()

            _, fl = ImGui.CheckboxFlags("Auto-Fit", axis.Flags, AxisFlags.AutoFit); axis.Flags = fl
            ImGui.Separator()
            if ImGui.Checkbox("Invert", ImHasFlag(axis.Flags, AxisFlags.Invert)) then FlipFlag(axis, "Flags", AxisFlags.Invert) end
            ImGui.Separator()
            ImGui.BeginDisabled(axis.Label == "")
            if ImGui.Checkbox("Label", axis:HasLabel()) then FlipFlag(axis, "Flags", AxisFlags.NoLabel) end
            ImGui.EndDisabled()
            if ImGui.Checkbox("Grid Lines", axis:HasGridLines()) then FlipFlag(axis, "Flags", AxisFlags.NoGridLines) end
            if ImGui.Checkbox("Tick Marks", axis:HasTickMarks()) then FlipFlag(axis, "Flags", AxisFlags.NoTickMarks) end
            if ImGui.Checkbox("Tick Labels", axis:HasTickLabels()) then FlipFlag(axis, "Flags", AxisFlags.NoTickLabels) end
            ImGui.PopItemWidth() -- [Port] upstream leaks this PushItemWidth
        end

        local function AxisMenus(plot, skip)
            for i = 0, 2 do
                if i ~= skip then
                    local axis = plot.Axes[i]
                    ImGui.PushID(i)
                    if ImGui.BeginMenu(if axis:HasLabel() then axis:GetLabel() else axis_labels[i]) then
                        internal.ShowAxisContextMenu(plot, i)
                        ImGui.EndMenu()
                    end
                    ImGui.PopID()
                end
            end
        end

        function internal.ShowPlaneContextMenu(plot, plane_idx) AxisMenus(plot, plane_idx) end

        function internal.ShowPlotContextMenu(plot)
            local Flags = ImPlot3D.ImPlot3DFlags
            AxisMenus(plot, -1)
            ImGui.Separator()
            if ImGui.BeginMenu("Box") then
                ImGui.PushItemWidth(75)
                for i, name in { [0] = "Scale X", "Scale Y", "Scale Z" } do
                    local v, changed = ImGui.DragFloat(name, plot.Axes[i].NDCScale, 0.01, 0.1, 3.0)
                    if changed then plot.Axes[i].NDCScale = math.max(v, 0.01) end
                end
                ImGui.PopItemWidth()
                ImGui.EndMenu()
            end
            ImGui.Separator()
            if ImGui.BeginMenu("Legend") then
                if internal.ShowLegendContextMenu(plot.Items.Legend, not ImHasFlag(plot.Flags, Flags.NoLegend)) then FlipFlag(plot, "Flags", Flags.NoLegend) end
                ImGui.EndMenu()
            end
            if ImGui.BeginMenu("Settings") then
                if ImGui.MenuItem("Equal", nil, ImHasFlag(plot.Flags, Flags.Equal)) then FlipFlag(plot, "Flags", Flags.Equal) end
                ImGui.BeginDisabled(plot.Title == "")
                if ImGui.MenuItem("Title", nil, plot:HasTitle()) then FlipFlag(plot, "Flags", Flags.NoTitle) end
                ImGui.EndDisabled()
                if ImGui.MenuItem("Clip", nil, not ImHasFlag(plot.Flags, Flags.NoClip)) then FlipFlag(plot, "Flags", Flags.NoClip) end
                if ImGui.MenuItem("Mouse Position", nil, not ImHasFlag(plot.Flags, Flags.NoMouseText)) then FlipFlag(plot, "Flags", Flags.NoMouseText) end
                ImGui.EndMenu()
            end
        end

        -- [Port] EndPlot's mouse text + context menu popups
        function internal.ShowPlotPopups(plot)
            local Flags = ImPlot3D.ImPlot3DFlags
            internal.RenderMousePos()
            if ImGui.BeginPopup("##LegendContext") then
                ImGui.Text("Legend")
                ImGui.Separator()
                if internal.ShowLegendContextMenu(plot.Items.Legend, not ImHasFlag(plot.Flags, Flags.NoLegend)) then FlipFlag(plot, "Flags", Flags.NoLegend) end
                ImGui.EndPopup()
            end
            for i = 0, 2 do
                local axis = plot.Axes[i]
                if ImGui.BeginPopup(axis_contexts[i]) then
                    ImGui.TextUnformatted(if axis:HasLabel() then axis:GetLabel() else axis_labels[i])
                    ImGui.Separator()
                    internal.ShowAxisContextMenu(plot, i)
                    ImGui.EndPopup()
                end
            end
            for i = 0, 2 do
                if ImGui.BeginPopup(plane_contexts[i]) then
                    ImGui.Text(plane_labels[i])
                    ImGui.Separator()
                    internal.ShowPlaneContextMenu(plot, i)
                    ImGui.EndPopup()
                end
            end
            if ImGui.BeginPopup("##PlotContext") then
                internal.ShowPlotContextMenu(plot)
                ImGui.EndPopup()
            end
        end

        function ImPlot3D.SetupLock()
            local gp = GImPlot3D
            IM_ASSERT(gp.CurrentPlot ~= nil, "SetupLock() needs to be called between BeginPlot() and EndPlot()!")
            local plot = gp.CurrentPlot
            if plot.SetupLocked then return end
            plot.SetupLocked = true
            local draw_list = ImGui.GetWindowDrawList()
            -- Set default formatter/locator
            for i = 0, 2 do
                local axis = plot.Axes[i]
                if axis.Formatter == nil then
                    axis.Formatter = internal.Formatter_Default
                    if axis.FormatterData == nil then axis.FormatterData = internal.IMPLOT3D_LABEL_FORMAT end
                end
                if axis.Locator == nil then axis.Locator = internal.Locator_Default end
            end
            -- Draw frame background
            draw_list:AddRectFilled(plot.FrameRect.Min, plot.FrameRect.Max, ImPlot3D.GetStyleColorU32(ImPlot3D.ImPlot3DCol.FrameBg))
            -- Compute canvas/plot rectangle
            local pad = gp.Style.PlotPadding
            plot.CanvasRect = G.ImRect(plot.FrameRect.Min + pad, plot.FrameRect.Max - pad)
            plot.PlotRect = G.ImRect(plot.CanvasRect.Min, plot.CanvasRect.Max)
            -- Apply equal axis aspect constraint if not approximately equal
            if ImHasFlag(plot.Flags, ImPlot3D.ImPlot3DFlags.Equal) then
                local xar, yar, zar = plot.Axes[0]:GetAspect(), plot.Axes[1]:GetAspect(), plot.Axes[2]:GetAspect()
                if not internal.ImAlmostEqual(xar, yar) or not internal.ImAlmostEqual(xar, zar) then
                    local aspect = (xar + yar + zar) / 3.0
                    for i = 0, 2 do plot.Axes[i]:SetAspect(aspect) end
                end
            end
            -- Compute ticks
            for i = 0, 2 do
                local axis = plot.Axes[i]
                if axis.ShowDefaultTicks then
                    axis.Locator(axis.Ticker, axis.Range, plot:GetViewScale() * axis.NDCScale, axis.Formatter, axis.FormatterData)
                end
            end
            -- Cache axis colors
            for i = 0, 2 do
                local axis = plot.Axes[i]
                axis.ColorBg = ImPlot3D.GetStyleColorU32(ImPlot3D.ImPlot3DCol.AxisBg)
                axis.ColorHov = ImPlot3D.GetStyleColorU32(ImPlot3D.ImPlot3DCol.AxisBgHovered)
                axis.ColorAct = ImPlot3D.GetStyleColorU32(ImPlot3D.ImPlot3DCol.AxisBgActive)
            end
            -- Render title
            if plot:HasTitle() then
                local col = ImPlot3D.GetStyleColorU32(ImPlot3D.ImPlot3DCol.TitleText)
                internal.AddTextCentered(draw_list, ImVec2(plot.FrameRect:GetCenter().x, plot.CanvasRect.Min.y), col, plot:GetTitle())
                plot.PlotRect.Min.y += ImGui.GetTextLineHeight() + gp.Style.LabelPadding.y
            end
            -- Handle animation
            if plot.AnimationTime > 0.0 then
                local dt = ImGui.GetIO().DeltaTime
                local t = math.clamp(dt / plot.AnimationTime, 0.0, 1.0)
                plot.AnimationTime = math.max(plot.AnimationTime - dt, 0.0)
                plot.Rotation = Q.Slerp(plot.Rotation, plot.RotationAnimationEnd, t)
            end
            plot.Initialized = true
            -- Handle user input
            internal.HandleInput(plot)
            -- Push plot rect clipping
            ImGui.PushClipRect(plot.PlotRect.Min, plot.PlotRect.Max, true)
            -- Render plot box
            internal.RenderPlotBox(draw_list, plot)
        end

        function ImPlot3D.PlotToNDC(point) return internal.PlotToNDC(CurrentPlot("PlotToNDC"), point) end
        function ImPlot3D.NDCToPlot(point) return internal.NDCToPlot(CurrentPlot("NDCToPlot"), point) end
        function ImPlot3D.NDCToPixels(point) return internal.NDCToPixels(CurrentPlot("NDCToPixels"), point) end
        -- [Port] (point) / (x, y, z) overloads
        function ImPlot3D.PlotToPixels(x, y, z)
            if type(x) == "number" then x = P(x, y, z) end
            return ImPlot3D.NDCToPixels(ImPlot3D.PlotToNDC(x))
        end

        function ImPlot3D.PixelsToNDCRay(pix)
            local plot = CurrentPlot("PixelsToNDCRay")
            -- Undo screen transformations to get back to NDC space
            local zoom, center = plot:GetViewScale(), plot.PlotRect:GetCenter()
            local x = (pix.x - center.x) / zoom
            local y = -(pix.y - center.y) / zoom -- Invert y-axis
            local inv = plot.Rotation:Inverse()
            local ndc_near, ndc_far = inv * P(x, y, 10.0), inv * P(x, y, -10.0)
            return ImPlot3D.ImPlot3DRay(ndc_near, (ndc_far - ndc_near):Normalized())
        end

        function ImPlot3D.NDCRayToPlotRay(ray)
            local plot = CurrentPlot("NDCRayToPlotRay")
            local plot_origin = internal.NDCToPlot(plot, ray.Origin)
            local plot_along = internal.NDCToPlot(plot, ray.Origin + ray.Direction)
            return ImPlot3D.ImPlot3DRay(plot_origin, (plot_along - plot_origin):Normalized())
        end

        -- [Port] (pix) / (x, y) overloads
        function ImPlot3D.PixelsToPlotRay(x, y)
            if type(x) == "number" then x = ImVec2(x, y) end
            return ImPlot3D.NDCRayToPlotRay(ImPlot3D.PixelsToNDCRay(x))
        end

        -- [Port] (pix, plane, mask) / (x, y, plane, mask) overloads
        function ImPlot3D.PixelsToPlotPlane(pix, plane, mask, mask2)
            if type(pix) == "number" then pix, plane, mask = ImVec2(pix, plane), mask, mask2 end
            local plot = CurrentPlot("PixelsToPlotPlane")
            local ray = ImPlot3D.PixelsToNDCRay(pix)
            local O, D = ray.Origin, ray.Direction
            local NAN = 0 / 0
            -- Compute which plane to intersect with
            local active_faces = internal.ComputeActiveFaces(plot.Rotation, plot.Axes)
            local half = 0.5 * plot.Axes[plane].NDCScale
            local coord = if active_faces[plane] == 1 then half else -half
            -- Solve for t in O[plane] + D[plane]*t = coord
            local denom = D[plane]
            if math.abs(denom) < 1e-12 then return P(NAN, NAN, NAN) end -- Ray is parallel to the plane
            local t = (coord - O[plane]) / denom
            if t < 0.0 then return P(NAN, NAN, NAN) end -- Intersection behind the ray origin
            local p = O + D * t
            -- Handle mask (if the intersection is out of the plot box, return NAN)
            if mask then
                local box_scale = plot:GetBoxScale()
                for i = 0, 2 do
                    if i ~= plane and (p[i] < -0.5 * box_scale[i] or p[i] > 0.5 * box_scale[i]) then return P(NAN, NAN, NAN) end
                end
            end
            return internal.NDCToPlot(plot, p)
        end
    end

    --------------------------------------------------------------------------
    -- [SECTION] Text Utils
    --------------------------------------------------------------------------
    do
        -- [Port] text_end dropped: Luau strings carry their length
        function internal.AddTextRotated(draw_list, pos, angle, col, text)
            local g = ImGui.GetCurrentContext()
            local font_baked = ImGui.GetFontBaked()
            local scale = g.FontSize / font_baked.Size
            -- Align to be pixel perfect
            pos = ImVec2(math.floor(pos.x), math.floor(pos.y))
            -- Measure the size of the text in unrotated coordinates
            local text_size = ImGui.CalcTextSize(text)
            -- Precompute sine and cosine of the angle (note: angle should be positive for rotation in ImGui)
            local cos_a, sin_a = math.cos(-angle), math.sin(-angle)
            -- [Port] ponytail: per-glyph PrimReserve instead of reserve-all + PrimUnreserve
            -- Adjust pen position to center the text
            local pen_x, pen_y = -text_size.x * 0.5, -text_size.y * 0.5
            do -- [Port] utf8.codes() raises on malformed UTF-8 (upstream breaks out of the loop)
                for _, c in utf8.codes(text) do
                    local glyph = font_baked:FindGlyph(c)
                    if glyph ~= nil then
                        -- Glyph quad corners in unrotated space, then rotate and translate
                        local x0, y0 = pen_x + glyph.X0 * scale, pen_y + glyph.Y0 * scale
                        local x1, y1 = pen_x + glyph.X1 * scale, pen_y + glyph.Y1 * scale
                        local function R(x, y) return ImVec2(x * cos_a - y * sin_a + pos.x, x * sin_a + y * cos_a + pos.y) end
                        draw_list:PrimReserve(6, 4)
                        draw_list:PrimQuadUV(R(x0, y0), R(x1, y0), R(x1, y1), R(x0, y1),
                            ImVec2(glyph.U0, glyph.V0), ImVec2(glyph.U1, glyph.V0), ImVec2(glyph.U1, glyph.V1), ImVec2(glyph.U0, glyph.V1), col)
                        -- Advance the pen position
                        pen_x += glyph.AdvanceX * scale
                    end
                end
            end
        end

        function internal.AddTextCentered(draw_list, top_center, col, text)
            local text_end = ImGui.FindRenderedTextEnd(text)
            local text_size = ImGui.CalcTextSize(text, text_end, true)
            draw_list:AddText(ImVec2(top_center.x - text_size.x * 0.5, top_center.y), col, text, text_end)
        end
    end

    --------------------------------------------------------------------------
    -- [SECTION] Plot Box Utils
    -- [Port] lookup tables keep upstream's 0-based corner/edge/face indices; rows are 1-based Luau arrays
    --------------------------------------------------------------------------
    do
        local P = ImPlot3D.ImPlot3DPoint
        local ImHasFlag = internal.ImHasFlag

        -- Faces of the box (defined by 4 corner indices)
        local faces = {
            [0] = { 0, 3, 7, 4 }, -- X-min face
            { 0, 4, 5, 1 }, -- Y-min face
            { 0, 1, 2, 3 }, -- Z-min face
            { 1, 2, 6, 5 }, -- X-max face
            { 3, 7, 6, 2 }, -- Y-max face
            { 4, 5, 6, 7 }, -- Z-max face
        }
        -- Edges of the box (defined by 2 corner indices)
        local edges = {
            [0] = { 0, 1 }, { 1, 2 }, { 2, 3 }, { 3, 0 }, -- Bottom face edges
            { 4, 5 }, { 5, 6 }, { 6, 7 }, { 7, 4 }, -- Top face edges
            { 0, 4 }, { 1, 5 }, { 2, 6 }, { 3, 7 }, -- Vertical edges
        }
        -- Face edges (4 edge indices for each face)
        local face_edges = {
            [0] = { 3, 11, 8, 7 }, -- X-min face
            { 0, 8, 4, 9 }, -- Y-min face
            { 0, 1, 2, 3 }, -- Z-min face
            { 1, 9, 5, 10 }, -- X-max face
            { 2, 10, 6, 11 }, -- Y-max face
            { 4, 5, 6, 7 }, -- Z-max face
        }
        -- Lookup table for axis_corners based on active_faces (3D plot)
        local axis_corners_lookup_3d = {
            [0] = { [0] = { 3, 2 }, { 1, 2 }, { 1, 5 } }, -- {0, 0, 0}
            { [0] = { 7, 6 }, { 5, 6 }, { 1, 5 } }, -- {0, 0, 1}
            { [0] = { 0, 1 }, { 1, 2 }, { 2, 6 } }, -- {0, 1, 0}
            { [0] = { 4, 5 }, { 5, 6 }, { 2, 6 } }, -- {0, 1, 1}
            { [0] = { 3, 2 }, { 0, 3 }, { 0, 4 } }, -- {1, 0, 0}
            { [0] = { 7, 6 }, { 4, 7 }, { 0, 4 } }, -- {1, 0, 1}
            { [0] = { 0, 1 }, { 0, 3 }, { 3, 7 } }, -- {1, 1, 0}
            { [0] = { 4, 5 }, { 4, 7 }, { 3, 7 } }, -- {1, 1, 1}
        }
        internal.box_faces, internal.box_edges, internal.box_face_edges = faces, edges, face_edges

        -- [Port] active_faces is a 0-based array of 0/1 ints (C++ bool used as index)
        function internal.Active3DFacesToAxisLookupIndex(active_faces)
            return active_faces[0] * 4 + active_faces[1] * 2 + active_faces[2]
        end

        function internal.ComputeEdgeOutwardDir(p0, p1, box_center)
            local dir = p1 - p0
            local len = math.sqrt(dir.x * dir.x + dir.y * dir.y)
            if len < 0.001 then return ImVec2(0, 0) end
            dir = ImVec2(dir.x / len, dir.y / len)
            -- Perpendicular direction, pointing away from box center
            local perp = ImVec2(-dir.y, dir.x)
            local to_edge = (p0 + p1) * 0.5 - box_center
            if perp.x * to_edge.x + perp.y * to_edge.y < 0 then perp = ImVec2(-perp.x, -perp.y) end
            return perp
        end

        -- Compute active faces based on the rotation. Returns active_faces, plane_2d
        -- If the plot is close to 2D, plane_2d is the plane index (0 -> YZ, 1 -> XZ, 2 -> XY), -1 otherwise
        function internal.ComputeActiveFaces(rotation, axes)
            local active_faces, plane_2d = {}, -1
            local rot_face_n = { [0] = rotation * P(1, 0, 0), rotation * P(0, 1, 0), rotation * P(0, 0, 1) }
            local num_deg = 0 -- Number of planes that are degenerate (seen as a line)
            for i = 0, 2 do
                local n = rot_face_n[i]
                local active
                if math.abs(n.z) < 0.025 then
                    -- If aligned with the plane, choose the min face for bottom/left
                    active = n.x + n.y < 0.0
                    num_deg += 1
                else
                    local is_inverted = ImHasFlag(axes[i].Flags, ImPlot3D.ImPlot3DAxisFlags.Invert)
                    active = if is_inverted then n.z > 0.0 else n.z < 0.0
                    plane_2d = i -- Set this plane as possible 2d plane
                end
                active_faces[i] = if active then 1 else 0
            end
            -- Only return 2d plane if there are exactly 2 degenerate planes
            if num_deg ~= 2 then plane_2d = -1 end
            return active_faces, plane_2d
        end

        -- Box corners in plot space (0-based)
        function internal.ComputeBoxCorners(range_min, range_max)
            local a, b = range_min, range_max
            return {
                [0] = P(a.x, a.y, a.z), P(b.x, a.y, a.z), P(b.x, b.y, a.z), P(a.x, b.y, a.z),
                P(a.x, a.y, b.z), P(b.x, a.y, b.z), P(b.x, b.y, b.z), P(a.x, b.y, b.z),
            }
        end

        function internal.ComputeBoxCornersPix(plot, corners)
            local corners_pix = {}
            for i = 0, 7 do corners_pix[i] = internal.PlotToPixels(plot, corners[i]) end
            return corners_pix
        end

        -- [Port] returns active_faces, corners_pix, corners, plane_2d, axis_corners (out-params in C++)
        function internal.GetAxesParameters(plot)
            local active_faces, plane_2d = internal.ComputeActiveFaces(plot.Rotation, plot.Axes)
            local corners = internal.ComputeBoxCorners(plot:RangeMin(), plot:RangeMax())
            local corners_pix = internal.ComputeBoxCornersPix(plot, corners)
            local axis_corners = { [0] = { -1, -1 }, { -1, -1 }, { -1, -1 } } -- [Port] axis_corners[a][1|2]
            if plane_2d ~= -1 then
                local face = plane_2d + 3 * active_faces[plane_2d] -- Face of the 2D plot
                local common_edges = { -1, -1 } -- Edges shared by the 3 faces
                for i = 1, 4 do
                    local edge = face_edges[face][i]
                    for j = 0, 1 do
                        local axis = (plane_2d + 1 + j) % 3
                        if table.find(face_edges[axis + active_faces[axis] * 3], edge) then common_edges[j + 1] = edge end
                    end
                end
                -- Get corners from 2 edges (origin is the corner in common)
                local origin_corner, x_corner, y_corner = -1, -1, -1
                local e0, e1 = edges[common_edges[1]], edges[common_edges[2]]
                for i = 1, 2 do
                    for j = 1, 2 do
                        if e0[i] == e1[j] then origin_corner, x_corner, y_corner = e0[i], e0[3 - i], e1[3 - j] end
                    end
                end
                -- Swap x and y if they are flipped
                local x_vec = corners_pix[x_corner] - corners_pix[origin_corner]
                local y_vec = corners_pix[y_corner] - corners_pix[origin_corner]
                if y_vec.x > x_vec.x then x_corner, y_corner = y_corner, x_corner end
                -- Check which 3d axis the 2d axis refers to
                local origin_3d = corners[origin_corner]
                local x_3d = (corners[x_corner] - origin_3d):Normalized()
                local y_3d = (corners[y_corner] - origin_3d):Normalized()
                local x_axis, x_inverted, y_axis, y_inverted = -1, false, -1, false
                for i = 0, 1 do
                    local axis_i = (plane_2d + 1 + i) % 3
                    if y_axis ~= -1 or (math.abs(x_3d[axis_i]) > 1e-8 and x_axis == -1) then
                        x_axis, x_inverted = axis_i, x_3d[axis_i] < 0.0
                    else
                        y_axis, y_inverted = axis_i, y_3d[axis_i] < 0.0
                    end
                end
                -- Set the 3d axis corners based on the 2d axis corners
                axis_corners[x_axis] = if x_inverted then { x_corner, origin_corner } else { origin_corner, x_corner }
                axis_corners[y_axis] = if y_inverted then { y_corner, origin_corner } else { origin_corner, y_corner }
            else
                local lookup = axis_corners_lookup_3d[internal.Active3DFacesToAxisLookupIndex(active_faces)]
                for a = 0, 2 do axis_corners[a] = { lookup[a][1], lookup[a][2] } end
            end
            return active_faces, corners_pix, corners, plane_2d, axis_corners
        end

        -- Spacing constants for axis tick labels and axis labels
        local AXIS_TICK_INNER_PAD = 5.0 -- gap between axis edge and inner edge of tick labels
        local AXIS_LABEL_PAD = 10.0 -- gap between tick label outer edge and axis label center
        local AXIS_RECT_MIN_WIDTH = 40.0 -- minimum hover rect width when labels are absent
        local AxisFlags = ImPlot3D.ImPlot3DAxisFlags
        local Col = ImPlot3D.ImPlot3DCol

        -- Computes the maximum extent of tick labels perpendicular to the axis in screen space
        function internal.ComputeMaxTickLabelExtent(axis)
            if ImHasFlag(axis.Flags, AxisFlags.NoTickLabels) then return 0.0 end
            local max_extent = 0.0
            for _, tick in axis.Ticker.Ticks do
                if tick.ShowLabel then max_extent = math.max(max_extent, tick.LabelSize.x * 0.5) end
            end
            return max_extent
        end

        -- Computes the total outward width of the hover rect for an axis
        function internal.ComputeAxisHoverWidth(axis)
            local w = 2.0 * internal.ComputeMaxTickLabelExtent(axis) + AXIS_TICK_INNER_PAD
            if axis:HasLabel() then w += AXIS_LABEL_PAD + ImGui.CalcTextSize(axis:GetLabel()).y * 0.5 end
            return math.max(w, AXIS_RECT_MIN_WIDTH)
        end

        -- [Port] returns hovered plane (0 -> YZ, 1 -> XZ, 2 -> XY) or -1; plane_out dropped (always equal)
        function internal.GetMouseOverPlane(active_faces, corners_pix)
            local mouse_pos = ImGui.GetIO().MousePos
            local contains = G.ImStd.ImTriangleContainsPoint
            for a = 0, 2 do
                local idx = faces[a + 3 * active_faces[a]]
                local p0, p1, p2, p3 = corners_pix[idx[1]], corners_pix[idx[2]], corners_pix[idx[3]], corners_pix[idx[4]]
                if contains(p0, p1, p2, mouse_pos) or contains(p2, p3, p0, mouse_pos) then return a end
            end
            return -1
        end

        -- Check if a point is inside an edge's hover region (a rectangle extending outward from the edge)
        function internal.IsPointInEdgeHoverRegion(point, p0, p1, outward_dir, width)
            local dir = p1 - p0
            local len = math.sqrt(dir.x * dir.x + dir.y * dir.y)
            if len < 0.001 then return false end
            local local_ = point - p0
            local along = (local_.x * dir.x + local_.y * dir.y) / len
            local across = local_.x * outward_dir.x + local_.y * outward_dir.y
            return along >= 0 and along <= len and across >= 0 and across <= width
        end

        -- [Port] returns hovered axis (or -1), hovered edge index (or -1)
        function internal.GetMouseOverAxis(plot, corners_pix, plane_2d, axis_corners)
            local mouse_pos = ImGui.GetIO().MousePos
            local box_center = ImVec2(0, 0)
            for i = 0, 7 do box_center = box_center + corners_pix[i] end
            box_center = box_center * (1.0 / 8.0)
            for axis_idx = 0, 2 do
                local idx0, idx1 = axis_corners[axis_idx][1], axis_corners[axis_idx][2]
                if not (plane_2d ~= -1 and axis_idx == plane_2d) and idx0 ~= -1 and idx1 ~= -1 then
                    local edge = -1
                    for e = 0, 11 do
                        local ed = edges[e]
                        if (ed[1] == idx0 and ed[2] == idx1) or (ed[1] == idx1 and ed[2] == idx0) then edge = e; break end
                    end
                    if edge ~= -1 then
                        local p0, p1 = corners_pix[idx0], corners_pix[idx1]
                        local outward_dir = internal.ComputeEdgeOutwardDir(p0, p1, box_center)
                        if internal.IsPointInEdgeHoverRegion(mouse_pos, p0, p1, outward_dir, internal.ComputeAxisHoverWidth(plot.Axes[axis_idx])) then
                            return axis_idx, edge
                        end
                    end
                end
            end
            return -1, -1
        end

        function internal.GetLocationPos(outer_rect, inner_size, loc, pad)
            local Loc = ImPlot3D.ImPlot3DLocation
            local W, E = ImHasFlag(loc, Loc.West), ImHasFlag(loc, Loc.East)
            local N, S = ImHasFlag(loc, Loc.North), ImHasFlag(loc, Loc.South)
            local center = outer_rect:GetCenter()
            local x = if W and not E then outer_rect.Min.x + pad.x
                elseif E and not W then outer_rect.Max.x - pad.x - inner_size.x
                else center.x - inner_size.x * 0.5
            local y = if N and not S then outer_rect.Min.y + pad.y
                elseif S and not N then outer_rect.Max.y - pad.y - inner_size.y
                else center.y - inner_size.y * 0.5
            return ImVec2(math.floor(x + 0.5), math.floor(y + 0.5))
        end

        function internal.RenderMousePos()
            local plot = GImPlot3D.CurrentPlot
            if ImHasFlag(plot.Flags, ImPlot3D.ImPlot3DFlags.NoMouseText) then return end
            local mouse_pos = ImGui.GetMousePos()
            local pos = ImPlot3D.PixelsToPlotPlane(mouse_pos, 0, true)
            if pos:IsNaN() then pos = ImPlot3D.PixelsToPlotPlane(mouse_pos, 1, true) end
            if pos:IsNaN() then pos = ImPlot3D.PixelsToPlotPlane(mouse_pos, 2, true) end
            if pos:IsNaN() then return end
            local parts = {}
            for i = 0, 2 do
                local axis = plot.Axes[i]
                parts[i + 1] = axis.Formatter(pos[i], axis.FormatterData)
            end
            local text = "(" .. table.concat(parts, ", ") .. ")"
            local p = internal.GetLocationPos(plot.PlotRect, ImGui.CalcTextSize(text), ImPlot3D.ImPlot3DLocation.SouthEast, ImVec2(10, 10))
            ImGui.GetWindowDrawList():AddText(p, ImPlot3D.GetStyleColorU32(ImPlot3D.ImPlot3DCol.InlayText), text)
        end

        function internal.RenderPlotBackground(draw_list, plot, corners_pix, active_faces, plane_2d, axis_corners)
            local col_bg = ImPlot3D.GetStyleColorVec4(Col.PlotBg)
            local col_bg_hov = col_bg + ImVec4(0.03, 0.03, 0.03, 0.0)
            local hovered_plane
            if not plot.Held then
                -- If the mouse is not held, highlight plane hovering when mouse over it
                hovered_plane = internal.GetMouseOverPlane(active_faces, corners_pix)
                if internal.GetMouseOverAxis(plot, corners_pix, plane_2d, axis_corners) ~= -1 then hovered_plane = -1 end
            else
                -- If the mouse is held, highlight the held plane
                hovered_plane = plot.HeldPlaneIdx
            end
            for a = 0, 2 do
                local idx = faces[a + 3 * active_faces[a]]
                local col = ImGui.ColorConvertFloat4ToU32(if hovered_plane == a then col_bg_hov else col_bg)
                draw_list:AddQuadFilled(corners_pix[idx[1]], corners_pix[idx[2]], corners_pix[idx[3]], corners_pix[idx[4]], col)
            end
        end

        function internal.RenderAxisRects(draw_list, plot, corners_pix, _, plane_2d, axis_corners)
            local hovered_axis = internal.GetMouseOverAxis(plot, corners_pix, plane_2d, axis_corners)
            -- Compute box center in screen space
            local box_center = ImVec2(0, 0)
            for i = 0, 7 do box_center = box_center + corners_pix[i] end
            box_center = box_center * (1.0 / 8.0)
            for axis_idx = 0, 2 do
                local idx0, idx1 = axis_corners[axis_idx][1], axis_corners[axis_idx][2]
                -- In 2D mode, skip the perpendicular axis
                if not (plane_2d ~= -1 and axis_idx == plane_2d) and idx0 ~= -1 and idx1 ~= -1 then
                    local axis = plot.Axes[axis_idx]
                    local p0, p1 = corners_pix[idx0], corners_pix[idx1]
                    local outward_dir = internal.ComputeEdgeOutwardDir(p0, p1, box_center)
                    local hover_width = internal.ComputeAxisHoverWidth(axis)
                    -- Active only when the drag started on this axis rect (HeldEdgeIdx set), not on a plane or outside.
                    local col
                    if axis.Held and plot.HeldEdgeIdx ~= -1 then
                        col = axis.ColorAct
                    elseif axis_idx == hovered_axis and not plot.Held then
                        col = axis.ColorHov
                    else
                        col = axis.ColorBg
                    end
                    -- Draw hover rectangle if color is not transparent
                    if col ~= 0 then
                        draw_list:AddQuadFilled(p0, p0 + outward_dir * hover_width, p1 + outward_dir * hover_width, p1, col)
                    end
                end
            end
        end

        function internal.RenderPlotBorder(draw_list, _, corners_pix, active_faces, plane_2d)
            -- Determine which edges to render (all visible edges)
            local render_edge = {}
            for a = 0, 2 do
                if not (plane_2d ~= -1 and a ~= plane_2d) then
                    for _, e in face_edges[a + 3 * active_faces[a]] do render_edge[e] = true end
                end
            end
            local col_bd = ImPlot3D.GetStyleColorU32(Col.PlotBorder)
            for i = 0, 11 do
                if render_edge[i] then draw_list:AddLine(corners_pix[edges[i][1]], corners_pix[edges[i][2]], col_bd, 1.0) end
            end
        end

        function internal.RenderGrid(draw_list, plot, corners, active_faces, plane_2d)
            local col_grid = ImPlot3D.GetStyleColorVec4(Col.AxisGrid)
            local col_grid_minor = ImGui.GetColorU32(ImVec4(col_grid.x, col_grid.y, col_grid.z, col_grid.w * 0.3))
            local col_grid_major = ImGui.GetColorU32(ImVec4(col_grid.x, col_grid.y, col_grid.z, col_grid.w * 0.6))
            -- Draw grid lines for ticks of `axis` sweeping from a->b (start) / c->d (end)
            local function lines(axis, s0, s1, vec)
                if ImHasFlag(axis.Flags, AxisFlags.NoGridLines) then return end
                for _, tick in axis.Ticker.Ticks do
                    local t = (tick.PlotPos - axis.Range.Min) / (axis.Range.Max - axis.Range.Min)
                    -- Skip ticks that are out of range
                    if t >= 0.0 and t <= 1.0 then
                        local p_start = internal.PlotToPixels(plot, s0 + vec * t)
                        local p_end = internal.PlotToPixels(plot, s1 + vec * t)
                        draw_list:AddLine(p_start, p_end, if tick.Major then col_grid_major else col_grid_minor)
                    end
                end
            end
            for face = 0, 2 do
                if not (plane_2d ~= -1 and face ~= plane_2d) then
                    local f = faces[face + 3 * active_faces[face]]
                    -- Corners of the face in plot space; u/v are the two axes that define the face plane
                    local p0, p1, p3 = corners[f[1]], corners[f[2]], corners[f[4]]
                    lines(plot.Axes[(face + 1) % 3], p0, p3, p1 - p0) -- along u
                    lines(plot.Axes[(face + 2) % 3], p0, p1, p3 - p0) -- along v
                end
            end
        end
        internal.AXIS_TICK_INNER_PAD, internal.AXIS_LABEL_PAD = AXIS_TICK_INNER_PAD, AXIS_LABEL_PAD

        function internal.RenderTickMarks(draw_list, plot, corners, corners_pix, axis_corners, plane_2d)
            local col_tick = ImPlot3D.GetStyleColorU32(Col.AxisTick)
            -- Tick lengths in NDC units
            local major_size_ndc, minor_size_ndc = 0.06, 0.03
            for a = 0, 2 do
                local axis = plot.Axes[a]
                local idx0, idx1 = axis_corners[a][1], axis_corners[a][2]
                -- [Port] `continue` chain flattened into a repeat/break block
                repeat
                    if ImHasFlag(axis.Flags, AxisFlags.NoTickMarks) or idx0 == idx1 then break end -- axis not visible or invalid
                    local axis_start = corners[idx0]
                    local axis_dir = corners[idx1] - axis_start
                    local axis_len = axis_dir:Length()
                    if axis_len < 1e-12 then break end
                    axis_dir = axis_dir / axis_len
                    -- Draw axis line
                    draw_list:AddLine(corners_pix[idx0], corners_pix[idx1], col_tick)
                    -- Choose plane: 2D plane if any, else X/Y axis -> XY plane (2), Z axis -> XZ plane (1)
                    local chosen_plane = if plane_2d ~= -1 then plane_2d elseif a == 2 then 1 else 2
                    -- Project axis_dir onto chosen plane
                    local proj_dir = P(axis_dir.x, axis_dir.y, axis_dir.z)
                    proj_dir[chosen_plane] = 0.0
                    local proj_len = proj_dir:Length()
                    if proj_len < 1e-12 then break end -- Axis is parallel to plane normal, skip ticks
                    proj_dir = proj_dir / proj_len
                    -- Rotate 90 degrees in chosen plane
                    local tick_dir
                    if chosen_plane == 0 then
                        tick_dir = P(0, -proj_dir.z, proj_dir.y) -- YZ plane
                    elseif chosen_plane == 1 then
                        tick_dir = P(-proj_dir.z, 0, proj_dir.x) -- XZ plane
                    else
                        tick_dir = P(-proj_dir.y, proj_dir.x, 0) -- XY plane
                    end
                    tick_dir:Normalize()
                    for _, tick in axis.Ticker.Ticks do
                        local v = (tick.PlotPos - axis.Range.Min) / (axis.Range.Max - axis.Range.Min)
                        -- Skip ticks that are out of range
                        if v >= 0.0 and v <= 1.0 then
                            local tick_pos_ndc = internal.PlotToNDC(plot, axis_start + axis_dir * (v * axis_len))
                            -- Half tick on each side of the axis line
                            local half_tick_ndc = tick_dir * ((if tick.Major then major_size_ndc else minor_size_ndc) * 0.5)
                            draw_list:AddLine(internal.NDCToPixels(plot, tick_pos_ndc - half_tick_ndc),
                                internal.NDCToPixels(plot, tick_pos_ndc + half_tick_ndc), col_tick)
                        end
                    end
                until true
            end
        end

        -- Normalized screen-space direction of an axis edge
        local function ScreenDir(p0, p1)
            local d = p1 - p0
            local len = math.sqrt(d.x * d.x + d.y * d.y)
            return if len > 0.0 then ImVec2(d.x / len, d.y / len) else ImVec2(1.0, 0.0)
        end

        function internal.RenderTickLabels(draw_list, plot, corners, corners_pix, axis_corners)
            local col_tick_txt = ImPlot3D.GetStyleColorU32(Col.AxisText)
            local IM_PI = math.pi
            for a = 0, 2 do
                local axis = plot.Axes[a]
                local idx0, idx1 = axis_corners[a][1], axis_corners[a][2]
                -- If normal to the 2D plot, ignore the ticks
                if not ImHasFlag(axis.Flags, AxisFlags.NoTickLabels) and idx0 ~= idx1 then
                    local axis_start = corners[idx0]
                    local axis_dir = corners[idx1] - axis_start
                    local axis_start_pix, axis_end_pix = corners_pix[idx0], corners_pix[idx1]
                    local axis_screen_dir = ScreenDir(axis_start_pix, axis_end_pix)
                    -- Outward perpendicular direction and label offset
                    local outward_dir = internal.ComputeEdgeOutwardDir(axis_start_pix, axis_end_pix, internal.PlotToPixels(plot, plot:RangeCenter()))
                    local offset_pix = outward_dir * (internal.ComputeMaxTickLabelExtent(axis) + AXIS_TICK_INNER_PAD)
                    -- Compute angle perpendicular to axis in screen space, normalized to [-pi, pi], kept upright
                    local angle = math.atan2(-axis_screen_dir.y, axis_screen_dir.x) + IM_PI * 0.5
                    if angle > IM_PI then angle -= 2 * IM_PI end
                    if angle < -IM_PI then angle += 2 * IM_PI end
                    if angle > IM_PI * 0.5 then angle -= IM_PI end
                    if angle < -IM_PI * 0.5 then angle += IM_PI end
                    for _, tick in axis.Ticker.Ticks do
                        local t_axis = (tick.PlotPos - axis.Range.Min) / (axis.Range.Max - axis.Range.Min)
                        if tick.ShowLabel and t_axis >= 0.0 and t_axis <= 1.0 then
                            local tick_pos_pix = internal.PlotToPixels(plot, axis_start + axis_dir * t_axis)
                            internal.AddTextRotated(draw_list, tick_pos_pix + offset_pix, angle, col_tick_txt, axis.Ticker:GetText(tick))
                        end
                    end
                end
            end
        end

        function internal.RenderAxisLabels(draw_list, plot, _, corners_pix, axis_corners)
            local col_ax_txt = ImPlot3D.GetStyleColorU32(Col.AxisText)
            local IM_PI = math.pi
            for a = 0, 2 do
                local axis = plot.Axes[a]
                local idx0, idx1 = axis_corners[a][1], axis_corners[a][2]
                -- If normal to the 2D plot, ignore axis label
                if axis:HasLabel() and idx0 ~= idx1 then
                    local axis_start_pix, axis_end_pix = corners_pix[idx0], corners_pix[idx1]
                    local axis_screen_dir = ScreenDir(axis_start_pix, axis_end_pix)
                    -- Tick labels are centered at (max_tick_extent + AXIS_TICK_INNER_PAD) from the axis edge,
                    -- so the axis label sits one more max_tick_extent + AXIS_LABEL_PAD beyond that.
                    local outward_dir = internal.ComputeEdgeOutwardDir(axis_start_pix, axis_end_pix, internal.PlotToPixels(plot, plot:RangeCenter()))
                    local max_tick_extent = internal.ComputeMaxTickLabelExtent(axis)
                    local total_offset = max_tick_extent + AXIS_TICK_INNER_PAD + max_tick_extent + AXIS_LABEL_PAD
                    local label_pos_pix = (axis_start_pix + axis_end_pix) * 0.5 + outward_dir * total_offset
                    -- Compute text angle
                    local angle = math.atan2(-axis_screen_dir.y, axis_screen_dir.x)
                    if angle > IM_PI * 0.5 then angle -= IM_PI end
                    if angle < -IM_PI * 0.5 then angle += IM_PI end
                    internal.AddTextRotated(draw_list, label_pos_pix, angle, col_ax_txt, axis:GetLabel())
                end
            end
        end

        function internal.RenderPlotBox(draw_list, plot)
            local active_faces, corners_pix, corners, plane_2d, axis_corners = internal.GetAxesParameters(plot)
            internal.RenderPlotBackground(draw_list, plot, corners_pix, active_faces, plane_2d, axis_corners)
            internal.RenderAxisRects(draw_list, plot, corners_pix, active_faces, plane_2d, axis_corners)
            internal.RenderPlotBorder(draw_list, plot, corners_pix, active_faces, plane_2d)
            internal.RenderGrid(draw_list, plot, corners, active_faces, plane_2d)
            internal.RenderTickMarks(draw_list, plot, corners, corners_pix, axis_corners, plane_2d)
            internal.RenderTickLabels(draw_list, plot, corners, corners_pix, axis_corners)
            internal.RenderAxisLabels(draw_list, plot, corners, corners_pix, axis_corners)
        end
    end

    --------------------------------------------------------------------------
    -- [SECTION] ImPlot3DSpec, ImPlot3DItem, ImPlot3DItemGroup methods, ImPlot3DNextItemData, Item Utils
    --------------------------------------------------------------------------
    do
        local Prop, Marker = ImPlot3D.ImPlot3DProp, ImPlot3D.ImPlot3DMarker
        local ImHasFlag, IsColorAuto = internal.ImHasFlag, internal.IsColorAuto
        local AUTO = ImPlot3D.IMPLOT3D_AUTO

        -- [Port] Prop -> field name. Array props take Lua arrays (1-based) of ImU32/float.
        local prop_fields = {
            [Prop.LineColor] = "LineColor", [Prop.LineColors] = "LineColors", [Prop.LineWeight] = "LineWeight",
            [Prop.FillColor] = "FillColor", [Prop.FillColors] = "FillColors", [Prop.FillAlpha] = "FillAlpha",
            [Prop.Marker] = "Marker", [Prop.MarkerSize] = "MarkerSize", [Prop.MarkerSizes] = "MarkerSizes",
            [Prop.MarkerLineColor] = "MarkerLineColor", [Prop.MarkerLineColors] = "MarkerLineColors",
            [Prop.MarkerFillColor] = "MarkerFillColor", [Prop.MarkerFillColors] = "MarkerFillColors",
            [Prop.Offset] = "Offset", [Prop.Stride] = "Stride", [Prop.Flags] = "Flags",
        }
        local color_fields = { LineColor = true, FillColor = true, MarkerLineColor = true, MarkerFillColor = true }

        local SpecMT = {}
        SpecMT.__index = SpecMT

        -- Set properties from (ImPlot3DProp,value) pairs in any order
        -- [Port] colors accept ImU32 or ImVec4 (the scalar/ImVec4 SetProp overloads)
        function SpecMT:SetProp(...)
            local n = select("#", ...)
            IM_ASSERT(n % 2 == 0, "Odd number of arguments! You must provide (ImPlot3DProp,value) pairs!")
            for i = 1, n, 2 do
                local prop, v = select(i, ...)
                local field = prop_fields[prop]
                IM_ASSERT(field ~= nil, "User provided an invalid ImPlot3DProp!")
                if color_fields[field] and type(v) == "number" then v = ImGui.ColorConvertU32ToFloat4(v) end
                self[field] = v
            end
            return self
        end

        -- [Port] ImPlot3DSpec() / ImPlot3DSpec(prop, value, ...). A plain table of fields is also accepted by PlotX.
        function ImPlot3D.ImPlot3DSpec(...)
            local s = setmetatable({
                LineColor = IMPLOT3D_AUTO_COL(), LineColors = nil, LineWeight = 1.0,
                FillColor = IMPLOT3D_AUTO_COL(), FillColors = nil, FillAlpha = AUTO,
                Marker = Marker.Auto, MarkerSize = AUTO, MarkerSizes = nil,
                MarkerLineColor = IMPLOT3D_AUTO_COL(), MarkerLineColors = nil,
                MarkerFillColor = IMPLOT3D_AUTO_COL(), MarkerFillColors = nil,
                Offset = 0, Stride = AUTO, Flags = 0,
            }, SpecMT)
            if select("#", ...) > 0 then s:SetProp(...) end
            return s
        end

        -- [Port] copy a user spec (ImPlot3DSpec or partial table) into a full spec; colors copied by value
        local function CopySpec(dst, src)
            local def = ImPlot3D.ImPlot3DSpec()
            for k, v in def do
                local sv = src and src[k]
                if sv == nil then sv = v end
                if color_fields[k] then
                    if type(sv) == "number" then sv = ImGui.ColorConvertU32ToFloat4(sv) else sv = ImVec4(sv.x, sv.y, sv.z, sv.w) end
                end
                dst[k] = sv
            end
            for _, k in { "LineColors", "FillColors", "MarkerSizes", "MarkerLineColors", "MarkerFillColors" } do
                dst[k] = src and src[k] or nil
            end
            return dst
        end
        internal.CopySpec = CopySpec

        -- State information for plot items
        function internal.ImPlot3DItem()
            return { ID = 0, Color = G.IM_COL32_WHITE, Marker = Marker.None, NameOffset = -1, Show = true, LegendHovered = false, SeenThisFrame = false }
        end

        function internal.ImPlot3DNextItemData()
            local n = { Spec = ImPlot3D.ImPlot3DSpec() }
            internal.ResetNextItemData(n)
            return n
        end
        function internal.ResetNextItemData(n)
            CopySpec(n.Spec, nil)
            n.RenderLine, n.RenderFill = false, false
            n.RenderMarkerLine, n.RenderMarkerFill = true, true
            n.IsAutoFill, n.IsAutoLine = true, true
            n.Hidden = false
        end

        -- [Port] ImPlot3DItemGroup methods (group is the table from internal.ImPlot3DItemGroup)
        -- [Port] Legend.Labels -> Legend.LabelList (1-based array of label strings); NameOffset = 0-based index into it
        local IG = {}
        internal.ItemGroup = IG
        function IG.GetItemCount(g) return g.ItemPool.BufSize end
        function IG.GetItemID(_, label_id) return ImGui.GetID(label_id) end
        function IG.GetItem(g, id) if type(id) == "string" then id = ImGui.GetID(id) end return g.ItemPool:GetByKey(id) end
        function IG.GetOrAddItem(g, id) return g.ItemPool:GetOrAddByKey(id) end
        function IG.GetItemByIndex(g, i) return g.ItemPool:GetByIndex(i) end
        function IG.GetItemIndex(g, item) return g.ItemPool:GetIndex(item) end
        function IG.GetLegendCount(g) return #g.Legend.Indices end
        function IG.GetLegendItem(g, i) return g.ItemPool:GetByIndex(g.Legend.Indices[i + 1]) end
        function IG.GetLegendLabel(g, i) return g.Legend.LabelList[IG.GetLegendItem(g, i).NameOffset + 1] end
        function IG.Reset(g)
            g.ItemPool:Clear()
            table.clear(g.Legend.Indices)
            table.clear(g.Legend.LabelList)
            g.ColormapIdx, g.MarkerIdx = 0, 0
        end

        function internal.NextMarker()
            local gp = GImPlot3D
            IM_ASSERT(gp.CurrentItems ~= nil, "NextMarker() needs to be called between BeginPlot() and EndPlot()!")
            local idx = gp.CurrentItems.MarkerIdx % Marker.COUNT
            gp.CurrentItems.MarkerIdx += 1
            return idx
        end

        function internal.RegisterOrGetItem(label_id, flags)
            local gp = GImPlot3D
            local Items = gp.CurrentItems
            local id = ImGui.GetID(label_id)
            local just_created = Items.ItemPool:GetByKey(id) == nil
            local item = Items.ItemPool:GetOrAddByKey(id)
            -- Avoid re-adding the same item to the legend (the legend is reset every frame)
            if item.SeenThisFrame then return item, just_created end
            item.SeenThisFrame = true
            -- Add item to the legend
            local idx = Items.ItemPool:GetIndex(item)
            item.ID = id
            local display_end = string.find(label_id, "##", 1, true)
            if not ImHasFlag(flags, ImPlot3D.ImPlot3DItemFlags.NoLegend) and display_end ~= 1 and label_id ~= "" then
                local legend = Items.Legend
                table.insert(legend.Indices, idx)
                item.NameOffset = #legend.LabelList
                table.insert(legend.LabelList, label_id)
            end
            return item, just_created
        end

        function internal.GetCurrentItem() return GImPlot3D.CurrentItem end
        function internal.GetItemData() return GImPlot3D.NextItemData end

        function internal.BustItemCache()
            for _, plot in GImPlot3D.Plots.Buf do
                if plot then IG.Reset(plot.Items) end
            end
        end

        local ITEM_HIGHLIGHT_LINE_SCALE, ITEM_HIGHLIGHT_MARK_SCALE = 2.0, 1.25

        function internal.EndItem()
            local gp = GImPlot3D
            internal.ResetNextItemData(gp.NextItemData)
            gp.CurrentItem = nil
        end

        function internal.BeginItem(label_id, spec, item_col, item_mkr)
            local gp = GImPlot3D
            IM_ASSERT(gp.CurrentPlot ~= nil, "PlotX() needs to be called between BeginPlot() and EndPlot()!")
            ImPlot3D.SetupLock()
            local style = gp.Style
            local n = gp.NextItemData
            local s = CopySpec(n.Spec, spec)
            -- Register item
            local item, just_created = internal.RegisterOrGetItem(label_id, s.Flags)
            gp.CurrentItem = item
            -- Set/override item color
            if item_col ~= nil and type(item_col) == "number" then item_col = ImGui.ColorConvertU32ToFloat4(item_col) end
            if item_col ~= nil and not IsColorAuto(item_col) then
                item.Color = ImGui.ColorConvertFloat4ToU32(item_col)
            elseif just_created then
                item.Color = internal.NextColormapColorU32()
            end
            -- Set/override item marker
            item_mkr = item_mkr or Marker.Invalid
            if item_mkr ~= Marker.Invalid then
                if item_mkr ~= Marker.Auto then
                    item.Marker = item_mkr
                elseif just_created or item.Marker == Marker.None then
                    item.Marker = internal.NextMarker()
                end
            end
            -- Set next item color
            local ic = ImGui.ColorConvertU32ToFloat4(item.Color)
            n.IsAutoLine = IsColorAuto(s.LineColor)
            n.IsAutoFill = IsColorAuto(s.FillColor)
            if IsColorAuto(s.LineColor) then s.LineColor = ImVec4(ic.x, ic.y, ic.z, ic.w) end
            if IsColorAuto(s.FillColor) then s.FillColor = ImVec4(ic.x, ic.y, ic.z, ic.w) end
            if IsColorAuto(s.MarkerLineColor) then local c = s.LineColor s.MarkerLineColor = ImVec4(c.x, c.y, c.z, c.w) end
            if IsColorAuto(s.MarkerFillColor) then local c = s.LineColor s.MarkerFillColor = ImVec4(c.x, c.y, c.z, c.w) end
            -- Set size & weight
            if s.LineWeight < 0 then s.LineWeight = style.LineWeight end
            if s.Marker < 0 then s.Marker = style.Marker end
            if s.MarkerSize < 0 then s.MarkerSize = style.MarkerSize end
            if s.FillAlpha < 0 then s.FillAlpha = style.FillAlpha end
            -- Apply alpha modifiers
            s.FillColor.w *= s.FillAlpha
            s.MarkerFillColor.w *= s.FillAlpha
            -- Set render flags
            n.RenderLine = s.LineColor.w > 0 and s.LineWeight > 0
            n.RenderFill = s.FillColor.w > 0
            n.RenderMarkerLine = s.LineColor.w > 0 and s.LineWeight > 0
            n.RenderMarkerFill = s.FillColor.w > 0
            -- Don't render if item is hidden
            if not item.Show then
                internal.EndItem()
                return false
            elseif item.LegendHovered and not ImHasFlag(gp.CurrentItems.Legend.Flags, ImPlot3D.ImPlot3DLegendFlags.NoHighlightItem) then
                -- Legend hover highlight
                s.LineWeight *= ITEM_HIGHLIGHT_LINE_SCALE
                s.MarkerSize *= ITEM_HIGHLIGHT_MARK_SCALE
            end
            return true
        end

        -- [Port] getter: { Count, Get = function(g, idx) -> x, y, z } (see Getters section)
        function internal.BeginItemEx(label_id, getter, spec, item_col, item_mkr)
            if internal.BeginItem(label_id, spec, item_col, item_mkr) then
                local plot = GImPlot3D.CurrentPlot
                if plot.FitThisFrame and not ImHasFlag(GImPlot3D.NextItemData.Spec.Flags, ImPlot3D.ImPlot3DItemFlags.NoFit) then
                    local a0, a1, a2 = plot.Axes[0], plot.Axes[1], plot.Axes[2]
                    local f0, f1, f2 = a0.FitThisFrame, a1.FitThisFrame, a2.FitThisFrame
                    local get = getter.Get
                    for i = 0, getter.Count - 1 do
                        -- [Port] plot.ExtendFit(getter(i)) inlined: no ImPlot3DPoint per point
                        local x, y, z = get(getter, i)
                        if f0 then a0:ExtendFit(x) end
                        if f1 then a1:ExtendFit(y) end
                        if f2 then a2:ExtendFit(z) end
                    end
                end
                return true
            end
            return false
        end
    end

    --------------------------------------------------------------------------
    -- [SECTION] Getters, Renderers, RenderPrimitives (implot3d_items.cpp)
    -- [Port] Getters are { Count, Get = function(g, idx) -> x, y, z } (idx 0-based), color getters ->
    -- renderer fields Col/Cols/Alpha, size getters -> Size/Sizes. Hot loops work on scalars: the
    -- plot->pixel transform and depth are cached per RenderPrimitivesEx call (no ImPlot3DPoint/ImVec2 per point).
    --------------------------------------------------------------------------
    do
        local ImHasFlag = internal.ImHasFlag
        local writef64, writeu32, sqrt, min, max = buffer.writef64, buffer.writeu32, math.sqrt, math.min, math.max
        local VTX_STRIDE = G.VTX_STRIDE or 36
        local HUGE = math.huge

        -- Indexers / Getters
        local function GetXYZ(g, idx)
            local s, off = g.Stride, g.Offset
            local i = (if off == 0 then idx else (off + idx) % g.Count) * s + 1
            return g.Xs[i], g.Ys[i], g.Zs[i]
        end
        function internal.GetterXYZ(xs, ys, zs, count, offset, stride)
            return { Xs = xs, Ys = ys, Zs = zs, Count = count, Offset = if count > 0 then internal.ImPosMod(offset or 0, count) else 0,
                Stride = stride or 1, Get = GetXYZ }
        end
        local function GetLoop(g, idx) local inner = g.Getter return inner.Get(inner, idx % (g.Count - 1)) end
        function internal.GetterLoop(getter) return { Getter = getter, Count = getter.Count + 1, Get = GetLoop } end

        -- Transform cache (PlotToPixels + GetPointDepth as scalars)
        local ax_tf, ax_td, ax_min, ax_size, ax_inv, ax_ndc = {}, {}, {}, {}, {}, {}
        local qx, qy, qz, qw, vscale, cx, cy = 0, 0, 0, 1, 1, 0, 0
        local function CacheTransform(plot)
            for i = 0, 2 do
                local a = plot.Axes[i]
                ax_tf[i], ax_td[i] = a.TransformForward, a.TransformData
                local r = if a.TransformForward ~= nil then a.ScaledRange else a.Range
                ax_min[i], ax_size[i] = r.Min, r.Max - r.Min
                ax_inv[i] = ImHasFlag(a.Flags, ImPlot3D.ImPlot3DAxisFlags.Invert)
                ax_ndc[i] = a.NDCScale
            end
            local q = plot.Rotation
            qx, qy, qz, qw = q.x, q.y, q.z, q.w
            vscale = plot:GetViewScale()
            local c = plot.PlotRect:GetCenter()
            cx, cy = c.x, c.y
        end
        local function Rotate(x, y, z)
            local ux, uy, uz = qy * z - qz * y, qz * x - qx * z, qx * y - qy * x
            local vx, vy, vz = qy * uz - qz * uy, qz * ux - qx * uz, qx * uy - qy * ux
            return x + 2 * (qw * ux + vx), y + 2 * (qw * uy + vy), z + 2 * (qw * uz + vz)
        end
        local function NDC(i, v)
            local tf = ax_tf[i]
            if tf ~= nil then v = tf(v, ax_td[i]) end
            local t = (v - ax_min[i]) / ax_size[i]
            return (if ax_inv[i] then 0.5 - t else t - 0.5) * ax_ndc[i]
        end
        local function ToPixels(x, y, z)
            local rx, ry = Rotate(NDC(0, x), NDC(1, y), NDC(2, z))
            return rx * vscale + cx, -ry * vscale + cy
        end
        local function Depth(x, y, z)
            if ax_inv[0] then x = -x end
            if ax_inv[1] then y = -y end
            if ax_inv[2] then z = -z end
            local _, _, rz = Rotate(x, y, z)
            return rz
        end
        internal.CacheTransform, internal.TransformToPixels, internal.GetPointDepth = CacheTransform, ToPixels, Depth

        -- Liang-Barsky clip against the cull box; returns t0, t1 or nil when outside
        -- [Port] upstream lambda -> module-level helper on ct0/ct1 (no closure per call)
        local bx0, by0, bz0, bx1, by1, bz1 = 0, 0, 0, 0, 0, 0
        local ct0, ct1 = 0.0, 1.0
        local function upd(p, q)
            if p == 0.0 then return q >= 0.0 end
            local r = q / p
            if p < 0.0 then
                if r > ct1 then return false end
                if r > ct0 then ct0 = r end
            else
                if r < ct0 then return false end
                if r < ct1 then ct1 = r end
            end
            return true
        end
        local function Clip(x0, y0, z0, x1, y1, z1)
            if x0 >= bx0 and x0 <= bx1 and y0 >= by0 and y0 <= by1 and z0 >= bz0 and z0 <= bz1
                and x1 >= bx0 and x1 <= bx1 and y1 >= by0 and y1 <= by1 and z1 >= bz0 and z1 <= bz1 then
                return 0.0, 1.0
            end
            ct0, ct1 = 0.0, 1.0
            local dx, dy, dz = x1 - x0, y1 - y0, z1 - z0
            if not (upd(-dx, x0 - bx0) and upd(dx, bx1 - x0) and upd(-dy, y0 - by0) and upd(dy, by1 - y0)
                and upd(-dz, z0 - bz0) and upd(dz, bz1 - z0)) then return nil end
            return ct0, ct1
        end

        local function GetCol(r, prim)
            local cols = r.Cols
            if cols == nil then return r.Col end
            local col = cols[prim + 1]
            if r.Alpha < 1.0 then
                local c = ImGui.ColorConvertU32ToFloat4(col)
                c.w *= r.Alpha
                col = ImGui.ColorConvertFloat4ToU32(c)
            end
            return col
        end

        local function PrimLine(dl, x1, y1, x2, y2, hw, col, u0, v0, u1, v1, z)
            local dx, dy = x2 - x1, y2 - y1
            local d2 = dx * dx + dy * dy
            if d2 > 0 then local inv = 1 / sqrt(d2); dx *= inv; dy *= inv end
            dx *= hw; dy *= hw
            local b, o = dl.VtxBuffer.Buf, (dl._VtxWritePtr - 1) * VTX_STRIDE
            writef64(b, o, x1 + dy); writef64(b, o + 8, y1 - dx); writef64(b, o + 16, u0); writef64(b, o + 24, v0); writeu32(b, o + 32, col)
            o += VTX_STRIDE
            writef64(b, o, x2 + dy); writef64(b, o + 8, y2 - dx); writef64(b, o + 16, u0); writef64(b, o + 24, v0); writeu32(b, o + 32, col)
            o += VTX_STRIDE
            writef64(b, o, x2 - dy); writef64(b, o + 8, y2 + dx); writef64(b, o + 16, u1); writef64(b, o + 24, v1); writeu32(b, o + 32, col)
            o += VTX_STRIDE
            writef64(b, o, x1 - dy); writef64(b, o + 8, y1 + dx); writef64(b, o + 16, u1); writef64(b, o + 24, v1); writeu32(b, o + 32, col)
            local idx, id, iw = dl._VtxCurrentIdx, dl.IdxBuffer, dl._IdxWritePtr
            id[iw] = idx; id[iw + 1] = idx + 1; id[iw + 2] = idx + 2
            id[iw + 3] = idx; id[iw + 4] = idx + 2; id[iw + 5] = idx + 3
            local zb, zw = dl.ZBuffer, dl._ZWritePtr
            zb[zw] = z; zb[zw + 1] = z
            dl._VtxWritePtr += 4; dl._IdxWritePtr = iw + 6; dl._VtxCurrentIdx = idx + 4; dl._ZWritePtr = zw + 2
        end

        local function LineInit(r)
            local hw = r.HalfWeight
            local u0, v0, u1, v1, fringe = ImGui.GetWindowDrawList():_SelectLineTexture(hw * 2.0, r.DLFlags)
            r.HalfWeight, r.U0, r.V0, r.U1, r.V1 = hw + fringe * 0.5, u0, v0, u1, v1
        end
        local function WhiteInit(r)
            local uv = ImGui.GetDrawListSharedData().TexUvWhitePixel
            r.U, r.V = uv.x, uv.y
        end

        -- Shared segment render: clip, project, emit (P1 -> P2)
        local function Segment(r, dl, prim, x1, y1, z1, x2, y2, z2)
            local t0, t1 = Clip(x1, y1, z1, x2, y2, z2)
            if t0 == nil then return false end
            local dx, dy, dz = x2 - x1, y2 - y1, z2 - z1
            local ax, ay = ToPixels(x1 + dx * t0, y1 + dy * t0, z1 + dz * t0)
            local bx, by = ToPixels(x1 + dx * t1, y1 + dy * t1, z1 + dz * t1)
            PrimLine(dl, ax, ay, bx, by, r.HalfWeight, GetCol(r, prim), r.U0, r.V0, r.U1, r.V1,
                Depth((x1 + x2) * 0.5, (y1 + y2) * 0.5, (z1 + z2) * 0.5))
            return true
        end

        local function LineStripRender(r, dl, prim)
            local g = r.Getter
            local x2, y2, z2 = g.Get(g, prim + 1)
            local vis = Segment(r, dl, prim, r.X1, r.Y1, r.Z1, x2, y2, z2)
            r.X1, r.Y1, r.Z1 = x2, y2, z2
            return vis
        end
        local function LineStripSkipRender(r, dl, prim)
            local g = r.Getter
            local x2, y2, z2 = g.Get(g, prim + 1)
            local x1, y1, z1 = r.X1, r.Y1, r.Z1
            local vis = false
            if x1 == x1 and y1 == y1 and z1 == z1 and x2 == x2 and y2 == y2 and z2 == z2 then
                vis = Segment(r, dl, prim, x1, y1, z1, x2, y2, z2)
            end
            if x2 == x2 and y2 == y2 and z2 == z2 then r.X1, r.Y1, r.Z1 = x2, y2, z2 end
            return vis
        end
        local function LineSegmentsRender(r, dl, prim)
            local g = r.Getter
            local x1, y1, z1 = g.Get(g, prim * 2)
            local x2, y2, z2 = g.Get(g, prim * 2 + 1)
            if x1 == x1 and y1 == y1 and z1 == z1 and x2 == x2 and y2 == y2 and z2 == z2 then
                return Segment(r, dl, prim, x1, y1, z1, x2, y2, z2)
            end
            return false
        end
        local line_renders = { Strip = LineStripRender, StripSkip = LineStripSkipRender, Segments = LineSegmentsRender }
        -- kind: "Strip" | "StripSkip" | "Segments"
        function internal.RendererLine(kind, getter, weight)
            local r = { Getter = getter, HalfWeight = max(1.0, weight) * 0.5, IdxConsumed = 6, VtxConsumed = 4,
                Prims = if kind == "Segments" then getter.Count // 2 else getter.Count - 1,
                Init = LineInit, Render = line_renders[kind] }
            if kind ~= "Segments" then r.X1, r.Y1, r.Z1 = getter.Get(getter, 0) end
            return r
        end

        local function MarkersFillRender(r, dl, prim)
            local g = r.Getter
            local x, y, z = g.Get(g, prim)
            if not (x >= bx0 and x <= bx1 and y >= by0 and y <= by1 and z >= bz0 and z <= bz1) then return false end
            local px, py = ToPixels(x, y, z)
            local col = GetCol(r, prim)
            local size = if r.Sizes then r.Sizes[prim + 1] else r.Size
            local m, count, u, v = r.Marker, r.Count, r.U, r.V
            local b, o = dl.VtxBuffer.Buf, (dl._VtxWritePtr - 1) * VTX_STRIDE
            for i = 0, count - 1 do
                writef64(b, o, px + m[i * 2 + 1] * size); writef64(b, o + 8, py + m[i * 2 + 2] * size)
                writef64(b, o + 16, u); writef64(b, o + 24, v); writeu32(b, o + 32, col)
                o += VTX_STRIDE
            end
            local idx, id, iw = dl._VtxCurrentIdx, dl.IdxBuffer, dl._IdxWritePtr
            local zb, zw, depth = dl.ZBuffer, dl._ZWritePtr, Depth(x, y, z)
            for i = 2, count - 1 do
                id[iw] = idx; id[iw + 1] = idx + i - 1; id[iw + 2] = idx + i
                iw += 3
                zb[zw] = depth; zw += 1
            end
            dl._VtxWritePtr += count; dl._IdxWritePtr = iw; dl._VtxCurrentIdx = idx + count; dl._ZWritePtr = zw
            return true
        end
        function internal.RendererMarkersFill(getter, marker, count)
            return { Prims = getter.Count, IdxConsumed = (count - 2) * 3, VtxConsumed = count,
                Getter = getter, Marker = marker, Count = count, Init = WhiteInit, Render = MarkersFillRender }
        end

        local function MarkersLineRender(r, dl, prim)
            local g = r.Getter
            local x, y, z = g.Get(g, prim)
            if not (x >= bx0 and x <= bx1 and y >= by0 and y <= by1 and z >= bz0 and z <= bz1) then return false end
            local px, py = ToPixels(x, y, z)
            local col = GetCol(r, prim)
            local size = if r.Sizes then r.Sizes[prim + 1] else r.Size
            local m, hw, depth = r.Marker, r.HalfWeight, Depth(x, y, z)
            for i = 0, r.Count - 1, 2 do
                PrimLine(dl, px + m[i * 2 + 1] * size, py + m[i * 2 + 2] * size, px + m[i * 2 + 3] * size, py + m[i * 2 + 4] * size,
                    hw, col, r.U0, r.V0, r.U1, r.V1, depth)
            end
            return true
        end
        function internal.RendererMarkersLine(getter, marker, count, weight)
            return { Prims = getter.Count, IdxConsumed = count // 2 * 6, VtxConsumed = count // 2 * 4,
                Getter = getter, Marker = marker, Count = count, HalfWeight = max(1.0, weight) * 0.5,
                Init = LineInit, Render = MarkersLineRender }
        end

        -- [Port] color getter (GetterConstColor/GetterIdxColor) and size getter folded into renderer fields
        function internal.RenderPrimitivesEx(r, col, cols, alpha, size, sizes)
            local plot = GImPlot3D.CurrentPlot
            local dl = plot.DrawList
            r.Col, r.Cols, r.Alpha, r.Size, r.Sizes, r.DLFlags = col, cols, alpha or 1.0, size, sizes, dl._Flags
            if ImHasFlag(plot.Flags, ImPlot3D.ImPlot3DFlags.NoClip) then
                bx0, by0, bz0, bx1, by1, bz1 = -HUGE, -HUGE, -HUGE, HUGE, HUGE, HUGE
            else
                local a = plot.Axes
                bx0, by0, bz0 = a[0].Range.Min, a[1].Range.Min, a[2].Range.Min
                bx1, by1, bz1 = a[0].Range.Max, a[1].Range.Max, a[2].Range.Max
            end
            CacheTransform(plot)
            -- Find how many can be reserved up to end of current draw command's limit
            local prims = min(r.Prims, (internal.ImDrawList3D_MaxIdx - dl._VtxCurrentIdx) // r.VtxConsumed)
            if prims <= 0 then return end
            dl:PrimReserve(prims * r.IdxConsumed, prims * r.VtxConsumed)
            r.Init(r)
            local render, culled = r.Render, 0
            for i = 0, prims - 1 do
                if not render(r, dl, i) then culled += 1 end
            end
            dl:PrimUnreserve(culled * r.IdxConsumed, culled * r.VtxConsumed)
        end
    end

    --------------------------------------------------------------------------
    -- [SECTION] Markers, PlotScatter, PlotLine
    -- [Port] marker shapes are flat {x1, y1, x2, y2, ...} arrays
    -- [Port] PlotX(label_id, xs, ys, zs, count?, spec?): xs/ys/zs are 1-based Lua arrays; count defaults to #xs.
    -- spec is an ImPlot3DSpec or a plain table of spec fields. Stride is in elements (default 1).
    --------------------------------------------------------------------------
    do
        local M, LineFlags = ImPlot3D.ImPlot3DMarker, ImPlot3D.ImPlot3DLineFlags
        local ImHasFlag = internal.ImHasFlag
        local S12, S32 = 0.70710678118, 0.86602540378
        local FILL = {
            [M.Circle] = { 1.0, 0.0, 0.809017, 0.58778524, 0.30901697, 0.95105654, -0.30901703, 0.9510565, -0.80901706, 0.5877852,
                -1.0, 0.0, -0.80901694, -0.58778536, -0.3090171, -0.9510565, 0.30901712, -0.9510565, 0.80901694, -0.5877853 },
            [M.Square] = { S12, S12, S12, -S12, -S12, -S12, -S12, S12 },
            [M.Diamond] = { 1, 0, 0, -1, -1, 0, 0, 1 },
            [M.Up] = { S32, 0.5, 0, -1, -S32, 0.5 },
            [M.Down] = { S32, -0.5, 0, 1, -S32, -0.5 },
            [M.Left] = { -1, 0, 0.5, S32, 0.5, -S32 },
            [M.Right] = { 1, 0, -0.5, S32, -0.5, -S32 },
        }
        -- Line markers: closed outlines of the fill shapes as segment pairs, plus the line-only markers
        local LINE = {
            [M.Asterisk] = { -S32, -0.5, S32, 0.5, -S32, 0.5, S32, -0.5, 0, -1, 0, 1 },
            [M.Plus] = { -1, 0, 1, 0, 0, -1, 0, 1 },
            [M.Cross] = { -S12, -S12, S12, S12, S12, -S12, -S12, S12 },
        }
        for m, f in FILL do
            local n, out = #f // 2, {}
            for i = 0, n - 1 do
                local j = (i + 1) % n
                table.insert(out, f[i * 2 + 1]); table.insert(out, f[i * 2 + 2])
                table.insert(out, f[j * 2 + 1]); table.insert(out, f[j * 2 + 2])
            end
            LINE[m] = out
        end

        local function RenderMarkers(getter, marker, rend_fill, col_fill, cols_fill, fill_alpha, rend_line, col_line, cols_line, size, sizes, weight)
            local f = FILL[marker]
            if rend_fill and f then
                internal.RenderPrimitivesEx(internal.RendererMarkersFill(getter, f, #f // 2), col_fill, cols_fill, fill_alpha, size, sizes)
            end
            local l = LINE[marker]
            if rend_line and l then
                internal.RenderPrimitivesEx(internal.RendererMarkersLine(getter, l, #l // 2, weight), col_line, cols_line, 1.0, size, sizes)
            end
        end
        internal.RenderMarkers = RenderMarkers

        function internal.RenderColoredMarkers(getter, n)
            local s = n.Spec
            RenderMarkers(getter, s.Marker, n.RenderMarkerFill, ImGui.GetColorU32(s.MarkerFillColor), s.MarkerFillColors, s.FillAlpha,
                n.RenderMarkerLine, ImGui.GetColorU32(s.MarkerLineColor), s.MarkerLineColors, s.MarkerSize, s.MarkerSizes, s.LineWeight)
        end

        -- [Port] overload dispatch: (label, xs, ys, zs, [count], [spec])
        local function Args(xs, count, spec)
            if type(count) == "table" then count, spec = nil, count end
            return count or #xs, spec or ImPlot3D.ImPlot3DSpec()
        end
        local function Stride(spec) return if spec.Stride == nil or spec.Stride == ImPlot3D.IMPLOT3D_AUTO then 1 else spec.Stride end

        function internal.PlotScatterEx(label_id, getter, spec)
            if internal.BeginItemEx(label_id, getter, spec, spec.MarkerLineColor, spec.Marker or M.Auto) then
                local n = GImPlot3D.NextItemData
                -- Scatter always renders a marker; default to Circle
                if n.Spec.Marker == M.None then n.Spec.Marker = M.Circle end
                internal.RenderColoredMarkers(getter, n)
                internal.EndItem()
            end
        end

        function ImPlot3D.PlotScatter(label_id, xs, ys, zs, count, spec)
            count, spec = Args(xs, count, spec)
            if count < 1 then return end
            internal.PlotScatterEx(label_id, internal.GetterXYZ(xs, ys, zs, count, spec.Offset, Stride(spec)), spec)
        end

        function internal.PlotLineEx(label_id, getter, spec)
            if internal.BeginItemEx(label_id, getter, spec, spec.LineColor, spec.Marker or M.Auto) then
                local n = GImPlot3D.NextItemData
                local s = n.Spec
                local flags = s.Flags
                if getter.Count >= 2 and n.RenderLine then
                    local col = ImGui.GetColorU32(s.LineColor)
                    local kind, g = "Strip", getter
                    if ImHasFlag(flags, LineFlags.Segments) then
                        kind = "Segments"
                    else
                        if ImHasFlag(flags, LineFlags.Loop) then g = internal.GetterLoop(getter) end
                        if ImHasFlag(flags, LineFlags.SkipNaN) then kind = "StripSkip" end
                    end
                    internal.RenderPrimitivesEx(internal.RendererLine(kind, g, s.LineWeight), col, s.LineColors, 1.0)
                end
                -- Render markers
                if s.Marker ~= M.None then internal.RenderColoredMarkers(getter, n) end
                internal.EndItem()
            end
        end

        function ImPlot3D.PlotLine(label_id, xs, ys, zs, count, spec)
            count, spec = Args(xs, count, spec)
            if count < 2 then return end
            internal.PlotLineEx(label_id, internal.GetterXYZ(xs, ys, zs, count, spec.Offset, Stride(spec)), spec)
        end
    end

    --------------------------------------------------------------------------
    -- [SECTION] Legend Utils
    --------------------------------------------------------------------------
    do
        local ImHasFlag, IG = internal.ImHasFlag, internal.ItemGroup
        local LF = ImPlot3D.ImPlot3DLegendFlags
        local band, bnot, lshift = bit32.band, bit32.bnot, bit32.lshift
        local ImRect = G.ImRect

        local function ImAlphaU32(col, alpha) return band(col, bnot(lshift(math.floor((1 - alpha) * 255), 24))) end
        internal.ImAlphaU32 = ImAlphaU32

        function internal.CalcLegendSize(items, pad, spacing, vertical)
            local n = IG.GetLegendCount(items)
            local txt_ht = ImGui.GetTextLineHeight()
            local icon_size = txt_ht
            local max_w, sum_w = 0, 0
            for i = 0, n - 1 do
                local w = ImGui.CalcTextSize(IG.GetLegendLabel(items, i), nil, true).x
                max_w = math.max(max_w, w)
                sum_w += w
            end
            if vertical then
                return ImVec2(pad.x * 2 + icon_size + max_w, pad.y * 2 + n * txt_ht + (n - 1) * spacing.y)
            end
            return ImVec2(pad.x * 2 + icon_size * n + sum_w + (n - 1) * spacing.x, pad.y * 2 + txt_ht)
        end

        -- [Port] modifies legend_rect in place, returns clamped
        function internal.ClampLegendRect(r, outer, pad)
            local clamped = false
            local minx, miny, maxx, maxy = outer.Min.x + pad.x, outer.Min.y + pad.y, outer.Max.x - pad.x, outer.Max.y - pad.y
            if r.Min.x < minx then r.Min.x = minx; clamped = true end
            if r.Min.y < miny then r.Min.y = miny; clamped = true end
            if r.Max.x > maxx then r.Max.x = maxx; clamped = true end
            if r.Max.y > maxy then r.Max.y = maxy; clamped = true end
            return clamped
        end

        function internal.ShowLegendEntries(items, legend_bb, pad, spacing, vertical, draw_list)
            local txt_ht = ImGui.GetTextLineHeight()
            local icon_size, icon_shrink = txt_ht, 2
            local col_txt = ImPlot3D.GetStyleColorU32(ImPlot3D.ImPlot3DCol.LegendText)
            local col_txt_dis = ImAlphaU32(col_txt, 0.25)
            local sum_label_width = 0
            local n = IG.GetLegendCount(items)
            for i = 0, n - 1 do
                local item = IG.GetLegendItem(items, i)
                local label = IG.GetLegendLabel(items, i)
                local label_width = ImGui.CalcTextSize(label, nil, true).x
                local top_left = if vertical then legend_bb.Min + pad + ImVec2(0, i * (txt_ht + spacing.y))
                    else legend_bb.Min + pad + ImVec2(i * (icon_size + spacing.x) + sum_label_width, 0)
                sum_label_width += label_width
                local icon_min = top_left + ImVec2(icon_shrink, icon_shrink)
                local icon_max = top_left + ImVec2(icon_size - icon_shrink, icon_size - icon_shrink)
                local label_max = top_left + ImVec2(label_width + icon_size, icon_size)
                local col_item = ImAlphaU32(item.Color, 1)
                local button_bb = ImRect(icon_min, label_max)
                ImGui.KeepAliveID(item.ID)
                local item_clk, item_hov, item_hld = false, false, false
                if not ImHasFlag(items.Legend.Flags, LF.NoButtons) then
                    item_clk, item_hov, item_hld = ImGui.ButtonBehavior(button_bb, item.ID)
                end
                if item_clk then item.Show = not item.Show end
                local col_txt_hl
                if item_hov and not ImHasFlag(items.Legend.Flags, LF.NoHighlightItem) then
                    item.LegendHovered = true
                    col_txt_hl = internal.ImMixU32(col_txt, col_item, 64)
                else
                    item.LegendHovered = false
                    col_txt_hl = ImGui.GetColorU32(col_txt, nil, true)
                end
                local col_icon
                if item_hld then
                    col_icon = if item.Show then ImAlphaU32(col_item, 0.5) else ImGui.GetColorU32(G.ImGuiCol.TextDisabled, 0.5)
                elseif item_hov then
                    col_icon = if item.Show then ImAlphaU32(col_item, 0.75) else ImGui.GetColorU32(G.ImGuiCol.TextDisabled, 0.75)
                else
                    col_icon = if item.Show then col_item else col_txt_dis
                end
                draw_list:AddRectFilled(icon_min, icon_max, col_icon)
                local text_end = ImGui.FindRenderedTextEnd(label)
                if text_end > 1 then
                    draw_list:AddText(top_left + ImVec2(icon_size, 0), if item.Show then col_txt_hl else col_txt_dis, label, text_end)
                end
            end
        end

        function internal.RenderLegend()
            local gp = GImPlot3D
            local plot = gp.CurrentPlot
            if ImHasFlag(plot.Flags, ImPlot3D.ImPlot3DFlags.NoLegend) or IG.GetLegendCount(plot.Items) == 0 then return end
            local draw_list = ImGui.GetWindowDrawList()
            local IO = ImGui.GetIO()
            local style = gp.Style
            local legend = plot.Items.Legend
            local legend_horz = ImHasFlag(legend.Flags, LF.Horizontal)
            local legend_size = internal.CalcLegendSize(plot.Items, style.LegendInnerPadding, style.LegendSpacing, not legend_horz)
            local legend_pos = internal.GetLocationPos(plot.PlotRect, legend_size, legend.Location, style.LegendPadding)
            legend.Rect = ImRect(legend_pos, legend_pos + legend_size)
            legend.RectClamped = ImRect(legend.Rect.Min, legend.Rect.Max)
            local legend_scrollable = internal.ClampLegendRect(legend.RectClamped, plot.PlotRect, style.LegendPadding)
            -- Test hover (using the clamped rect so off-screen overflow does not register)
            local BF = G.ImGuiButtonFlags
            local flags = bit32.bor(BF.AllowOverlap, BF.PressedOnClick, BF.PressedOnDoubleClick, BF.MouseButtonLeft,
                BF.MouseButtonRight, BF.MouseButtonMiddle, BF.FlattenChildren)
            ImGui.KeepAliveID(plot.Items.ID)
            local _
            _, legend.Hovered, legend.Held = ImGui.ButtonBehavior(legend.RectClamped, plot.Items.ID, flags)
            legend.Hovered = legend.Hovered or legend.RectClamped:Contains(IO.MousePos)
            -- Handle legend scrolling
            if legend_scrollable then
                if legend.Hovered then
                    ImGui.SetKeyOwner(G.ImGuiKey.MouseWheelY, plot.Items.ID)
                    if IO.MouseWheel ~= 0.0 then
                        local max_step = legend.Rect:GetSize() * 0.67
                        local step = math.floor(math.min(2 * ImGui.GetFontSize(), max_step.x))
                        legend.Scroll.x += step * IO.MouseWheel
                        legend.Scroll.y += step * IO.MouseWheel
                    end
                end
                local min_off = legend.RectClamped:GetSize() - legend.Rect:GetSize()
                legend.Scroll.x = math.clamp(legend.Scroll.x, math.min(min_off.x, 0), 0)
                legend.Scroll.y = math.clamp(legend.Scroll.y, math.min(min_off.y, 0), 0)
                local scroll = if legend_horz then ImVec2(legend.Scroll.x, 0) else ImVec2(0, legend.Scroll.y)
                local off = legend.RectClamped.Min - legend.Rect.Min + scroll
                legend.Rect = ImRect(legend.Rect.Min + off, legend.Rect.Max + off)
            else
                legend.Scroll = ImVec2(0, 0)
            end
            -- Render background and entries (clipped to the clamped rect)
            local col_bg = ImPlot3D.GetStyleColorU32(ImPlot3D.ImPlot3DCol.LegendBg)
            local col_bd = ImPlot3D.GetStyleColorU32(ImPlot3D.ImPlot3DCol.LegendBorder)
            ImGui.PushClipRect(legend.RectClamped.Min, legend.RectClamped.Max, true)
            draw_list:AddRectFilled(legend.RectClamped.Min, legend.RectClamped.Max, col_bg)
            internal.ShowLegendEntries(plot.Items, legend.Rect, style.LegendInnerPadding, style.LegendSpacing, not legend_horz, draw_list)
            draw_list:AddRect(legend.RectClamped.Min, legend.RectClamped.Max, col_bd)
            ImGui.PopClipRect()
        end
    end

    --------------------------------------------------------------------------
    -- [SECTION] ImDrawList3D
    -- [Port] VtxBuffer is an ImDrawVtxBuffer (same 36-byte vertex layout as ImDrawList), IdxBuffer/ZBuffer are
    -- 1-based Lua arrays sized by IdxSize/ZSize (never shrunk, so no per-frame allocation). Write ptrs are 1-based;
    -- _VtxCurrentIdx is 0-based (local to this list) and offset by ImDrawList._VtxCurrentIdx on move.
    -- [Port] SetTexture/ResetTexture (PlotImage) not ported yet: everything uses the draw list's current texture.
    --------------------------------------------------------------------------
    do
        local DL3 = {}
        DL3.__index = DL3
        local MAX_IDX = 4294967295
        internal.ImDrawList3D_MaxIdx = MAX_IDX

        function internal.ImDrawList3D()
            local self = setmetatable({
                VtxBuffer = G.ImDrawVtxBuffer(), IdxBuffer = {}, ZBuffer = {}, IdxSize = 0, ZSize = 0,
                _VtxCurrentIdx = 0, _VtxWritePtr = 1, _IdxWritePtr = 1, _ZWritePtr = 1,
                _Flags = 0, _SharedData = nil, _Order = {},
            }, DL3)
            return self
        end

        function DL3:ResetBuffers()
            self.VtxBuffer.Size = 0
            self.IdxSize, self.ZSize = 0, 0
            self._VtxCurrentIdx = 0
            self._VtxWritePtr, self._IdxWritePtr, self._ZWritePtr = 1, 1, 1
        end

        function DL3:PrimReserve(idx_count, vtx_count)
            IM_ASSERT(idx_count >= 0 and vtx_count >= 0 and idx_count % 3 == 0)
            local vb = self.VtxBuffer
            local old = vb.Size
            vb:resize(old + vtx_count)
            self._VtxWritePtr = old + 1
            self._IdxWritePtr = self.IdxSize + 1
            self.IdxSize += idx_count
            self._ZWritePtr = self.ZSize + 1
            self.ZSize += idx_count // 3
        end

        function DL3:PrimUnreserve(idx_count, vtx_count)
            self.VtxBuffer.Size -= vtx_count
            self.IdxSize -= idx_count
            self.ZSize -= idx_count // 3
        end

        -- Move triangles to the current window draw list, sorted by depth
        function DL3:SortedMoveToImGuiDrawList()
            local draw_list = ImGui.GetWindowDrawList()
            local tri_count = self.ZSize
            if tri_count == 0 then
                self:ResetBuffers()
                return
            end
            -- Sort triangle indices by z (distance from viewer)
            local order, Z = self._Order, self.ZBuffer
            for i = 1, tri_count do order[i] = i end
            for i = #order, tri_count + 1, -1 do order[i] = nil end
            table.sort(order, function(a, b) return Z[a] < Z[b] end)

            local vtx_count = self.VtxBuffer.Size
            draw_list:PrimReserve(self.IdxSize, vtx_count)
            -- Copy vertices (no reordering needed)
            local stride = G.VTX_STRIDE or 36
            buffer.copy(draw_list.VtxBuffer.Buf, (draw_list._VtxWritePtr - 1) * stride, self.VtxBuffer.Buf, 0, vtx_count * stride)
            local idx_offset = draw_list._VtxCurrentIdx
            draw_list._VtxWritePtr += vtx_count
            draw_list._VtxCurrentIdx += vtx_count
            local max_index_allowed = MAX_IDX - idx_offset
            -- Copy indices with triangle sorting
            local idx_in, idx_out, iw = self.IdxBuffer, draw_list.IdxBuffer.Data, draw_list._IdxWritePtr
            local skipped = 0
            for i = 1, tri_count do
                local base = (order[i] - 1) * 3
                local i0, i1, i2 = idx_in[base + 1], idx_in[base + 2], idx_in[base + 3]
                if i0 > max_index_allowed or i1 > max_index_allowed or i2 > max_index_allowed then
                    skipped += 3
                else
                    idx_out[iw] = i0 + idx_offset; idx_out[iw + 1] = i1 + idx_offset; idx_out[iw + 2] = i2 + idx_offset
                    iw += 3
                end
            end
            draw_list._IdxWritePtr = iw
            if skipped > 0 then
                -- [Port] upstream leaves the skipped indices reserved; give them back so ElemCount stays exact
                draw_list.IdxBuffer:shrink(draw_list.IdxBuffer.Size - skipped)
                draw_list.CmdBuffer.Data[draw_list.CmdBuffer.Size].ElemCount -= skipped
            end
            self:ResetBuffers()
        end
    end

    --------------------------------------------------------------------------
    -- [SECTION] Begin/End Plot
    --------------------------------------------------------------------------
    do
        local Flags = ImPlot3D.ImPlot3DFlags

        function ImPlot3D.BeginPlot(title_id, size, flags)
            size = size or ImVec2(-1, 0)
            flags = flags or 0
            local gp = GImPlot3D
            IM_ASSERT(gp ~= nil, "No current context. Did you call ImPlot3D::CreateContext() or ImPlot3D::SetCurrentContext()?")
            IM_ASSERT(gp.CurrentPlot == nil, "Mismatched BeginPlot()/EndPlot()!")
            local window = ImGui.GetCurrentWindow()
            -- Skip if needed
            if window.SkipItems then return false end
            -- Get or create plot
            local ID = window:GetID(title_id)
            local just_created = gp.Plots:GetByKey(ID) == nil
            gp.CurrentPlot = gp.Plots:GetOrAddByKey(ID)
            local plot = gp.CurrentPlot
            gp.CurrentItems = plot.Items
            -- Populate plot
            plot.ID = ID
            plot.Items.ID = ID - 1
            plot.JustCreated = just_created
            if just_created then
                plot.Rotation = plot.InitialRotation
                plot.FitThisFrame = true
                for i = 0, 2 do
                    plot.Axes[i] = internal.ImPlot3DAxis()
                    plot.Axes[i].FitThisFrame = true
                end
            end
            if plot.PreviousFlags ~= flags then plot.Flags = flags end
            plot.PreviousFlags = flags
            plot.SetupLocked = false
            plot.OpenContextThisFrame = false
            plot.RotationCond = ImPlot3D.ImPlot3DCond.None
            -- Populate title
            plot:SetTitle(title_id)
            -- Calculate frame size
            local style = gp.Style
            local frame_size = ImGui.CalcItemSize(size, style.PlotDefaultSize.x, style.PlotDefaultSize.y)
            if frame_size.x < style.PlotMinSize.x and size.x < 0.0 then frame_size.x = style.PlotMinSize.x end
            if frame_size.y < style.PlotMinSize.y and size.y < 0.0 then frame_size.y = style.PlotMinSize.y end
            -- Create plot ImGui item
            local cursor = window.DC.CursorPos
            plot.FrameRect = G.ImRect(ImVec2(cursor.x, cursor.y), cursor + frame_size)
            ImGui.ItemSize(plot.FrameRect)
            if not ImGui.ItemAdd(plot.FrameRect, plot.ID, plot.FrameRect) then
                gp.CurrentPlot, gp.CurrentItems, gp.CurrentItem = nil, nil, nil
                return false
            end
            -- Reset legend
            local legend = plot.Items.Legend
            table.clear(legend.Indices)
            table.clear(legend.LabelList)
            -- Reset axes
            for i = 0, 2 do plot.Axes[i]:Reset() end
            -- Push frame rect clipping
            ImGui.PushClipRect(plot.FrameRect.Min, plot.FrameRect.Max, true)
            -- Setup 3D draw list
            plot.DrawList._Flags = window.DrawList.Flags
            plot.DrawList._SharedData = ImGui.GetDrawListSharedData()
            return true
        end

        function ImPlot3D.EndPlot()
            local gp = GImPlot3D
            IM_ASSERT(gp ~= nil, "No current context. Did you call ImPlot3D::CreateContext() or ImPlot3D::SetCurrentContext()?")
            IM_ASSERT(gp.CurrentPlot ~= nil, "Mismatched BeginPlot()/EndPlot()!")
            local plot = gp.CurrentPlot
            -- Move triangles from 3D draw list to ImGui draw list
            plot.DrawList:SortedMoveToImGuiDrawList()
            -- Handle data fitting
            if plot.FitThisFrame then
                plot.FitThisFrame = false
                if not internal.ImHasFlag(plot.Flags, Flags.Equal) then
                    -- Apply fit to all axes independently
                    for i = 0, 2 do
                        local axis = plot.Axes[i]
                        if axis.FitThisFrame then
                            axis.FitThisFrame = false
                            axis:ApplyFit()
                        end
                    end
                else
                    -- Fit all axes, then use the one with the highest aspect ratio (units per NDC unit) as reference
                    local ref_axis, max_aspect = 0, 0.0
                    for i = 0, 2 do
                        local axis = plot.Axes[i]
                        if axis.FitThisFrame then
                            axis.FitThisFrame = false
                            axis:ApplyFit()
                            local aspect = axis:GetAspect()
                            if aspect > max_aspect then max_aspect, ref_axis = aspect, i end
                        end
                    end
                    plot:ApplyEqualAspect(ref_axis)
                end
            end
            -- Lock setup if not already done
            ImPlot3D.SetupLock()
            -- Pop plot rect clipping
            ImGui.PopClipRect()
            -- Reset legend hover
            plot.Items.Legend.Hovered = false
            -- Render legend
            internal.RenderLegend()
            -- Mouse position text and context menus
            internal.ShowPlotPopups(plot)
            -- Pop frame rect clipping
            ImGui.PopClipRect()
            -- Reset current plot
            gp.CurrentPlot, gp.CurrentItems, gp.CurrentItem = nil, nil, nil
            -- Reset the plot items for the next frame
            for _, item in plot.Items.ItemPool.Buf do
                if item then item.SeenThisFrame = false end
            end
        end

        local function CurrentPlot(name)
            local gp = GImPlot3D
            IM_ASSERT(gp.CurrentPlot ~= nil, name .. "() needs to be called between BeginPlot() and EndPlot()!")
            return gp.CurrentPlot
        end

        function ImPlot3D.GetPlotRectPos()
            local plot = CurrentPlot("GetPlotRectPos")
            ImPlot3D.SetupLock()
            return plot.PlotRect.Min
        end

        function ImPlot3D.GetPlotRectSize()
            local plot = CurrentPlot("GetPlotRectSize")
            ImPlot3D.SetupLock()
            return plot.PlotRect:GetSize()
        end

        function ImPlot3D.GetFramePos() return CurrentPlot("GetFramePos").FrameRect.Min end
        function ImPlot3D.GetFrameSize() return CurrentPlot("GetFrameSize").FrameRect:GetSize() end
        function ImPlot3D.GetPlotDrawList() return ImGui.GetWindowDrawList() end
    end

    return ImPlot3D
end
