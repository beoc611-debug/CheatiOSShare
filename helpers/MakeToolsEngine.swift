import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

// MARK: - Structs

struct MakeOptions {
    var male = true
    var female = true
    var p2Mx = -0.3133402466773987; var p2Fx = -0.23; var p2Fz = -0.01; var p2Scale = 1.5555556
    var posX = -0.244620; var posY = -0.0039; var posZ = 0.0
    var rotY = 2.686321; var scale = 1.5
    var maleScale = 1.555556; var femaleScale = 1.5
    var toeScale = 1.5; var toeX = -0.3850825; var toeY = -0.0746385
    var toeDrag = false; var antena = false; var antenaHeight = 250.0
    var label = "Aimlock"
    var maleCenterX = 0.0; var maleRadius = 0.0; var femaleCenterX = 0.0; var femaleRadius = 0.0
    var zeroOthers = true
    var colRadius = 0.8; var colHeight = 0.8; var bodyOn = true; var headOn = false
    var xrayRGB: [Float] = [Float(17.0/255.0), Float(17.0/255.0), Float(17.0/255.0)]
    var lineRGB: [Float] = [1, 1, 1]
    var dimRGB: [Float] = [Float(17.0/255.0), Float(17.0/255.0), Float(17.0/255.0)]
    var width: Float = 4; var alpha: Float = 1
    var tintRGB: [Float] = [0, 1, 1]; var rimRGB: [Float] = [0, 1, 1]; var scanRGB: [Float] = [0, 0, 0]
    var tintA: Float = 1; var rimA: Float = 1; var scanA: Float = 1
    var xrayOn = true; var lineOn = false; var glitchOn = false
}

struct MakeResult {
    var out: Bytes
    var note: String
    var cols: [String]
    var rows: [[String]]
}

enum MakeBundleKind: String {
    case uma, shader, holo, hitbox
}

struct MakeDetection {
    var kind: MakeBundleKind?
    var why: String?
    var build: String?
    var guess = false
    var detail: String?
}

// MARK: - Engine (detect + format only; patching is server-side)

enum MakeToolsEngine {

    static func viNum(_ n: Int) -> String {
        let s = String(abs(n))
        var out = ""
        for (i, ch) in s.reversed().enumerated() {
            if i > 0 && i % 3 == 0 { out.append(".") }
            out.append(ch)
        }
        return (n < 0 ? "-" : "") + String(out.reversed())
    }

    static func cdnHash(_ data: Bytes) -> String {
        #if canImport(CryptoKit)
        let digest = Insecure.SHA1.hash(data: Data(data))
        let b64 = Data(digest).base64EncodedString()
        #else
        let b64 = ""
        #endif
        return b64.replacingOccurrences(of: "+", with: "~2B")
            .replacingOccurrences(of: "/", with: "~2F")
            .replacingOccurrences(of: "=", with: "~3D")
    }

    // MARK: detect helpers

    private static func find(_ hay: Bytes, _ pat: Bytes) -> Bool {
        if pat.isEmpty || hay.count < pat.count { return false }
        let last = hay.count - pat.count
        let first = pat[0]; var i = 0
        while i <= last {
            if hay[i] == first {
                var ok = true; var k = 1
                while k < pat.count { if hay[i+k] != pat[k] { ok = false; break }; k += 1 }
                if ok { return true }
            }
            i += 1
        }
        return false
    }

    private static let xrayShaders = ["backweapon", "brmobilebumpspec", "brmobilebumpspecdecal"]

    private static func shaderKey(_ path: String) -> String {
        var f = path.split(separator: "/", omittingEmptySubsequences: false).last.map(String.init) ?? path
        if f.hasSuffix(".shader") { f = String(f.dropLast(7)) }
        return f
    }

    private static func isXrayShader(_ path: String) -> Bool { xrayShaders.contains(shaderKey(path)) }

    // MARK: Build tables (for version detection only)

    private struct BuildInfo { var name: String; var size: Int; var objs: Int; var items: Int; var shaders: Int }

    private static let umaBuilds = [
        BuildInfo(name: "Free Fire Thường", size: 46096,   objs: 24, items: 8,  shaders: 0),
        BuildInfo(name: "Free Fire Max",    size: 46640,   objs: 24, items: 12, shaders: 0)
    ]
    private static let shaderBuilds = [
        BuildInfo(name: "Free Fire Thường", size: 1443632, objs: 0, items: 0, shaders: 146),
        BuildInfo(name: "Free Fire Max",    size: 1419165, objs: 0, items: 0, shaders: 144)
    ]
    private static let holoBuilds = [
        BuildInfo(name: "Free Fire Thường", size: 382493,  objs: 0, items: 0, shaders: 48),
        BuildInfo(name: "Free Fire Max",    size: 391791,  objs: 0, items: 0, shaders: 50)
    ]

    // MARK: detect

    static func detect(_ orig: Bytes, _ b: UnityBundle) -> MakeDetection {
        guard let node = b.nodes.first else { return MakeDetection(kind: nil, why: "Bundle không có node nào.") }

        var isUMA = false
        if !b.hasCompressedBlocks {
            let from = b.dataStart + node.off
            let hay = orig.sub(from, from + node.size)
            for kw in ["bone_Hips", "bone_Left_Spine_Backpack", "UMAAssetIndexer"] where find(hay, utf8Bytes(kw)) {
                isUMA = true; break
            }
        }

        do {
            let (data, _) = try b.decompressAll(orig)
            let cab = data.sub(node.off, node.off + node.size)
            let sf = try SerializedFile.parse(cab)
            let nShader = sf.objs.filter { $0.cid == 48 }.count

            if nShader > 0 {
                var hit = 0; var hasHolo = false; var hasDecal = false
                if let ab = sf.objs.first(where: { $0.cid == 142 }) {
                    let v = try sf.read(ab)
                    for c in v["m_Container"]?.array ?? [] {
                        guard let first = c["first"]?.string else { continue }
                        if isXrayShader(first) { hit += 1 }
                        let f = first.split(separator: "/", omittingEmptySubsequences: false).last.map(String.init) ?? first
                        if f == "hologram.shader" { hasHolo = true }
                        if f == "brmobilebumpspecdecal.shader" { hasDecal = true }
                    }
                }
                if hasHolo && !hasDecal {
                    var build = holoBuilds.first { $0.shaders == nShader && $0.size == orig.count }
                    var guess = false
                    if build == nil { build = holoBuilds.first { $0.shaders == nShader }; guess = build != nil }
                    return MakeDetection(kind: .holo, why: nil, build: build?.name, guess: guess,
                                         detail: "bundle shader nhân vật — \(nShader) shader, có hologram")
                }
                if hit == 0 {
                    return MakeDetection(kind: nil, why: "Bundle có \(nShader) shader nhưng không có backweapon / brmobilebumpspec / brmobilebumpspecdecal.")
                }
                var build = shaderBuilds.first { $0.shaders == nShader && $0.size == orig.count }
                var guess = false
                if build == nil { build = shaderBuilds.first { $0.shaders == nShader }; guess = build != nil }
                return MakeDetection(kind: .shader, why: nil, build: build?.name, guess: guess,
                                     detail: "bundle shader súng — \(nShader) shader, \(hit) shader định vị")
            }

            let nCollider = sf.objs.filter { $0.cid == 136 }.count
            var isCacheRes = false
            if let ab = sf.objs.first(where: { $0.cid == 142 }), let v = try? sf.read(ab) {
                if v["m_Name"]?.string == "cache_res" || v["m_AssetBundleName"]?.string == "cache_res" { isCacheRes = true }
            }
            if !isCacheRes && (nCollider >= 30 || node.name.contains("CAB-f35e59c15686beb35c2683bdcd5b9393")) {
                isCacheRes = true
            }
            if isCacheRes {
                return MakeDetection(kind: .hitbox, why: nil, build: "cache_res (Hitbox Nhân Vật)", guess: false,
                                     detail: "bundle hitbox va chạm nhân vật — \(nCollider) CapsuleCollider (DTSCollider)")
            }

            if isUMA || sf.types.contains(where: { $0.cid == 114 }) {
                var items: Int? = nil
                if let idx = sf.objs.first(where: { o in
                    let t = sf.types[o.tid]
                    guard t.cid == 114, t.nodes != nil, let tree = try? TTTree.build(t) else { return false }
                    return tree.nodes.contains { $0.level == 1 && $0.name == "Items" }
                }) {
                    items = (try? sf.read(idx))?["Items"]?.array?.count
                }
                var build = umaBuilds.first { $0.size == orig.count && $0.objs == sf.objs.count }
                var guess = false
                if build == nil, let it = items {
                    build = umaBuilds.first { $0.items == it }; guess = build != nil
                }
                let tail = items != nil ? ", indexer \(items!) mục" : ""
                return MakeDetection(kind: .uma, why: nil, build: build?.name, guess: guess,
                                     detail: "bundle UMA — \(sf.objs.count) object\(tail)")
            }
        } catch {
            return MakeDetection(kind: nil, why: "Không đọc được nội dung: \(error.localizedDescription)")
        }
        return MakeDetection(kind: nil, why: "Không nhận ra đây là bundle UMA, shader hay cache_res.")
    }
}
