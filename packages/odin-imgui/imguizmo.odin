package imgui

when      ODIN_OS == .Windows { when ODIN_ARCH == .amd64 { foreign import lib "imgui_windows_x64.lib" } else { foreign import lib "imgui_windows_arm64.lib" } }
else when ODIN_OS == .Linux   { when ODIN_ARCH == .amd64 { foreign import lib "imgui_linux_x64.a" }     else { foreign import lib "imgui_linux_arm64.a" } }
else when ODIN_OS == .Darwin  { when ODIN_ARCH == .amd64 { foreign import lib "imgui_darwin_x64.a" }    else { foreign import lib "imgui_darwin_arm64.a" } }

OPERATION :: enum {
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

MODE :: enum {
    LOCAL,
    WORLD,
}

foreign lib {
    ImGuizmo_SetDrawlist                  :: proc(drawlist: ^DrawList) ---
    ImGuizmo_BeginFrame                   :: proc() ---
    ImGuizmo_SetImGuiContext              :: proc(ctx: ^Context) ---
    ImGuizmo_IsOver_Nil                   :: proc() ---
    ImGuizmo_IsUsing                      :: proc() ---
    ImGuizmo_IsUsingAny                   :: proc() ---
    ImGuizmo_Enable                       :: proc(enable: bool) ---
    ImGuizmo_DecomposeMatrixToComponents  :: proc(m, translation, rotation: [^]f32, scale: [^]f32) ---
    // ImGuizmo_RecomposeMatrixFromComponents:: proc(translation,rotation,scale: ,float* matrix);
    // ImGuizmo_SetRect                      :: proc(float x,float y,float width,float height);
    // ImGuizmo_SetOrthographic              :: proc(bool isOrthographic);
    // ImGuizmo_DrawCubes                    :: proc(const float* view,const float* projection,const float* matrices,int matrixCount);
    // ImGuizmo_DrawGrid                     :: proc(const float* view,const float* projection,const float* matrix,const float gridSize);
    ImGuizmo_Manipulate                   :: proc(view,projection: [^]f32, operation: OPERATION ,mode: MODE ,m: [^]f32,deltaMatrix: [^]f32, snap,localBounds,boundsSnap: [^]f32) -> bool ---
    // ImGuizmo_ViewManipulate_Float         :: proc(view: [^]f32,float length,ImVec2 position,ImVec2 size,ImU32 backgroundColor);
    // ImGuizmo_ViewManipulate_FloatPtr      :: proc(view: [^]f32,const float* projection,OPERATION operation,MODE mode,float* matrix,float length,ImVec2 position,ImVec2 size,ImU32 backgroundColor);
    // ImGuizmo_SetID                        :: proc(id: i32);
    ImGuizmo_IsOver_OPERATION             :: proc(op: OPERATION) ---
    ImGuizmo_SetGizmoSizeClipSpace        :: proc(value: f32) ---
    ImGuizmo_AllowAxisFlip                :: proc(value: bool) ---
    ImGuizmo_SetAxisLimit                 :: proc(value: f32) ---
    ImGuizmo_SetPlaneLimit                :: proc(value: f32) ---
}
