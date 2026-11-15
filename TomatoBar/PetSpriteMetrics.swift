import AppKit

/// Apparent-size normalization for the legacy sprite pets.
///
/// The legacy 256×256 assets were authored as independent illustrations: the
/// character occupies a different fraction of each canvas and the transparent
/// padding differs per state. Drawing every image with `scaledToFit()` into the
/// same box therefore makes the pet change apparent size whenever the phase
/// changes. These metrics crop the transparent padding, ground every state on a
/// shared baseline, and let the view pick a consistent scale.
enum PetSpriteFit {
    enum Policy {
        /// Fit each state to the shared content box. Keeps the on-screen
        /// footprint stable when a close-up idle switches to a wide work scene.
        case eachState
        /// Use one pixels-per-point scale for the whole character. Keeps the
        /// artwork's own proportion between states, at the cost of a smaller
        /// footprint for wide shots.
        case perPet
    }

    /// Each state fills the same box, which is what the four-pet lineup needs:
    /// switching phase or pet should not visibly resize the companion.
    static let policy: Policy = .eachState

    static func scale(cellSize: CGSize, box: CGSize) -> CGFloat {
        guard cellSize.width > 0, cellSize.height > 0,
              box.width > 0, box.height > 0 else { return 1 }
        return min(box.width / cellSize.width, box.height / cellSize.height)
    }

    static func petScale(cellSizes: [CGSize], box: CGSize) -> CGFloat? {
        guard !cellSizes.isEmpty else { return nil }
        return cellSizes.map { scale(cellSize: $0, box: box) }.min()
    }
}

enum PetAlphaBounds {
    /// Bounding box of pixels whose alpha exceeds `threshold`, in top-left
    /// pixel coordinates. `pixels` is RGBA8 (`premultipliedLast`).
    static func bounds(in pixels: [UInt8], width: Int, height: Int,
                       bytesPerRow: Int? = nil, threshold: UInt8 = 8) -> CGRect? {
        guard width > 0, height > 0 else { return nil }
        let row = bytesPerRow ?? width * 4
        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1
        for y in 0..<height {
            let base = y * row
            for x in 0..<width {
                guard pixels[base + x * 4 + 3] > threshold else { continue }
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}

struct PetSpriteAsset {
    /// Content-cropped image. Strip assets keep their full width so equal-width
    /// frame slicing stays valid; only the shared vertical padding is trimmed.
    let image: NSImage
    /// Pixel size of the cropped image.
    let pixelSize: CGSize
    /// Pixel size of one frame (equal to `pixelSize` for single images).
    let cellSize: CGSize
    let frameCount: Int
}

final class PetSpriteMetrics {
    static let shared = PetSpriteMetrics()

    private var cache: [String: PetSpriteAsset] = [:]
    private var missing = Set<String>()

    private init() {}

    func asset(named name: String, frameCount: Int) -> PetSpriteAsset? {
        if let cached = cache[name] { return cached }
        if missing.contains(name) { return nil }
        let count = max(frameCount, 1)
        guard let asset = Self.makeAsset(named: name, frameCount: count) else {
            missing.insert(name)
            return nil
        }
        cache[name] = asset
        return asset
    }

    /// The scale at which every state of a pet fits the box (used by the
    /// `.perPet` policy; also the safe fallback when a state is unknown).
    func contentScale(for kind: PetKind, box: CGSize) -> CGFloat? {
        let cells = kind.legacyDisplayAssets.compactMap { entry in
            asset(named: entry.name, frameCount: entry.frames)?.cellSize
        }
        return PetSpriteFit.petScale(cellSizes: cells, box: box)
    }

    private static func makeAsset(named name: String, frameCount: Int) -> PetSpriteAsset? {
        guard let source = NSImage(named: name) else { return nil }
        var proposed = CGRect(origin: .zero, size: source.size)
        guard let cg = source.cgImage(forProposedRect: &proposed, context: nil, hints: nil),
              cg.width > 0, cg.height > 0,
              let bounds = alphaBounds(cg) else { return nil }

        let crop: CGRect
        let cell: CGSize
        if frameCount > 1 {
            crop = CGRect(x: 0, y: bounds.minY, width: CGFloat(cg.width), height: bounds.height)
            cell = CGSize(width: CGFloat(cg.width) / CGFloat(frameCount), height: bounds.height)
        } else {
            crop = bounds
            cell = bounds.size
        }
        guard let cropped = cg.cropping(to: crop) else { return nil }
        let image = NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
        return PetSpriteAsset(image: image,
                              pixelSize: CGSize(width: cropped.width, height: cropped.height),
                              cellSize: cell,
                              frameCount: frameCount)
    }

    private static func alphaBounds(_ cg: CGImage) -> CGRect? {
        let width = cg.width
        let height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let info = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: info) else { return }
            // Top-left origin, matching CGImage.cropping's coordinate space.
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return PetAlphaBounds.bounds(in: pixels, width: width, height: height,
                                     bytesPerRow: width * 4, threshold: 8)
    }
}
