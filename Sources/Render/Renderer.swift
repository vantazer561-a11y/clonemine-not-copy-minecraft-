import Metal
import MetalKit
import simd

struct Uniforms {
    var viewProjection: simd_float4x4
}

/// Metal-рендер воксельного мира от первого лица. Requirement 7.
final class Renderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private var pipeline: MTLRenderPipelineState!
    private var hudPipeline: MTLRenderPipelineState!
    private var depthState: MTLDepthStencilState!

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
    }

    private func buildPipelines(view: MTKView) -> Bool {
        guard let library = device.makeDefaultLibrary() else { return false }

        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = library.makeFunction(name: "voxel_vertex")
        desc.fragmentFunction = library.makeFunction(name: "voxel_fragment")
        desc.colorAttachments[0].pixelFormat = view.colorPixelFormat
        desc.depthAttachmentPixelFormat = .depth32Float

        let vd = MTLVertexDescriptor()
        // position
        vd.attributes[0].format = .float3
        vd.attributes[0].offset = 0
        vd.attributes[0].bufferIndex = 0
        // normal
        vd.attributes[1].format = .float3
        vd.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        vd.attributes[1].bufferIndex = 0
        // color
        vd.attributes[2].format = .float4
        vd.attributes[2].offset = MemoryLayout<SIMD3<Float>>.stride * 2
        vd.attributes[2].bufferIndex = 0
        vd.layouts[0].stride = MemoryLayout<VoxelVertex>.stride
        desc.vertexDescriptor = vd

        let hudDesc = MTLRenderPipelineDescriptor()
        hudDesc.vertexFunction = library.makeFunction(name: "hud_vertex")
        hudDesc.fragmentFunction = library.makeFunction(name: "hud_fragment")
        hudDesc.colorAttachments[0].pixelFormat = view.colorPixelFormat
        hudDesc.depthAttachmentPixelFormat = .depth32Float

        do {
            pipeline = try device.makeRenderPipelineState(descriptor: desc)
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

    func draw(in view: MTKView) {
        let now = CACurrentMediaTime()
        let dt = Float(min(now - lastTime, 0.05))
        lastTime = now

        game.update(dt: dt)
        rebuildDirtyChunks()

        guard let drawable = view.currentDrawable,
              let rpd = view.currentRenderPassDescriptor,
              let cmd = queue.makeCommandBuffer(),
              let enc = cmd.makeRenderCommandEncoder(descriptor: rpd) else { return }

        let aspect = viewSize.height > 0 ? Float(viewSize.width / viewSize.height) : 1
        var uniforms = Uniforms(viewProjection: game.camera.viewProjection(aspect: aspect))

        enc.setRenderPipelineState(pipeline)
        enc.setDepthStencilState(depthState)
        enc.setCullMode(.back)
        enc.setFrontFacing(.counterClockwise)
        enc.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)

        for buffers in chunkBuffers.values {
            enc.setVertexBuffer(buffers.vertexBuffer, offset: 0, index: 0)
            enc.drawIndexedPrimitives(type: .triangle, indexCount: buffers.indexCount,
                                      indexType: .uint32, indexBuffer: buffers.indexBuffer,
                                      indexBufferOffset: 0)
        }

        drawCrosshair(enc)

        enc.endEncoding()
        cmd.present(drawable)
        cmd.commit()
    }

    // Прицел в центре экрана (Requirement 7.2).
    private func drawCrosshair(_ enc: MTLRenderCommandEncoder) {
        let s: Float = 0.012
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
