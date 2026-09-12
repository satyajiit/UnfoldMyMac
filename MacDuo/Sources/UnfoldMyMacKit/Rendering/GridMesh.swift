import simd

/// A unit UV grid as triangles; instanced by cloth, pillow and sphere shaders.
struct GridMesh {
    let points: [SIMD2<Float>]
    let triangles: [UInt32]
    init(columns: Int, rows: Int) {
        var points: [SIMD2<Float>] = []
        var triangles: [UInt32] = []
        points.reserveCapacity((rows + 1) * (columns + 1)); triangles.reserveCapacity(rows * columns * 6)
        for row in 0...rows { for column in 0...columns { points.append(SIMD2(Float(column) / Float(columns), Float(row) / Float(rows))) } }
        for row in 0..<rows { for column in 0..<columns {
            let a = UInt32(row * (columns + 1) + column), b = a + 1
            let c = a + UInt32(columns + 1), d = c + 1
            triangles.append(contentsOf: [a, b, c, b, d, c])
        } }
        self.points = points; self.triangles = triangles
    }
}
