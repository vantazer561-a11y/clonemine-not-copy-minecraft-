import Metal
import MetalKit
import simd

struct Uniforms {
    var viewProjection: simd_float4x4
    var cameraPos: SIMD4<Float>   // xyz = позиция камеры
    var sunDir: SIMD4<Float>      // xyz = направление на солнце
    var sunColor: SIMD4<Float>    // rgb = цвет солнца
    var skyColor: SIMD4<Float>    // rgb = цвет неба, w = плотность тумана
    var params: SIMD4<Float>      // x = time
}

struct EntityUniforms {
    var mvp: simd_float4x4
    var color: SIMD4<Float>
    var sunDir: SIMD4<Float>      // xyz = направление на солнце
}

/// Metal-рендер воксельного мира от первого лица. Requirement 7.
final class Renderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private var pipeline: MTLRenderPipelineState!
    private var skyPipeline: MTLRenderPipelineState!
    private var entityPipeline: MTLRenderPipelineState!
    private var hudPipeline: MTLRenderPipelineState!
    private var depthState: MTLDepthStencilState!
    private var skyDepthState: MTLDepthStencilState!
    private var cubeBuffer: MTLBuffer!

    private struct ChunkBuffers {
        let vertexBuffer: MTLBuffer
        let indexBuffer: MTLBuffer
        let indexCount: Int
    }
    private var chunkBuffers: [ChunkCoord: ChunkBuffers] = [:]

    private let game: GameState
    private var lastTime: CFTimeInterval = CACurrentMediaTime()
    var viewSize: CGSize = .zero

    init?(mtkView: MTKView, game: GameState) {
        guard let device = mtkView.device ?? MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else { return nil }
        self.device = device
        self.queue = queue
        self.game = game
        super.init()

        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0.53, green: 0.78, blue: 0.92, alpha: 1)

        guard buildPipelines(view: mtkView) else { return nil }

        let depthDesc = MTLDepthStencilDescriptor()
        depthDesc.depthCompareFunction = .less
        depthDesc.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: depthDesc)

        // Небо: пишем на дальней плоскости, не затирая буфер глубины мира.
        let skyDepth = MTLDepthStencilDescriptor()
        skyDepth.depthCompareFunction = .lessEqual
        skyDepth.isDepthWriteEnabled = false
        skyDepthState = device.makeDepthStencilState(descriptor: skyDepth)

        cubeBuffer = device.makeBuffer(bytes: CubeMesh.vertices,
                                       length: MemoryLayout<EntityVertex>.stride * CubeMesh.vertices.count,
                                       options: [])
    }

    private func buildPipelines(view: MTKView) -> Bool {
        guard let library = device.makeDefaultLibrary() else { return false }

        // Воксельный мир
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = library.makeFunction(name: "voxel_vertex")
        desc.fragmentFunction = library.makeFunction(name: "voxel_fragment")
        desc.colorAttachments[0].pixelFormat = view.colorPixelFormat
        desc.depthAttachmentPixelFormat = .depth32Float

        let vd = MTLVertexDescriptor()
        vd.attributes[0].format = .float3
        vd.attributes[0].offset = 0
        vd.attributes[0].bufferIndex = 0
        vd.attributes[1].format = .float3
        vd.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        vd.attributes[1].bufferIndex = 0
        vd.attributes[2].format = .float4
        vd.attributes[2].offset = MemoryLayout<SIMD3<Float>>.stride * 2
        vd.attributes[2].bufferIndex = 0
        vd.layouts[0].stride = MemoryLayout<VoxelVertex>.stride
        desc.vertexDescriptor = vd

        // Небо
        let skyDesc = MTLRenderPipelineDescriptor()
        skyDesc.vertexFunction = library.makeFunction(name: "sky_vertex")
        skyDesc.fragmentFunction = library.makeFunction(name: "sky_fragment")
        skyDesc.colorAttachments[0].pixelFormat = view.colorPixelFormat
        skyDesc.depthAttachmentPixelFormat = .depth32Float

        // Сущности (животные / подсветка)
        let entDesc = MTLRenderPipelineDescriptor()
        entDesc.vertexFunction = library.makeFunction(name: "entity_vertex")
        entDesc.fragmentFunction = library.makeFunction(name: "entity_fragment")
        entDesc.colorAttachments[0].pixelFormat = view.colorPixelFormat
        entDesc.depthAttachmentPixelFormat = .depth32Float
        // Альфа-смешивание для полупрозрачной подсветки.
        entDesc.colorAttachments[0].isBlendingEnabled = true
        entDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        entDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        entDesc.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        entDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        let evd = MTLVertexDescriptor()
        evd.attributes[0].format = .float3
        evd.attributes[0].offset = 0
        evd.attributes[0].bufferIndex = 0
        evd.attributes[1].format = .float3
        evd.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        evd.attributes[1].bufferIndex = 0
        evd.layouts[0].stride = MemoryLayout<EntityVertex>.stride
        entDesc.vertexDescriptor = evd

        // HUD
        let hudDesc = MTLRenderPipelineDescriptor()
        hudDesc.vertexFunction = library.makeFunction(name: "hud_vertex")
        hudDesc.fragmentFunction = library.makeFunction(name: "hud_fragment")
        hudDesc.colorAttachments[0].pixelFormat = view.colorPixelFormat
        hudDesc.depthAttachmentPixelFormat = .depth32Float

        do {
            pipeline = try device.makeRenderPipelineState(descriptor: desc)
            skyPipeline = try device.makeRenderPipelineState(descriptor: skyDesc)
            entityPipeline = try device.makeRenderPipelineState(descriptor: entDesc)
            hudPipeline = try device.makeRenderPipelineState(descriptor: hudDesc)
            return true
        } catch {
            print("Pipeline error: \(error)")
            return false
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewSize = size
    }

    private func rebuildDirtyChunks() {
        for coord in game.world.consumeDirtyChunks() {
            guard let chunk = game.world.chunk(at: coord) else {
                chunkBuffers[coord] = nil
                continue
            }
            let mesh = ChunkMesher.buildMesh(for: chunk, world: game.world)
            guard !mesh.vertices.isEmpty else {
                chunkBuffers[coord] = nil
                continue
            }
            let vBuf = device.makeBuffer(bytes: mesh.vertices,
                                         length: MemoryLayout<VoxelVertex>.stride * mesh.vertices.count,
                                         options: [])!
            let iBuf = device.makeBuffer(bytes: mesh.indices,
                                         length: MemoryLayout<UInt32>.stride * mesh.indices.count,
                                         options: [])!
            chunkBuffers[coord] = ChunkBuffers(vertexBuffer: vBuf, indexBuffer: iBuf,
                                               indexCount: mesh.indices.count)
        }
    }

    private func makeUniforms() -> Uniforms {
        let aspect = viewSize.height > 0 ? Float(viewSize.width / viewSize.height) : 1
        let cam = game.camera.position
        let sun = game.sky.sunDirection
        let sc = game.sky.sunColor
        let sky = game.sky.skyColor
        return Uniforms(
            viewProjection: game.camera.viewProjection(aspect: aspect),
            cameraPos: SIMD4<Float>(cam.x, cam.y, cam.z, 0),
            sunDir: SIMD4<Float>(sun.x, sun.y, sun.z, 0),
            sunColor: SIMD4<Float>(sc.x, sc.y, sc.z, 1),
            skyColor: SIMD4<Float>(sky.x, sky.y, sky.z, 0.012),
            params: SIMD4<Float>(game.sky.time, 0, 0, 0)
        )
    }

    func draw(in view: MTKView) {
        let now = CACurrentMediaTime()
        let dt = Float(min(now - lastTime, 0.05))
        lastTime = now

        game.update(dt: dt)
        rebuildDirtyChunks()

        // Цвет очистки следует за цветом неба (плавная смена дня/ночи).
        let sc = game.sky.skyColor
        view.clearColor = MTLClearColor(red: Double(sc.x), green: Double(sc.y),
                                        blue: Double(sc.z), alpha: 1)

        guard let drawable = view.currentDrawable,
              let rpd = view.currentRenderPassDescriptor,
              let cmd = queue.makeCommandBuffer(),
              let enc = cmd.makeRenderCommandEncoder(descriptor: rpd) else { return }

        var uniforms = makeUniforms()

        // 1) Небо + солнце
        enc.setRenderPipelineState(skyPipeline)
        enc.setDepthStencilState(skyDepthState)
        enc.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

        // 2) Воксельный мир
        enc.setRenderPipelineState(pipeline)
        enc.setDepthStencilState(depthState)
        enc.setCullMode(.back)
        enc.setFrontFacing(.counterClockwise)
        enc.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        enc.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        for buffers in chunkBuffers.values {
            enc.setVertexBuffer(buffers.vertexBuffer, offset: 0, index: 0)
            enc.drawIndexedPrimitives(type: .triangle, indexCount: buffers.indexCount,
                                      indexType: .uint32, indexBuffer: buffers.indexBuffer,
                                      indexBufferOffset: 0)
        }

        // 3) Животные
        drawAnimals(enc, uniforms: uniforms)

        // 4) Подсветка целевого блока (Req 7.3)
        drawHighlight(enc, uniforms: uniforms)

        // 5) Прицел
        drawCrosshair(enc)

        enc.endEncoding()
        cmd.present(drawable)
        cmd.commit()
    }

    private func drawAnimals(_ enc: MTLRenderCommandEncoder, uniforms: Uniforms) {
        enc.setRenderPipelineState(entityPipeline)
        enc.setDepthStencilState(depthState)
        enc.setVertexBuffer(cubeBuffer, offset: 0, index: 0)
        for animal in game.animals.animals {
            let s = animal.kind.size
            // Куб строится в [0,1]; смещаем по X/Z так, чтобы центр совпал с position.
            let origin = SIMD3<Float>(animal.position.x - s.x * 0.5,
                                      animal.position.y,
                                      animal.position.z - s.z * 0.5)
            let model = makeTranslationScale(translation: origin, scale: s)
            var eu = EntityUniforms(mvp: uniforms.viewProjection * model,
                                    color: animal.kind.color,
                                    sunDir: uniforms.sunDir)            enc.setVertexBytes(&eu, length: MemoryLayout<EntityUniforms>.stride, index: 1)
            enc.setFragmentBytes(&eu, length: MemoryLayout<EntityUniforms>.stride, index: 1)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: CubeMesh.vertices.count)
        }
    }

    private func drawHighlight(_ enc: MTLRenderCommandEncoder, uniforms: Uniforms) {
        guard let hit = game.currentTarget else { return }
        let b = hit.blockCoord
        let scale: Float = 1.04
        let off = (scale - 1) * 0.5
        let origin = SIMD3<Float>(Float(b.x) - off, Float(b.y) - off, Float(b.z) - off)
        let model = makeTranslationScale(translation: origin,
                                         scale: SIMD3<Float>(scale, scale, scale))
        var eu = EntityUniforms(mvp: uniforms.viewProjection * model,
                                color: SIMD4<Float>(0, 0, 0, 0.28),
                                sunDir: uniforms.sunDir)
        enc.setRenderPipelineState(entityPipeline)
        enc.setDepthStencilState(depthState)
        enc.setVertexBuffer(cubeBuffer, offset: 0, index: 0)
        enc.setVertexBytes(&eu, length: MemoryLayout<EntityUniforms>.stride, index: 1)
        enc.setFragmentBytes(&eu, length: MemoryLayout<EntityUniforms>.stride, index: 1)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: CubeMesh.vertices.count)
    }

    // Прицел в центре экрана (Requirement 7.2).
    private func drawCrosshair(_ enc: MTLRenderCommandEncoder) {
        let s: Float = 0.014
        let aspect = viewSize.height > 0 ? Float(viewSize.width / viewSize.height) : 1
        let sx = s / aspect
        var verts: [SIMD2<Float>] = [
            SIMD2<Float>(-sx, 0), SIMD2<Float>(sx, 0),
            SIMD2<Float>(0, -s),  SIMD2<Float>(0, s),
        ]
        enc.setRenderPipelineState(hudPipeline)
        enc.setVertexBytes(&verts, length: MemoryLayout<SIMD2<Float>>.stride * verts.count, index: 0)
        enc.drawPrimitives(type: .line, vertexStart: 0, vertexCount: verts.count)
    }
}
