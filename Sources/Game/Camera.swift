import simd

public struct Camera {
    public var position: SIMD3<Float>
    public var yaw: Float    // поворот по горизонтали (радианы)
    public var pitch: Float  // наклон, ограничен [-90°, +90°]

    public static let reachDistance: Float = 5.0  // Reach_Distance (Req 4/5)

    public init(position: SIMD3<Float> = SIMD3<Float>(0, 60, 0),
                yaw: Float = 0, pitch: Float = 0) {
        self.position = position
        self.yaw = yaw
        self.pitch = pitch
    }

    public var forward: SIMD3<Float> {
        SIMD3<Float>(
            cos(pitch) * sin(yaw),
            sin(pitch),
            cos(pitch) * cos(yaw)
        )
    }

    public var right: SIMD3<Float> {
        SIMD3<Float>(sin(yaw - .pi / 2), 0, cos(yaw - .pi / 2))
    }

    public func viewProjection(aspect: Float) -> simd_float4x4 {
        let view = Camera.lookAt(eye: position, center: position + forward,
                                 up: SIMD3<Float>(0, 1, 0))
        let proj = Camera.perspective(fovYRadians: 1.2, aspect: aspect,
                                      near: 0.05, far: 500)
        return proj * view
    }

    static func lookAt(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
        let f = simd_normalize(center - eye)
        let s = simd_normalize(simd_cross(f, up))
        let u = simd_cross(s, f)
        return simd_float4x4(columns: (
            SIMD4<Float>(s.x, u.x, -f.x, 0),
            SIMD4<Float>(s.y, u.y, -f.y, 0),
            SIMD4<Float>(s.z, u.z, -f.z, 0),
            SIMD4<Float>(-simd_dot(s, eye), -simd_dot(u, eye), simd_dot(f, eye), 1)
        ))
    }

    static func perspective(fovYRadians: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
        let yScale = 1 / tan(fovYRadians * 0.5)
        let xScale = yScale / aspect
        let zRange = far - near
        return simd_float4x4(columns: (
            SIMD4<Float>(xScale, 0, 0, 0),
            SIMD4<Float>(0, yScale, 0, 0),
            SIMD4<Float>(0, 0, -(far + near) / zRange, -1),
            SIMD4<Float>(0, 0, -2 * far * near / zRange, 0)
        ))
    }
}
