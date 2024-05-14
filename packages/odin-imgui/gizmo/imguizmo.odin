package gizmo
import imgui "../"
import "core:c"

when      ODIN_OS == .Windows { when ODIN_ARCH == .amd64 { foreign import lib "../imgui_windows_x64.lib" } else { foreign import lib "../imgui_windows_arm64.lib" } }
else when ODIN_OS == .Linux   { when ODIN_ARCH == .amd64 { foreign import lib "../imgui_linux_x64.a" }     else { foreign import lib "../imgui_linux_arm64.a" } }
else when ODIN_OS == .Darwin  { when ODIN_ARCH == .amd64 { foreign import lib "../imgui_darwin_x64.a" }    else { foreign import lib "../imgui_darwin_arm64.a" } }

OPERATION :: enum i32 {
    TRANSLATE_X      = (1 << 0),
    TRANSLATE_Y      = (1 << 1),
    TRANSLATE_Z      = (1 << 2),
    ROTATE_X         = (1 << 3),
    ROTATE_Y         = (1 << 4),
    ROTATE_Z         = (1 << 5),
    ROTATE_SCREEN    = (1 << 6),
    SCALE_X          = (1 << 7),
    SCALE_Y          = (1 << 8),
    SCALE_Z          = (1 << 9),
    BOUNDS           = (1 << 10),
    SCALE_XU         = (1 << 11),
    SCALE_YU         = (1 << 12),
    SCALE_ZU         = (1 << 13),

    TRANSLATE = TRANSLATE_X | TRANSLATE_Y | TRANSLATE_Z,
    ROTATE = ROTATE_X | ROTATE_Y | ROTATE_Z | ROTATE_SCREEN,
    SCALE = SCALE_X | SCALE_Y | SCALE_Z,
    SCALEU = SCALE_XU | SCALE_YU | SCALE_ZU, // universal
    UNIVERSAL = TRANSLATE | ROTATE | SCALEU
}

@(init)
_ :: proc() {
    assert(cast(i32)OPERATION.TRANSLATE == 7)
}

MODE :: enum i32 {
    LOCAL,
    WORLD,
}

@(link_prefix="ImGuizmo_")
foreign lib {
    SetDrawlist                   :: proc(drawlist: ^imgui.DrawList) ---
    BeginFrame                    :: proc() ---
    SetImGuiContext               :: proc(ctx: ^imgui.Context) ---
    IsOver_Nil                    :: proc() ---
    IsUsing                       :: proc() ---
    IsUsingAny                    :: proc() ---
    Enable                        :: proc(enable: bool) ---
    DecomposeMatrixToComponents   :: proc(m, translation, rotation: [^]f32, scale: [^]f32) ---
    RecomposeMatrixFromComponents :: proc(translation, rotation, scale: [^]f32, m: [^]f32) ---
    SetRect                       :: proc(x, y, width, height: f32) ---
    SetOrthographic               :: proc(isOrthographic: bool) ---
    DrawCubes                     :: proc(view, projection: [^]f32, matrices: [^]f32, matrixCount: c.int) ---
    DrawGrid                      :: proc(view, projection, _matrix: [^]f32, gridSize: f32) ---
    Manipulate                    :: proc(view, projection: [^]f32, operation: OPERATION, mode: MODE, m: [^]f32, deltaMatrix: [^]f32 = nil, snap: [^]f32 = nil, localBounds: [^]f32 = nil, boundsSnap: [^]f32 = nil) -> b32 ---
    ViewManipulate_Float          :: proc(view: [^]f32, length: f32, position, size: [2]f32, backgroundColor: u32) ---
    ViewManipulate_FloatPtr       :: proc(view: [^]f32, projection: [^]f32, operation: OPERATION, mode: MODE, _matrix: [^]f32, length: f32, position: [2]f32, size: [2]f32, backgroundColor: u32) ---
    SetID                         :: proc(id: i32) ---
    IsOverEx                      :: proc(op: OPERATION) ---
    SetGizmoSizeClipSpace         :: proc(value: f32) ---
    AllowAxisFlip                 :: proc(value: bool) ---
    SetAxisLimit                  :: proc(value: f32) ---
    SetPlaneLimit                 :: proc(value: f32) ---
}
