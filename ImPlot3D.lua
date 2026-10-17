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
        -- [Port] NextItemData added with the item milestone.
        function internal.ImPlot3DContext()
            return {
                Plots = G.ImPool(function() return internal.ImPlot3DPlot() end), -- ImPool<ImPlot3DPlot>
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
                Scroll = ImVec2(0, 0), Indices = {}, Labels = "",
                Rect = ImRect(), RectClamped = ImRect(), Hovered = false, Held = false,
            }
        end

        -- Holds items
        -- [Port] item methods (GetItem, GetOrAddItem, ...) come with the item milestone
        function internal.ImPlot3DItemGroup()
            return { ID = 0, ItemPool = G.ImPool(), Legend = internal.ImPlot3DLegend(), ColormapIdx = 0, MarkerIdx = 0 }
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
                DrawList = nil, -- [Port] ImDrawList3D, added with rendering
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

        -- [Port] ponytail: state-only SetupLock. Frame bg/title drawing, HandleInput, clip rect and RenderPlotBox
        -- are skipped until the rendering milestone; ticks use the plot rect as-is.
        function ImPlot3D.SetupLock()
            local gp = GImPlot3D
            IM_ASSERT(gp.CurrentPlot ~= nil, "SetupLock() needs to be called between BeginPlot() and EndPlot()!")
            local plot = gp.CurrentPlot
            if plot.SetupLocked then return end
            plot.SetupLocked = true
            -- Set default formatter/locator
            for i = 0, 2 do
                local axis = plot.Axes[i]
                if axis.Formatter == nil then
                    axis.Formatter = internal.Formatter_Default
                    if axis.FormatterData == nil then axis.FormatterData = internal.IMPLOT3D_LABEL_FORMAT end
                end
                if axis.Locator == nil then axis.Locator = internal.Locator_Default end
            end
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
            -- Handle animation
            if plot.AnimationTime > 0.0 then
                local dt = ImGui.GetIO().DeltaTime
                local t = math.clamp(dt / plot.AnimationTime, 0.0, 1.0)
                plot.AnimationTime = math.max(plot.AnimationTime - dt, 0.0)
                plot.Rotation = Q.Slerp(plot.Rotation, plot.RotationAnimationEnd, t)
            end
            plot.Initialized = true
        end

        function ImPlot3D.PlotToNDC(point) return internal.PlotToNDC(CurrentPlot("PlotToNDC"), point) end
        function ImPlot3D.NDCToPlot(point) return internal.NDCToPlot(CurrentPlot("NDCToPlot"), point) end
        function ImPlot3D.NDCToPixels(point) return internal.NDCToPixels(CurrentPlot("NDCToPixels"), point) end
        -- [Port] (point) / (x, y, z) overloads
        function ImPlot3D.PlotToPixels(x, y, z)
            if type(x) == "number" then x = P(x, y, z) end
            return ImPlot3D.NDCToPixels(ImPlot3D.PlotToNDC(x))
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
    end

    return ImPlot3D
end
