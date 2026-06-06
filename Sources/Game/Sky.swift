import simd

/// Солнце и суточный цикл. Управляет направлением света и цветом неба.
public final class Sky {
    /// Длительность полного цикла (день+ночь) в секундах.
    public static let dayLength: Float = 240

    public private(set) var time: Float = 60   // старт в "утро"

    public init() {}

    public func update(dt: Float) {
        time += dt
        if time > Sky.dayLength { time -= Sky.dayLength }
    }

    /// Угол солнца по небосводу [0, 2pi).
    public var sunAngle: Float {
        (time / Sky.dayLength) * 2 * .pi
    }

    /// Направление НА солнце (нормализованное). Солнце встаёт на востоке, садится на западе.
    public var sunDirection: SIMD3<Float> {
        let a = sunAngle
        return simd_normalize(SIMD3<Float>(cos(a), sin(a), 0.35))
    }

    /// Насколько сейчас "день" (1 = полдень, 0 = ночь).
    public var daylight: Float {
        max(0, sin(sunAngle))
    }

    public var sunColor: SIMD3<Float> {
        let d = daylight
        // Тёплый на восходе/закате, белый в полдень.
        let warm = SIMD3<Float>(1.0, 0.6, 0.3)
        let noon = SIMD3<Float>(1.0, 0.97, 0.85)
        let t = smoothstep(0.0, 0.5, d)
        return mix(warm, noon, t) * (0.25 + 0.75 * d)
    }

    public var skyColor: SIMD3<Float> {
        let d = daylight
        let night = SIMD3<Float>(0.05, 0.07, 0.13)
        let day = SIMD3<Float>(0.53, 0.78, 0.92)
        return mix(night, day, smoothstep(0.0, 0.4, d))
    }

    private func smoothstep(_ a: Float, _ b: Float, _ x: Float) -> Float {
        let t = max(0, min(1, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }

    private func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Float) -> SIMD3<Float> {
        a + (b - a) * t
    }
}
