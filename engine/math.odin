package engine
import "core:math"
import "core:math/linalg"
import "core:math/noise"

get_quaternion_forward :: proc(rotation: quaternion128) -> Vector3 {
    return linalg.quaternion_mul_vector3(rotation, Vector3{0, 0, 1})
}

get_vector_forward :: proc(vector: Vector3) -> Vector3 {
    quat := linalg.quaternion_from_euler_angles(
        vector.y * math.RAD_PER_DEG,
        vector.x * math.RAD_PER_DEG,
        vector.z * math.RAD_PER_DEG,
        .YXZ)
    return linalg.quaternion_mul_vector3(quat, Vector3{0, 0, 1})
}

get_forward :: proc {
    get_quaternion_forward,
    get_vector_forward,
}