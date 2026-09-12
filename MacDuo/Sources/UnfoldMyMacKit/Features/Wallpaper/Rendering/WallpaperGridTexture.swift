import Metal
import UnfoldMyMacCore

/// Immutable replacement textures keep in-flight frames safe. No upload on a heartbeat.
@MainActor final class WallpaperGridTexture {
    private let device: MTLDevice
    private let empty: MTLTexture
    private var current: MTLTexture?
    private var revision: String?
    private(set) var uploadCount = 0
    init(device: MTLDevice) throws {
        self.device = device
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float, width: 1, height: 1, mipmapped: false)
        descriptor.usage = .shaderRead; descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else { throw WallpaperError.unavailable("Could not create a data texture.") }
        var zero: Float = 0
        texture.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: &zero, bytesPerRow: 4)
        empty = texture
    }
    func texture(for grid: WallpaperScalarGrid?) -> MTLTexture {
        guard let grid else { return empty }
        if revision == grid.revision, let current, current.width == grid.width, current.height == grid.height { return current }
        guard grid.isValid else { return empty }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float, width: grid.width, height: grid.height, mipmapped: false)
        descriptor.usage = .shaderRead; descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else { return empty }
        grid.values.withUnsafeBytes { bytes in
            texture.replace(region: MTLRegionMake2D(0, 0, grid.width, grid.height), mipmapLevel: 0,
                            withBytes: bytes.baseAddress!, bytesPerRow: grid.width * 4)
        }
        current = texture; revision = grid.revision; uploadCount += 1
        return texture
    }
}
