import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

// MARK: - Tham số + kết quả

struct MakeOptions {
    var male = true
    var female = true

    // Preset 2
    var p2Mx = -0.3133402466773987
    var p2Fx = -0.23
    var p2Fz = -0.01
    var p2Scale = 1.5555556

    // Aimlock (5, 7, 8, 9, 10, 11, 12, 13)
    var posX = -0.244620
    var posY = -0.0039
    var posZ = 0.0
    var rotY = 2.686321
    var scale = 1.5
    var maleScale = 1.555556
    var femaleScale = 1.5
    var toeScale = 1.5
    var toeX = -0.3850825
    var toeY = -0.0746385
    var toeDrag = false
    var antena = false
    var antenaHeight = 250.0
    var label = "Aimlock"

    // Hitbox cache_res (14, 15, 16, 18)
    var maleCenterX = 0.0
    var maleRadius = 0.0
    var femaleCenterX = 0.0
    var femaleRadius = 0.0
    var zeroOthers = true

    // Magic cache_res (17)
    var colRadius = 0.8
    var colHeight = 0.8
    var bodyOn = true
    var headOn = false

    // Shader súng (3)
    var xrayRGB: [Float] = [Float(17.0 / 255.0), Float(17.0 / 255.0), Float(17.0 / 255.0)]
    var lineRGB: [Float] = [1, 1, 1]
    var dimRGB: [Float] = [Float(17.0 / 255.0), Float(17.0 / 255.0), Float(17.0 / 255.0)]
    var width: Float = 4
    var alpha: Float = 1

    // Hologram (4)
    var tintRGB: [Float] = [0, 1, 1]
    var rimRGB: [Float] = [0, 1, 1]
    var scanRGB: [Float] = [0, 0, 0]
    var tintA: Float = 1
    var rimA: Float = 1
    var scanA: Float = 1
    var xrayOn = true
    var lineOn = false
    var glitchOn = false
}

struct MakeResult {
    var out: Bytes
    var note: String
    var cols: [String]
    var rows: [[String]]
}

enum MakeBundleKind: String {
    case uma
    case shader
    case holo
    case hitbox
}

struct MakeDetection {
    var kind: MakeBundleKind?
    var why: String?
    var build: String?
    var guess = false
    var detail: String?
}

// MARK: - Engine

enum MakeToolsEngine {
    // MARK: tiện ích định dạng

    static func fx(_ v: Double, _ d: Int) -> String { String(format: "%.\(d)f", v) }
    static func fx(_ v: Float, _ d: Int) -> String { String(format: "%.\(d)f", Double(v)) }

    /// 46096 → "46.096" (kiểu vi-VN)
    static func viNum(_ n: Int) -> String {
        let s = String(abs(n))
        var out = ""
        for (i, ch) in s.reversed().enumerated() {
            if i > 0 && i % 3 == 0 { out.append(".") }
            out.append(ch)
        }
        return (n < 0 ? "-" : "") + String(out.reversed())
    }

    static func rgb2hex(_ v: [Float]) -> String {
        var s = "#"
        for i in 0..<3 {
            let x = i < v.count ? v[i] : 0
            let n = Int((Swift.max(0, Swift.min(1, x)) * 255).rounded())
            s += hexString(n, pad: 2).uppercased()
        }
        return s
    }

    static func trimNum(_ v: Double) -> String {
        var s = String(format: "%.6f", v)
        while s.contains(".") && (s.hasSuffix("0") || s.hasSuffix(".")) { s.removeLast() }
        return s
    }

    static func trim2(_ x: Float) -> String {
        var s = String(format: "%.2f", Double(x))
        while s.contains(".") && (s.hasSuffix("0") || s.hasSuffix(".")) { s.removeLast() }
        return s.isEmpty ? "0" : s
    }

    static func nodeRange(_ b: UnityBundle) throws -> (node: UnityNode, from: Int, to: Int) {
        guard let node = b.nodes.first else { throw MakeToolsError("Bundle không có node nào.") }
        let from = b.dataStart + node.off
        return (node, from, from + node.size)
    }

    static func requireRaw(_ b: UnityBundle, _ preset: String) throws {
        if b.hasCompressedBlocks {
            throw MakeToolsError("Bundle có block bị nén — preset \(preset) chỉ sửa được bundle lưu thô.")
        }
    }

    static func parseCab(_ orig: Bytes, _ b: UnityBundle) throws -> (sf: SerializedFile, node: UnityNode) {
        guard let node = b.nodes.first else { throw MakeToolsError("Bundle không có node nào.") }
        let start = b.dataStart + node.off
        let cab = orig.sub(start, start + node.size)
        return (try SerializedFile.parse(cab), node)
    }

    static func find(_ hay: Bytes, _ pat: Bytes) -> Bool {
        if pat.isEmpty || hay.count < pat.count { return false }
        let last = hay.count - pat.count
        let first = pat[0]
        var i = 0
        while i <= last {
            if hay[i] == first {
                var ok = true
                var k = 1
                while k < pat.count {
                    if hay[i + k] != pat[k] { ok = false; break }
                    k += 1
                }
                if ok { return true }
            }
            i += 1
        }
        return false
    }

    static func matches(_ u8: Bytes, at p: Int, _ pat: Bytes) -> Bool {
        if p < 0 || p + pat.count > u8.count { return false }
        for k in 0..<pat.count where u8[p + k] != pat[k] { return false }
        return true
    }

    // MARK: Preset 1 — tráo bone_Hips ⇄ bone_Neck

    struct SwapHit {
        var at: Int
        var lb: String
        var ol: String
        var ot: Bytes
        var cons: Bool
        var h: UInt32
    }

    static let hipsB = utf8Bytes("bone_Hips")
    static let neckB = utf8Bytes("bone_Neck")

    static func findSwapTargets(_ u8: Bytes, from: Int, to: Int) -> [SwapHit] {
        let hH = CRC32.hash(hipsB)
        let hN = CRC32.hash(neckB)
        let want: [(nm: Bytes, lb: String, h: UInt32, ot: Bytes, ol: String, cons: Bool)] = [
            (hipsB, "bone_Hips", hH, neckB, "bone_Neck", true),
            (neckB, "bone_Neck", hN, hipsB, "bone_Hips", true),
            (hipsB, "bone_Hips", hN, neckB, "bone_Neck", false),
            (neckB, "bone_Neck", hH, hipsB, "bone_Hips", false)
        ]
        var hits: [SwapHit] = []
        for w in want {
            var pat = Bytes(repeating: 0, count: 20)
            pat.putU32LE(0, 9)
            pat.putBytes(4, w.nm)
            pat.putU32LE(16, w.h)
            var i = from
            while i <= to - 20 {
                if matches(u8, at: i, pat) {
                    hits.append(SwapHit(at: i + 4, lb: w.lb, ol: w.ol, ot: w.ot, cons: w.cons, h: w.h))
                }
                i += 1
            }
        }
        return hits.sorted { $0.at < $1.at }
    }

    static func applyPreset1(_ orig: Bytes, _ b: UnityBundle) throws -> MakeResult {
        try requireRaw(b, "1")
        let r = try nodeRange(b)
        let hits = findSwapTargets(orig, from: r.from, to: r.to)
        if hits.isEmpty { throw MakeToolsError("Không tìm thấy cặp bone_Hips / bone_Neck nào trong file này.") }
        var out = orig
        for h in hits { out.putBytes(h.at, h.ot) }
        let rows = hits.map { ["0x" + hexString($0.at, pad: 5), String($0.h), $0.lb, $0.ol] }
        let st = hits.allSatisfy { $0.cons } ? "nguyên bản" : (hits.allSatisfy { !$0.cons } ? "đã hoán đổi" : "lẫn lộn")
        return MakeResult(out: out,
                          note: "Tìm thấy \(hits.count) mục tiêu (trạng thái trước đó: \(st)) — hoán đổi \(hits.count * 4) byte.",
                          cols: ["Offset", "Hash (CRC32)", "Trước", "Sau"], rows: rows)
    }

    // MARK: Preset 2 — bone_Head giả + indexer

    static let malePID: Int64 = -9165109095992080675
    static let femalePID: Int64 = 2680591970127643204
    static let backpack = "bone_Left_Spine_Backpack"

    struct MeshPatch {
        var body: Bytes
        var idx: Int
        var bx: Double, by: Double, bz: Double
        var bsx: Double, bsy: Double, bsz: Double
        var ax: Double, az: Double
        var s: Double
    }

    static func patchMesh(_ sf: SerializedFile, _ o: SFObject, px: Double?, pz: Double?, s: Double) throws -> MeshPatch? {
        let trace = TTTrace()
        let val = try sf.read(o, trace: trace)
        guard let bones = val["meshData"]?["umaBones"]?.array else {
            throw MakeToolsError("Không đọc được umaBones của mesh.")
        }
        let names = trace.entries.filter { $0.node == "name" }
        if names.count != bones.count { throw MakeToolsError("Không khớp số xương với chuỗi tên.") }
        guard let idx = bones.firstIndex(where: { $0["name"]?.string == backpack }) else { return nil }
        let tr = names[idx]

        let body = sf.body(o)
        let posOff = tr.start - 40
        let scOff = tr.start - 12
        let oldFieldLen = a4(4 + tr.len)
        let nb = utf8Bytes("bone_Head")
        var newField = Bytes(repeating: 0, count: a4(4 + nb.count))
        newField.putU32LE(0, UInt32(nb.count))
        newField.putBytes(4, nb)

        var out = body.sub(0, tr.start)
        out.append(contentsOf: newField)
        out.append(contentsOf: body.sub(tr.start + oldFieldLen, body.count))

        let b = bones[idx]
        let bx = b["position"]?["x"]?.double ?? 0
        let by = b["position"]?["y"]?.double ?? 0
        let bz = b["position"]?["z"]?.double ?? 0
        let bsx = b["scale"]?["x"]?.double ?? 0
        let bsy = b["scale"]?["y"]?.double ?? 0
        let bsz = b["scale"]?["z"]?.double ?? 0
        if let px = px { out.putF32(posOff, Float(px)) }
        if let pz = pz { out.putF32(posOff + 8, Float(pz)) }
        out.putF32(scOff, Float(-s))
        out.putF32(scOff + 4, Float(s))
        out.putF32(scOff + 8, 1.0)
        return MeshPatch(body: out, idx: idx, bx: bx, by: by, bz: bz, bsx: bsx, bsy: bsy, bsz: bsz,
                         ax: px ?? bx, az: pz ?? bz, s: s)
    }

    struct IndexerKnown {
        var pid: Int64
        var name: String
        var typeIndex: Int
    }

    struct IndexerItem {
        var qn: String
        var typeIndex: Int
        var name: String
        var fileID: Int
        var pathID: Int64
        var path: String
    }

    struct IndexerResult {
        var body: Bytes
        var names: [String]
        var addedCount: Int
    }

    static func replaceLastAssetName(_ path: String, _ name: String) -> String {
        guard path.hasSuffix(".asset") else { return path }
        var parts = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        if parts.isEmpty { return path }
        parts[parts.count - 1] = name + ".asset"
        return parts.joined(separator: "/")
    }

    static func rebuildIndexer(_ sf: SerializedFile, _ o: SFObject, known: [IndexerKnown], targetSize: Int) throws -> IndexerResult {
        let trace = TTTrace()
        let val = try sf.read(o, trace: trace)
        guard let rawItems = val["Items"]?.array else { throw MakeToolsError("Indexer không có mảng Items.") }
        let pathEntries = trace.entries.filter { $0.node == "_Path" }
        if pathEntries.count != rawItems.count { throw MakeToolsError("Không khớp số _Path với số mục indexer.") }

        var items: [IndexerItem] = []
        for it in rawItems {
            items.append(IndexerItem(
                qn: it["_QualifiedName"]?.string ?? "",
                typeIndex: Int(it["_TypeIndex"]?.int64 ?? 0),
                name: it["_Name"]?.string ?? "",
                fileID: Int(it["m_Item"]?["m_FileID"]?.int64 ?? 0),
                pathID: it["m_Item"]?["m_PathID"]?.int64 ?? 0,
                path: it["_Path"]?.string ?? ""))
        }

        let have = Set(items.map { $0.pathID })
        var added: [IndexerItem] = []
        for k in known where !have.contains(k.pid) {
            let sib = items.first { $0.typeIndex == k.typeIndex }
            let path = sib != nil ? replaceLastAssetName(sib!.path, k.name) : k.name + ".asset"
            added.append(IndexerItem(qn: "", typeIndex: k.typeIndex, name: k.name, fileID: 0, pathID: k.pid, path: path))
        }
        let merged = items + added
        let order = merged.enumerated().sorted { a, b in
            if a.element.name != b.element.name { return a.element.name < b.element.name }
            return a.offset < b.offset
        }
        let all = order.map { $0.element }

        guard let firstQN = trace.entries.first(where: { $0.node == "_QualifiedName" }) else {
            throw MakeToolsError("Indexer không có mục nào để tham chiếu bố cục.")
        }
        let body0 = sf.body(o)
        let head = body0.sub(0, firstQN.start - 4)
        var fixed = 0
        for it in all {
            fixed += a4(4 + utf8Bytes(it.qn).count) + 4 + a4(4 + utf8Bytes(it.name).count) + 12
        }
        let budget = targetSize - head.count - 4 - fixed - 24
        if budget < all.count * 4 {
            throw MakeToolsError("Không đủ chỗ cho \(all.count) mục (_Path cần tối thiểu \(all.count * 4) B, còn \(budget) B).")
        }

        var cur = all.map { it -> String in
            it.path.split(separator: "/", omittingEmptySubsequences: false).last.map(String.init) ?? ""
        }
        func total() -> Int { cur.reduce(0) { $0 + a4(4 + utf8Bytes($1).count) } }
        func parts(_ k: Int) -> [String] { all[k].path.split(separator: "/", omittingEmptySubsequences: false).map(String.init) }
        if total() > budget { throw MakeToolsError("Không đủ chỗ cho _Path ngay cả khi chỉ giữ tên file.") }

        for k in 0..<all.count {
            let ps = parts(k)
            var d = 2
            while d <= ps.count {
                let old = cur[k]
                cur[k] = ps.suffix(d).joined(separator: "/")
                if total() > budget { cur[k] = old; break }
                d += 1
            }
        }
        var guardCount = 0
        while total() < budget && guardCount < 2000 {
            guardCount += 1
            var done = true
            for k in 0..<all.count {
                let ps = parts(k)
                let depth = cur[k].split(separator: "/", omittingEmptySubsequences: false).count
                if depth >= ps.count { continue }
                let old = cur[k]
                cur[k] = ps.suffix(depth + 1).joined(separator: "/")
                if total() > budget { cur[k] = old } else { done = false; break }
            }
            if done { break }
        }
        guardCount = 0
        while total() < budget && guardCount < 500 {
            guardCount += 1
            var j = 0
            for k in 1..<Swift.max(cur.count, 1) where cur[k].count < cur[j].count { j = k }
            cur[j] = "./" + cur[j]
        }
        if total() != budget { throw MakeToolsError("Không khớp ngân sách _Path (\(total()) ≠ \(budget)).") }

        var out = head
        var cnt = Bytes(repeating: 0, count: 4)
        cnt.putU32LE(0, UInt32(all.count))
        out.append(contentsOf: cnt)
        for k in 0..<all.count {
            let it = all[k]
            out.append(contentsOf: UnityRebuild.wstr(it.qn))
            var ti = Bytes(repeating: 0, count: 4)
            ti.putU32LE(0, UInt32(truncatingIfNeeded: it.typeIndex))
            out.append(contentsOf: ti)
            out.append(contentsOf: UnityRebuild.wstr(it.name))
            var pp = Bytes(repeating: 0, count: 12)
            pp.putU32LE(0, UInt32(truncatingIfNeeded: it.fileID))
            pp.putU32LE(4, UInt32(truncatingIfNeeded: it.pathID))
            pp.putU32LE(8, UInt32(truncatingIfNeeded: it.pathID >> 32))
            out.append(contentsOf: pp)
            out.append(contentsOf: UnityRebuild.wstr(cur[k]))
        }
        var tail = Bytes(repeating: 0, count: 24)
        let mf = Int32(truncatingIfNeeded: val["BaseMaleBone"]?["m_FileID"]?.int64 ?? 0)
        let mp = val["BaseMaleBone"]?["m_PathID"]?.int64 ?? 0
        let ff = Int32(truncatingIfNeeded: val["BaseFemaleBone"]?["m_FileID"]?.int64 ?? 0)
        let fp = val["BaseFemaleBone"]?["m_PathID"]?.int64 ?? 0
        tail.putU32LE(0, UInt32(bitPattern: mf))
        tail.putU32LE(4, UInt32(truncatingIfNeeded: mp))
        tail.putU32LE(8, UInt32(truncatingIfNeeded: mp >> 32))
        tail.putU32LE(12, UInt32(bitPattern: ff))
        tail.putU32LE(16, UInt32(truncatingIfNeeded: fp))
        tail.putU32LE(20, UInt32(truncatingIfNeeded: fp >> 32))
        out.append(contentsOf: tail)

        if out.count != targetSize { throw MakeToolsError("Indexer dựng ra \(out.count) B, cần \(targetSize) B.") }
        return IndexerResult(body: out, names: all.map { $0.name }, addedCount: added.count)
    }

    static func applyPreset2(_ orig: Bytes, _ b: UnityBundle, _ opt: MakeOptions) throws -> MakeResult {
        if b.hasCompressedBlocks { throw MakeToolsError("Bundle có block bị nén — chưa hỗ trợ.") }
        let (sf, _) = try parseCab(orig, b)
        guard let male = sf.objs.first(where: { $0.pid == malePID }),
              let female = sf.objs.first(where: { $0.pid == femalePID }) else {
            throw MakeToolsError("Không tìm thấy 2 UMAMeshAsset quen thuộc trong file này.")
        }

        var rows: [[String]] = []
        var repl: [Int64: Bytes] = [:]

        func v3(_ x: Double, _ y: Double, _ z: Double) -> String { "(\(fx(x, 4)), \(fx(y, 4)), \(fx(z, 4)))" }

        if let pm = try patchMesh(sf, male, px: opt.p2Mx, pz: nil, s: opt.p2Scale) {
            repl[malePID] = pm.body
            rows.append(["mesh nam", "umaBones[\(pm.idx)]", backpack, "bone_Head"])
            rows.append(["", "position.x", fx(pm.bx, 6), fx(pm.ax, 6)])
            rows.append(["", "scale", v3(pm.bsx, pm.bsy, pm.bsz), v3(-pm.s, pm.s, 1)])
        }
        if let pf = try patchMesh(sf, female, px: opt.p2Fx, pz: opt.p2Fz, s: opt.p2Scale) {
            repl[femalePID] = pf.body
            rows.append(["mesh nữ", "umaBones[\(pf.idx)]", backpack, "bone_Head"])
            rows.append(["", "position.x", fx(pf.bx, 6), fx(pf.ax, 6)])
            rows.append(["", "position.z", fx(pf.bz, 6), fx(pf.az, 6)])
            rows.append(["", "scale", v3(pf.bsx, pf.bsy, pf.bsz), v3(-pf.s, pf.s, 1)])
        }
        if repl.isEmpty {
            throw MakeToolsError("Không tìm thấy xương \(backpack) trong mesh nào — file có thể đã được sửa rồi.")
        }

        func hasLevel1(_ t: SFType, _ name: String) -> Bool {
            guard let tree = try? TTTree.build(t) else { return false }
            return tree.nodes.contains { $0.level == 1 && $0.name == name }
        }

        guard let idxObj = sf.objs.first(where: { o in
            let t = sf.types[o.tid]
            return t.cid == 114 && t.nodes != nil && hasLevel1(t, "Items")
        }) else { throw MakeToolsError("Không tìm thấy UMAAssetIndexer.") }

        var known: [IndexerKnown] = []
        for o in sf.objs {
            let t = sf.types[o.tid]
            if t.cid != 114 || t.nodes == nil || o.pid == idxObj.pid { continue }
            let isRace = hasLevel1(t, "raceName")
            let isRecipe = hasLevel1(t, "recipeData")
            if !isRace && !isRecipe { continue }
            let v = try sf.read(o)
            known.append(IndexerKnown(pid: o.pid, name: v["m_Name"]?.string ?? "", typeIndex: isRace ? 2 : 3))
        }

        var delta = 0
        for (pid, body) in repl {
            let sz = sf.objs.first(where: { $0.pid == pid })?.size ?? 0
            delta += body.count - sz
        }
        let targetSize = idxObj.size - delta
        let si = try rebuildIndexer(sf, idxObj, known: known, targetSize: targetSize)
        repl[idxObj.pid] = si.body
        rows.append(["indexer", "\(si.names.count) mục", "\(si.names.count - si.addedCount) mục ban đầu",
                     "thêm \(si.addedCount) mục · _Path rút gọn"])

        let newCab = try UnityRebuild.rebuildCab(sf, repl)
        let out = try UnityRebuild.rebuildBundle(orig: orig, b: b, cab: newCab)
        return MakeResult(out: out,
                          note: "Đã dựng lại bundle — \(repl.count) object thay đổi, dung lượng giữ nguyên \(viNum(out.count)) byte.",
                          cols: ["Vùng", "Trường", "Trước", "Sau"], rows: rows)
    }

    // MARK: Aimlock — các mảng byte mẫu

    static let aimlockPatch: Bytes = [
        0x89, 0x29, 0xc5, 0xbe, 0x16, 0xdc, 0x98, 0xbd, 0xbb, 0x82, 0x97, 0xb4, 0x00, 0x00, 0x00, 0x00,
        0xbf, 0xb2, 0x2f, 0x3f, 0x43, 0x32, 0x73, 0x36, 0x66, 0x03, 0x7b, 0x35, 0x00, 0x00, 0xc0, 0x3f,
        0x00, 0x00, 0xc0, 0x3f, 0x00, 0x00, 0xc0, 0x3f, 0x10, 0x00, 0x00, 0x00, 0x62, 0x6f, 0x6e, 0x65,
        0x5f, 0x48, 0x65, 0x61, 0x64, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x23, 0xaa, 0xa6, 0xb8,
        0xb2, 0xf7, 0x1f, 0xa4
    ]

    static let neckPatch: Bytes = [
        0xbd, 0x7d, 0x7a, 0xbe, 0x66, 0x8e, 0x81, 0xbb, 0x14, 0xfe, 0xcc, 0xb1, 0x00, 0x00, 0x00, 0x00,
        0xaf, 0xec, 0x2b, 0x40, 0xbd, 0x37, 0x06, 0xb7, 0x93, 0x1a, 0x5a, 0xb7, 0x00, 0x00, 0xc0, 0x3f,
        0x00, 0x00, 0xc0, 0x3f, 0x00, 0x00, 0xc0, 0x3f, 0x10, 0x00, 0x00, 0x00, 0x62, 0x6f, 0x6e, 0x65,
        0x5f, 0x48, 0x65, 0x61, 0x64, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x23, 0xaa, 0xa6, 0xb8,
        0xb2, 0xf7, 0x1f, 0xa4
    ]

    static let patWeapon: Bytes = [0x10, 0x00, 0x00, 0x00] + utf8Bytes("bone_Left_Weapon")
    static let patHeadName: Bytes = [0x10, 0x00, 0x00, 0x00, 0x62, 0x6f, 0x6e, 0x65, 0x5f, 0x48, 0x65, 0x61, 0x64,
                                     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
    static let headNameBytes: Bytes = utf8Bytes("bone_Head") + Bytes(repeating: 0, count: 7)

    struct BoneHit {
        var at: Int
        var isOrig: Bool
        var isMod: Bool
    }

    static func findAimlockTargets(_ u8: Bytes, from: Int, to: Int) -> [BoneHit] {
        var hits: [BoneHit] = []
        let patToe: Bytes = [0x0c, 0x00, 0x00, 0x00] + utf8Bytes("bone_LeftToe")
        var i = from
        while i <= to - 92 {
            if matches(u8, at: i, patToe) {
                let wepOff = i + 64
                let isOrig = matches(u8, at: wepOff, patWeapon)
                let isMod = matches(u8, at: wepOff, patHeadName)
                if isOrig || isMod { hits.append(BoneHit(at: i, isOrig: isOrig, isMod: isMod)) }
            }
            i += 1
        }
        return hits
    }

    static func findBodyTargets(_ u8: Bytes, from: Int, to: Int) -> [BoneHit] {
        var hits: [BoneHit] = []
        var i = from
        while i <= to - 68 {
            let isOrig = matches(u8, at: i + 40, patWeapon)
            let isMod = matches(u8, at: i + 40, patHeadName)
            if isOrig || isMod { hits.append(BoneHit(at: i, isOrig: isOrig, isMod: isMod)) }
            i += 1
        }
        return hits
    }

    static func parentName(_ id: UInt32) -> String {
        if id == 0xA41FF7B2 { return "bone_Spine1 (0xA41FF7B2)" }
        if id == 0x70CD0A46 { return "bone_LeftHand (0x70CD0A46)" }
        return "0x" + hexString(Int(id), pad: 8)
    }

    // MARK: Preset 5 — Aimlock đỉnh đầu

    static func applyPreset5(_ orig: Bytes, _ b: UnityBundle, _ opt: MakeOptions) throws -> MakeResult {
        try requireRaw(b, "5")
        let r = try nodeRange(b)
        let hits = findAimlockTargets(orig, from: r.from, to: r.to)
        if hits.isEmpty { throw MakeToolsError("Không tìm thấy cấu trúc bone_LeftToe / bone_Left_Weapon nào trong file này.") }

        var targets: [(label: String, hit: BoneHit)] = []
        if opt.male && hits.count > 0 { targets.append(("mesh nam", hits[0])) }
        if opt.female && hits.count > 1 { targets.append(("mesh nữ", hits[1])) }
        if targets.isEmpty { throw MakeToolsError("Vui lòng chọn ít nhất một mesh (nam hoặc nữ) để áp dụng.") }

        var out = orig
        var rows: [[String]] = []
        let customScale = abs(opt.toeScale - 1.5) > 1e-4
        let customX = abs(opt.toeX - (-0.3850825)) > 1e-4
        let customY = abs(opt.toeY - (-0.0746385)) > 1e-4

        for t in targets {
            let h = t.hit
            let pPosX = orig.leF32(h.at + 24), pPosY = orig.leF32(h.at + 28), pPosZ = orig.leF32(h.at + 32)
            let pRotX = orig.leF32(h.at + 36), pRotY = orig.leF32(h.at + 40), pRotZ = orig.leF32(h.at + 44), pRotW = orig.leF32(h.at + 48)
            let pScale = orig.leF32(h.at + 52)
            let pParent = orig.leU32(h.at + 88)
            let prevBone = h.isMod ? "bone_Head (đã mod)" : "bone_Left_Weapon"

            out.putBytes(h.at + 24, aimlockPatch)
            if customScale {
                out.putF32(h.at + 52, Float(opt.toeScale))
                out.putF32(h.at + 56, Float(opt.toeScale))
                out.putF32(h.at + 60, Float(opt.toeScale))
            }
            if customX { out.putF32(h.at + 24, Float(opt.toeX)) }
            if customY { out.putF32(h.at + 28, Float(opt.toeY)) }

            let newScale = customScale ? opt.toeScale : 1.5
            let newPosX = customX ? opt.toeX : -0.3850825
            let newPosY = customY ? opt.toeY : -0.0746385

            rows.append([t.label, "xương vũ khí → Head", prevBone, "bone_Head"])
            rows.append([t.label, "xương cha", parentName(pParent), "bone_Spine1 (0xA41FF7B2)"])
            rows.append([t.label, "bone_LeftToe scale", "(\(fx(pScale, 2)), \(fx(pScale, 2)), \(fx(pScale, 2)))",
                         "(\(fx(newScale, 2)), \(fx(newScale, 2)), \(fx(newScale, 2)))"])
            rows.append([t.label, "bone_LeftToe position", "(\(fx(pPosX, 4)), \(fx(pPosY, 4)), \(fx(pPosZ, 4)))",
                         "(\(fx(newPosX, 4)), \(fx(newPosY, 4)), 0.0000)"])
            rows.append([t.label, "bone_LeftToe rotation", "(\(fx(pRotX, 4)), \(fx(pRotY, 4)), \(fx(pRotZ, 4)), \(fx(pRotW, 4)))",
                         "(0.0000, 0.6863, 0.0000, 0.0000)"])
        }

        let exact = targets.count == 1 && targets[0].label == "mesh nam" && !customScale && !customX && !customY
        let extra = exact ? " — khớp 100% từng byte với File 1" : ""
        return MakeResult(out: out,
                          note: "Đã áp dụng Aimlock Đỉnh Đầu trên \(targets.map { $0.label }.joined(separator: " & "))\(extra) — sửa tại chỗ, dung lượng giữ nguyên \(viNum(out.count)) byte.",
                          cols: ["Vùng", "Trường", "Trước", "Sau"], rows: rows)
    }

    // MARK: Preset 6 — Antena tay

    static func findAntenaOffset(_ body: Bytes) -> (e33Offset: Int, currentVal: Float)? {
        var p = 0x40
        while p <= 0x60 {
            let count = Int(body.leI32(p))
            if count >= 20 && count <= 80 {
                let e33Off = p + 4 + 4 * 64 + 60          // bindPoses[4].e33
                if e33Off + 4 <= body.count {
                    let v = body.leF32(e33Off)
                    let e30 = body.leF32(e33Off - 12)
                    let e31 = body.leF32(e33Off - 8)
                    let e32 = body.leF32(e33Off - 4)
                    if e30 == 0 && e31 == 0 && e32 == 0 && v > 0.001 && v < 100000.0 {
                        return (e33Off, v)
                    }
                }
            }
            p += 4
        }
        return nil
    }

    static func applyPreset6(_ orig: Bytes, _ b: UnityBundle, _ opt: MakeOptions) throws -> MakeResult {
        try requireRaw(b, "6")
        let (sf, node) = try parseCab(orig, b)

        var targets: [(label: String, bone: String, obj: SFObject)] = []
        if opt.male, let m = sf.objs.first(where: { $0.pid == malePID }) { targets.append(("mesh nam", "bone_RightHand (tay phải)", m)) }
        if opt.female, let f = sf.objs.first(where: { $0.pid == femalePID }) { targets.append(("mesh nữ", "bone_LeftHand (tay trái)", f)) }
        if targets.isEmpty { throw MakeToolsError("Vui lòng chọn ít nhất một mesh (nam hoặc nữ) để áp dụng.") }

        var out = orig
        var rows: [[String]] = []
        var modified = 0
        for t in targets {
            let body = sf.body(t.obj)
            guard let found = findAntenaOffset(body) else {
                throw MakeToolsError("Không định vị được ma trận bindPoses của \(t.label) trong file này.")
            }
            let absOffset = b.dataStart + node.off + sf.dataOffset + t.obj.off + found.e33Offset
            out.putF32(absOffset, Float(opt.antenaHeight))
            modified += 4
            let where_ = "bindPoses[4].e33 (0x\(hexString(absOffset, pad: 5)))"
            rows.append([t.label, "xương gắn ăng-ten", t.bone, t.bone])
            rows.append([t.label, "vị trí ma trận", where_, where_])
            rows.append([t.label, "hệ số chiều cao Antena", fx(found.currentVal, 1), fx(opt.antenaHeight, 1)])
        }
        return MakeResult(out: out,
                          note: "Đã áp dụng Antena Tay trên \(targets.map { $0.label }.joined(separator: " & ")) (chiều cao: \(trimNum(opt.antenaHeight))) — sửa tại chỗ \(modified) byte, dung lượng giữ nguyên \(viNum(out.count)) byte.",
                          cols: ["Vùng", "Trường", "Trước", "Sau"], rows: rows)
    }

    // MARK: Preset 7 / 8 — Aimlock thân / cổ

    static func applyPreset7(_ orig: Bytes, _ b: UnityBundle, _ opt: MakeOptions) throws -> MakeResult {
        try requireRaw(b, "7")
        let r = try nodeRange(b)
        let hits = findBodyTargets(orig, from: r.from, to: r.to)
        if hits.isEmpty { throw MakeToolsError("Không tìm thấy cấu trúc bone_Left_Weapon nào trong file này.") }

        var targets: [(label: String, hit: BoneHit, scale: Double)] = []
        if opt.male && hits.count > 0 { targets.append(("mesh nam", hits[0], opt.maleScale)) }
        if opt.female && hits.count > 1 { targets.append(("mesh nữ", hits[1], opt.femaleScale)) }
        if targets.isEmpty { throw MakeToolsError("Vui lòng chọn ít nhất một mesh (nam hoặc nữ) để áp dụng.") }

        var out = orig
        var rows: [[String]] = []
        for t in targets {
            let h = t.hit
            let pX = orig.leF32(h.at), pY = orig.leF32(h.at + 4), pZ = orig.leF32(h.at + 8)
            let pRotY = orig.leF32(h.at + 16)
            let pScale = orig.leF32(h.at + 28)
            let pParent = orig.leU32(h.at + 64)
            let prevBone = h.isMod ? "bone_Head (đã mod)" : "bone_Left_Weapon"

            out.putF32(h.at, Float(opt.posX))
            out.putF32(h.at + 4, Float(opt.posY))
            out.putF32(h.at + 8, 0)
            out.putF32(h.at + 16, 3.0412555)
            out.putF32(h.at + 28, Float(t.scale))
            out.putF32(h.at + 32, Float(t.scale))
            out.putF32(h.at + 36, Float(t.scale))
            out.putBytes(h.at + 44, headNameBytes)
            out.putU32LE(h.at + 64, 0xA41FF7B2)

            rows.append([t.label, "xương vũ khí → Head", prevBone, "bone_Head (vùng thân)"])
            rows.append([t.label, "xương cha", parentName(pParent), "bone_Spine1 (0xA41FF7B2)"])
            rows.append([t.label, "vị trí ngực (pos)", "(\(fx(pX, 4)), \(fx(pY, 4)), \(fx(pZ, 4)))",
                         "(\(fx(opt.posX, 4)), \(fx(opt.posY, 4)), 0.0000)"])
            rows.append([t.label, "góc xoay (rot.y)", fx(pRotY, 4), "3.0413"])
            rows.append([t.label, "tỉ lệ thân (scale)", "(\(fx(pScale, 2)), \(fx(pScale, 2)), \(fx(pScale, 2)))",
                         "(\(fx(t.scale, 2)), \(fx(t.scale, 2)), \(fx(t.scale, 2)))"])
        }
        return MakeResult(out: out,
                          note: "Đã áp dụng Aimlock Body 90% (Aim Thân) trên \(targets.map { $0.label }.joined(separator: " & ")) — sửa tại chỗ, dung lượng giữ nguyên \(viNum(out.count)) byte.",
                          cols: ["Vùng", "Trường", "Trước", "Sau"], rows: rows)
    }

    static func applyPreset8(_ orig: Bytes, _ b: UnityBundle, _ opt: MakeOptions) throws -> MakeResult {
        try requireRaw(b, "8")
        let r = try nodeRange(b)
        let hits = findBodyTargets(orig, from: r.from, to: r.to)
        if hits.isEmpty { throw MakeToolsError("Không tìm thấy cấu trúc bone_Left_Weapon nào trong file này.") }

        var targets: [(label: String, hit: BoneHit)] = []
        if opt.male && hits.count > 0 { targets.append(("mesh nam", hits[0])) }
        if opt.female && hits.count > 1 { targets.append(("mesh nữ", hits[1])) }
        if targets.isEmpty { throw MakeToolsError("Vui lòng chọn ít nhất một mesh (nam hoặc nữ) để áp dụng.") }

        var out = orig
        var rows: [[String]] = []
        let customPos = abs(opt.posX - (-0.244620)) > 1e-4
        let customScale = abs(opt.scale - 1.5) > 1e-4

        for t in targets {
            let h = t.hit
            let pX = orig.leF32(h.at)
            let pRotY = orig.leF32(h.at + 16)
            let pScale = orig.leF32(h.at + 28)
            let pParent = orig.leU32(h.at + 64)
            let prevBone = h.isMod ? "bone_Head (đã mod)" : "bone_Left_Weapon"

            out.putBytes(h.at, neckPatch)
            if customPos { out.putF32(h.at, Float(opt.posX)) }
            if customScale {
                out.putF32(h.at + 28, Float(opt.scale))
                out.putF32(h.at + 32, Float(opt.scale))
                out.putF32(h.at + 36, Float(opt.scale))
            }
            let newPos = customPos ? opt.posX : -0.244620
            let newScale = customScale ? opt.scale : 1.5

            rows.append([t.label, "xương vũ khí → Head", prevBone, "bone_Head (vùng cổ)"])
            rows.append([t.label, "xương cha", parentName(pParent), "bone_Spine1 (0xA41FF7B2)"])
            rows.append([t.label, "vị trí cổ (pos.x)", fx(pX, 4), fx(newPos, 4)])
            rows.append([t.label, "góc xoay (rot.y)", fx(pRotY, 4), "2.6863"])
            rows.append([t.label, "tỉ lệ cổ (scale)", "(\(fx(pScale, 2)), \(fx(pScale, 2)), \(fx(pScale, 2)))",
                         "(\(fx(newScale, 2)), \(fx(newScale, 2)), \(fx(newScale, 2)))"])
        }

        let exact = targets.count == 1 && targets[0].label == "mesh nam" && !customPos && !customScale
        if exact && out.count > 0x7190 { out[0x7190] = 0x6e }
        let extra = exact ? " — khớp 100% từng byte với file neck mẫu" : ""
        return MakeResult(out: out,
                          note: "Đã áp dụng Aimlock Cổ (Neck Lock) trên \(targets.map { $0.label }.joined(separator: " & "))\(extra) — sửa tại chỗ, dung lượng giữ nguyên \(viNum(out.count)) byte.",
                          cols: ["Vùng", "Trường", "Trước", "Sau"], rows: rows)
    }

    // MARK: Presets 9, 10, 11, 12, 13 — Aimlock tuỳ biến

    static func applyAimlockCustom(_ orig: Bytes, _ b: UnityBundle, _ opt: MakeOptions) throws -> MakeResult {
        try requireRaw(b, "này")
        let r = try nodeRange(b)
        let hits = findBodyTargets(orig, from: r.from, to: r.to)
        if hits.isEmpty { throw MakeToolsError("Không tìm thấy cấu trúc bone_Left_Weapon nào trong file này.") }

        var targets: [(label: String, hit: BoneHit)] = []
        if opt.male && hits.count > 0 { targets.append(("mesh nam", hits[0])) }
        if opt.female && hits.count > 1 { targets.append(("mesh nữ", hits[1])) }
        if targets.isEmpty && !opt.antena { throw MakeToolsError("Vui lòng chọn ít nhất một mesh (nam hoặc nữ) để áp dụng.") }

        var out = orig
        var rows: [[String]] = []

        for t in targets {
            let h = t.hit
            let pX = orig.leF32(h.at)
            let pScale = orig.leF32(h.at + 28)
            let pParent = orig.leU32(h.at + 64)
            let prevBone = h.isMod ? "bone_Head (đã mod)" : "bone_Left_Weapon"

            out.putF32(h.at, Float(opt.posX))
            out.putF32(h.at + 4, Float(opt.posY))
            out.putF32(h.at + 8, Float(opt.posZ))
            out.putF32(h.at + 16, Float(opt.rotY))
            out.putF32(h.at + 28, Float(opt.scale))
            out.putF32(h.at + 32, Float(opt.scale))
            out.putF32(h.at + 36, Float(opt.scale))
            out.putBytes(h.at + 44, headNameBytes)
            out.putU32LE(h.at + 64, 0xA41FF7B2)

            rows.append([t.label, "xương vũ khí → Head", prevBone, "bone_Head"])
            rows.append([t.label, "xương cha", parentName(pParent), "bone_Spine1 (0xA41FF7B2)"])
            rows.append([t.label, "vị trí ngắm (pos.x)", fx(pX, 4), fx(opt.posX, 4)])
            rows.append([t.label, "tỉ lệ hitbox (scale)", "(\(fx(pScale, 2)), \(fx(pScale, 2)), \(fx(pScale, 2)))",
                         "(\(fx(opt.scale, 2)), \(fx(opt.scale, 2)), \(fx(opt.scale, 2)))"])
        }

        if opt.toeDrag {
            let toeHits = findAimlockTargets(orig, from: r.from, to: r.to)
            if opt.male && toeHits.count > 0 {
                let h = toeHits[0]
                out.putF32(h.at + 52, 1.5); out.putF32(h.at + 56, 1.5); out.putF32(h.at + 60, 1.5)
                rows.append(["mesh nam", "kéo chân (bone_LeftToe scale)", "1.00", "1.50"])
            }
            if opt.female && toeHits.count > 1 {
                let h = toeHits[1]
                out.putF32(h.at + 52, 1.5); out.putF32(h.at + 56, 1.5); out.putF32(h.at + 60, 1.5)
                rows.append(["mesh nữ", "kéo chân (bone_LeftToe scale)", "1.00", "1.50"])
            }
        }

        if opt.antena {
            let (sf, node) = try parseCab(orig, b)
            for (isMale, pid, label) in [(true, malePID, "mesh nam"), (false, femalePID, "mesh nữ")] {
                if (isMale && !opt.male) || (!isMale && !opt.female) { continue }
                guard let obj = sf.objs.first(where: { $0.pid == pid }) else { continue }
                guard let found = findAntenaOffset(sf.body(obj)) else { continue }
                let absOffset = b.dataStart + node.off + sf.dataOffset + obj.off + found.e33Offset
                out.putF32(absOffset, Float(opt.antenaHeight))
                rows.append([label, "Antena cột sóng", "bindPoses[4].e33 (\(fx(found.currentVal, 1)))", fx(opt.antenaHeight, 1)])
            }
        }

        let names = targets.map { $0.label }.joined(separator: " & ")
        return MakeResult(out: out,
                          note: "Đã áp dụng \(opt.label) trên \(names)\(opt.antena ? " + Antena" : "") — sửa tại chỗ, dung lượng giữ nguyên \(viNum(out.count)) byte.",
                          cols: ["Vùng", "Trường", "Trước", "Sau"], rows: rows)
    }

    // MARK: Presets 14–18 — hitbox cache_res

    static let maleHeadPID: Int64 = 3844969807423664876
    static let femaleHeadPID: Int64 = 4273153183181864610
    static let sniperColliderPID: Int64 = -3891784277426559989

    struct HeadTarget {
        var label: String
        var obj: SFObject
        var isMale: Bool
    }

    static func headTargets(_ sf: SerializedFile, _ opt: MakeOptions) throws -> [HeadTarget] {
        var targets: [HeadTarget] = []
        if opt.male, let o = sf.objs.first(where: { $0.pid == maleHeadPID }) {
            targets.append(HeadTarget(label: "mesh nam (Male_DTSCollider)", obj: o, isMale: true))
        }
        if opt.female, let o = sf.objs.first(where: { $0.pid == femaleHeadPID }) {
            targets.append(HeadTarget(label: "mesh nữ (Female_DTSCollider)", obj: o, isMale: false))
        }
        if targets.isEmpty { throw MakeToolsError("Vui lòng chọn ít nhất một mesh (nam hoặc nữ) để áp dụng.") }
        return targets
    }

    enum HitboxMode {
        case body, drag, neck, chest
    }

    static func applyHitbox(_ mode: HitboxMode, _ orig: Bytes, _ b: UnityBundle, _ opt: MakeOptions) throws -> MakeResult {
        let presetNo: String
        switch mode {
        case .body: presetNo = "14"
        case .drag: presetNo = "15"
        case .neck: presetNo = "16"
        case .chest: presetNo = "18"
        }
        try requireRaw(b, presetNo)
        let (sf, node) = try parseCab(orig, b)
        let targets = try headTargets(sf, opt)

        var out = orig
        var rows: [[String]] = []
        for t in targets {
            let body = sf.body(t.obj)
            let pRadius = body.leF32(44)
            let pCx = body.leF32(56), pCy = body.leF32(60), pCz = body.leF32(64)
            let newRadius = Float(t.isMale ? opt.maleRadius : opt.femaleRadius)
            let newCx = Float(t.isMale ? opt.maleCenterX : opt.femaleCenterX)
            var newCy = pCy
            var newCz = pCz
            let absOffset = b.dataStart + node.off + sf.dataOffset + t.obj.off

            if mode == .body {
                newCy = t.isMale ? 0.018044 : 0.016054
                newCz = t.isMale ? -0.000457 : -0.000464
                out.putU8(absOffset + 36, 0)       // m_IsTrigger = 0
                out.putU8(absOffset + 40, 1)       // m_Enabled = 1
            }
            out.putF32(absOffset + 44, newRadius)
            out.putF32(absOffset + 56, newCx)
            if mode != .chest {
                out.putF32(absOffset + 60, newCy)
                out.putF32(absOffset + 64, newCz)
            }

            let place: String
            switch mode {
            case .body: place = "bone_Head (lồng ngực)"
            case .drag: place = "bone_Head (cằm / cổ trên)"
            case .neck: place = "bone_Head (yết hầu cổ)"
            case .chest: place = "bone_Head (ngực trên chuẩn file chest)"
            }
            let d = mode == .chest ? 6 : 4
            rows.append([t.label, "bộ phận va chạm", "bone_Head (đỉnh đầu)", place])
            rows.append([t.label, "tâm Hitbox (Center.x)", fx(pCx, d), fx(newCx, d)])
            rows.append([t.label, "bán kính Hitbox (Radius)", fx(pRadius, d), fx(newRadius, d)])
            rows.append([t.label, "tọa độ đầy đủ (x, y, z)",
                         "(\(fx(pCx, 4)), \(fx(pCy, 4)), \(fx(pCz, 4)))",
                         "(\(fx(newCx, 4)), \(fx(newCy, 4)), \(fx(newCz, 4)))"])
        }

        var zeroed = 0
        switch mode {
        case .body:
            if opt.zeroOthers {
                for col in sf.objs where col.cid == 136 {
                    if col.pid == maleHeadPID || col.pid == femaleHeadPID || col.pid == sniperColliderPID { continue }
                    let absOffset = b.dataStart + node.off + sf.dataOffset + col.off
                    out.putU8(absOffset + 36, 1)
                    out.putU8(absOffset + 40, 0)
                    out.putF32(absOffset + 44, 0)
                    out.putF32(absOffset + 48, 0)
                    zeroed += 1
                }
                rows.append(["toàn bộ cơ thể", "triệt tiêu hitbox thân/chi", "34 collider thường",
                             "Đã ép Radius & Height = 0, tắt \(zeroed) collider"])
            }
        case .drag:
            rows.append(["toàn bộ cơ thể", "hitbox thân/tay/chân", "giữ nguyên chuẩn gốc", "Giữ nguyên 35 collider (hỗ trợ kéo tâm tự nhiên)"])
        case .neck:
            rows.append(["toàn bộ cơ thể", "hitbox thân/tay/chân", "giữ nguyên chuẩn gốc", "Giữ nguyên 35 collider (hỗ trợ bám cổ mượt mà)"])
        case .chest:
            rows.append(["toàn bộ cơ thể", "hitbox thân/tay/chân", "giữ nguyên chuẩn gốc", "Giữ nguyên 35 collider (chuẩn 100% file chest mẫu)"])
        }

        let names = targets.map { $0.label }.joined(separator: " & ")
        let title: String
        switch mode {
        case .body: title = "Aim Body 100% (Hitbox Đầu Về Ngực)"
        case .drag: title = "Aim Drag Headshot (Kéo Tâm Nhẹ Vào Đầu)"
        case .neck: title = "Aimlock Cổ (Neck Lock)"
        case .chest: title = "Aim Chest (Aim Ngực Chuẩn)"
        }
        let more = zeroed > 0 ? " + Triệt tiêu \(zeroed) Hitbox cơ thể" : ""
        let unit = mode == .body ? "byte" : "byte chuẩn"
        return MakeResult(out: out,
                          note: "Đã áp dụng \(title) trên \(names)\(more) — sửa tại chỗ, dung lượng giữ nguyên \(viNum(out.count)) \(unit).",
                          cols: ["Vùng", "Trường", "Trước", "Sau"], rows: rows)
    }

    static func applyHitboxMagic(_ orig: Bytes, _ b: UnityBundle, _ opt: MakeOptions) throws -> MakeResult {
        try requireRaw(b, "17")
        let (sf, node) = try parseCab(orig, b)
        var out = orig
        var rows: [[String]] = []

        var countBody = 0
        if opt.bodyOn {
            for col in sf.objs where col.cid == 136 {
                if col.pid == maleHeadPID || col.pid == femaleHeadPID || col.pid == sniperColliderPID { continue }
                let absOffset = b.dataStart + node.off + sf.dataOffset + col.off
                out.putU8(absOffset + 36, 0)
                out.putU8(absOffset + 40, 1)
                out.putF32(absOffset + 44, Float(opt.colRadius))
                out.putF32(absOffset + 48, Float(opt.colHeight))
                countBody += 1
            }
            rows.append(["34 collider thân/chi", "bán kính (Radius)", "0.010 ~ 0.084 (gốc)", "\(fx(opt.colRadius, 4)) (khổng lồ)"])
            rows.append(["34 collider thân/chi", "chiều cao (Height)", "0.061 ~ 0.267 (gốc)", "\(fx(opt.colHeight, 4)) (khổng lồ)"])
        }

        var countHead = 0
        if opt.headOn {
            for (pid, label) in [(maleHeadPID, "mesh nam (bone_Head)"), (femaleHeadPID, "mesh nữ (bone_Head)")] {
                guard let obj = sf.objs.first(where: { $0.pid == pid }) else { continue }
                let prevRadius = sf.body(obj).leF32(44)
                let absOffset = b.dataStart + node.off + sf.dataOffset + obj.off
                out.putF32(absOffset + 44, Float(opt.colRadius))
                out.putF32(absOffset + 48, Float(opt.colHeight))
                rows.append([label, "bán kính đầu (Radius)", fx(prevRadius, 4), fx(opt.colRadius, 4)])
                countHead += 1
            }
        }
        if countBody == 0 && countHead == 0 {
            throw MakeToolsError("Vui lòng chọn ít nhất một tùy chọn (phóng to thân hoặc phóng to đầu).")
        }
        let more = countHead > 0 ? " + \(countHead) collider đầu" : ""
        return MakeResult(out: out,
                          note: "Đã áp dụng Magic Bullet (Hitbox Khổng Lồ Toàn Thân) trên \(countBody) collider cơ thể\(more) — sửa tại chỗ, dung lượng giữ nguyên \(viNum(out.count)) byte chuẩn.",
                          cols: ["Vùng", "Trường", "Trước", "Sau"], rows: rows)
    }

    // MARK: Shader — dùng chung

    struct ShaderProp {
        var name: String
        var type: Int
        var valOff: Int
        var val: [Float]
    }

    /// SerializedProperty: m_Name, m_Description, m_Attributes[], m_Type(i32), m_Flags(u32),
    /// m_DefValue[0..3](f32), m_DefTexture{m_DefaultName, m_TexDim}
    static func readShaderProps(_ body: Bytes) throws -> [ShaderProp] {
        var p = 0
        func rd() throws -> Int {
            if p + 4 > body.count { throw MakeToolsError("shader bị cắt cụt") }
            let v = Int(body.leI32(p)); p += 4
            return v
        }
        func str() throws -> String {
            let n = try rd()
            if n < 0 || p + n > body.count { throw MakeToolsError("chuỗi hỏng trong shader") }
            let s = String(decoding: body.sub(p, p + n), as: UTF8.self)
            p = a4(p + n)
            return s
        }
        _ = try str()                                  // Shader.m_Name
        let cnt = try rd()
        if cnt < 0 || cnt > 500 { throw MakeToolsError("số property bất thường: \(cnt)") }
        var props: [ShaderProp] = []
        for _ in 0..<cnt {
            let name = try str()
            _ = try str()                              // m_Description
            let na = try rd()
            if na < 0 || na > 100 { throw MakeToolsError("m_Attributes hỏng") }
            for _ in 0..<na { _ = try str() }
            let type = try rd()
            p += 4                                     // m_Flags
            let valOff = p
            if p + 16 > body.count { throw MakeToolsError("shader bị cắt cụt") }
            let val = [body.leF32(p), body.leF32(p + 4), body.leF32(p + 8), body.leF32(p + 12)]
            p += 16
            _ = try str()                              // m_DefTexture.m_DefaultName
            p += 4                                     // m_TexDim
            props.append(ShaderProp(name: name, type: type, valOff: valOff, val: val))
        }
        return props
    }

    static let xrayShaders = ["backweapon", "brmobilebumpspec", "brmobilebumpspecdecal"]

    static func shaderKey(_ path: String) -> String {
        var f = path.split(separator: "/", omittingEmptySubsequences: false).last.map(String.init) ?? path
        if f.hasSuffix(".shader") { f = String(f.dropLast(7)) }
        return f
    }

    static func isXrayShader(_ path: String) -> Bool { xrayShaders.contains(shaderKey(path)) }

    /// pathID → đường dẫn asset (từ AssetBundle.m_Container)
    static func containerNames(_ sf: SerializedFile) throws -> [Int64: String] {
        var nameOf: [Int64: String] = [:]
        if let ab = sf.objs.first(where: { $0.cid == 142 }) {
            let v = try sf.read(ab)
            for c in v["m_Container"]?.array ?? [] {
                if let path = c["first"]?.string, let pid = c["second"]?["asset"]?["m_PathID"]?.int64 {
                    nameOf[pid] = path
                }
            }
        }
        return nameOf
    }

    // MARK: Preset 3 — shader súng

    static func paintShader(_ body: inout Bytes, _ opt: MakeOptions, _ short: String, _ rows: inout [[String]]) throws -> Int {
        let props = try readShaderProps(body)
        var n = 0
        for p in props {
            var next: [Float]
            var before: String
            var after: String
            switch p.name {
            case "_XRayColor", "_OutLineColor", "_DimColor":
                let rgb = p.name == "_XRayColor" ? opt.xrayRGB : (p.name == "_OutLineColor" ? opt.lineRGB : opt.dimRGB)
                let alpha = p.name == "_XRayColor" ? opt.alpha : p.val[3]
                next = [rgb[0], rgb[1], rgb[2], alpha]
                before = rgb2hex(p.val)
                after = rgb2hex(next)
            case "_OutLineWidth":
                next = [opt.width, p.val[1], p.val[2], p.val[3]]
                before = fx(p.val[0], 2)
                after = fx(next[0], 2)
            default:
                continue
            }
            for i in 0..<4 { body.putF32(p.valOff + i * 4, next[i]) }
            n += 1
            rows.append([short, p.name, before, after])
        }
        return n
    }

    static func applyPreset3(_ orig: Bytes, _ b: UnityBundle, _ opt: MakeOptions) throws -> MakeResult {
        guard let node = b.nodes.first else { throw MakeToolsError("Bundle không có node nào.") }
        let (data, spans) = try b.decompressAll(orig)
        let cab = data.sub(node.off, node.off + node.size)
        let sf = try SerializedFile.parse(cab)
        let nameOf = try containerNames(sf)

        var slots: [(key: String, obj: SFObject)] = []
        for o in sf.objs where o.cid == 48 {
            guard let path = nameOf[o.pid], isXrayShader(path) else { continue }
            let key = shaderKey(path)
            if let i = slots.firstIndex(where: { $0.key == key }) { slots[i] = (key, o) } else { slots.append((key, o)) }
        }
        if slots.isEmpty {
            throw MakeToolsError("Không tìm thấy backweapon / brmobilebumpspec / brmobilebumpspecdecal trong bundle này. Đây có phải file shaders của game không?")
        }

        var rows: [[String]] = []
        var repl: [Int64: Bytes] = [:]
        var swapped = 0
        var painted = 0

        for (key, o) in slots {
            let bodyStart = sf.dataOffset + o.off
            let cur = cab.sub(bodyStart, bodyStart + o.size)

            var isXray = false
            if let props = try? readShaderProps(cur) {
                isXray = props.contains { $0.name == "_XRayColor" || $0.name == "_DimColor" }
            }

            var body: Bytes
            if isXray {
                body = cur
            } else {
                let blob = try MakeToolsBlobs.xray(key)
                let xb = try blob.bytes()
                if blob.pid != o.pid {
                    throw MakeToolsError("pathID của \(key) không khớp shader nhúng (\(o.pid) ≠ \(blob.pid)) — bundle này khác phiên bản.")
                }
                if xb.count > o.size {
                    throw MakeToolsError("Shader X-Ray của \(key) (\(xb.count) B) lớn hơn shader gốc (\(o.size) B) — không đệm vừa.")
                }
                body = Bytes(repeating: 0, count: o.size)
                body.putBytes(0, xb)
                swapped += 1
                rows.append([key + ".shader", "(toàn bộ shader)", "gốc \(viNum(o.size)) B", "X-Ray \(viNum(xb.count)) B + đệm"])
            }
            painted += try paintShader(&body, opt, key + ".shader", &rows)
            repl[o.pid] = body
        }

        let out = try UnityRebuild.rebuildShaders(orig: orig, b: b, data: data, spans: spans, sf: sf, node: node, repl: repl)
        let what = swapped > 0
            ? "Đã thay \(swapped) shader gốc bằng bản X-Ray và đặt màu"
            : "Đã đổi màu \(slots.count) shader định vị"
        return MakeResult(out: out,
                          note: "\(what) — \(painted) giá trị, dung lượng giữ nguyên \(viNum(out.count)) byte.",
                          cols: ["Shader", "Property", "Trước", "Sau"], rows: rows)
    }

    // MARK: Preset 4 — hologram nhân vật

    static let zTestNames: [Int: String] = [
        0: "Disabled", 1: "Never", 2: "Less", 3: "Equal", 4: "LEqual", 5: "Greater", 6: "NotEqual", 7: "GEqual", 8: "Always"
    ]

    static func paintHolo(_ body: inout Bytes, _ opt: MakeOptions, _ rows: inout [[String]], _ label: String,
                          _ tree: TTTree) throws -> Int {
        let props = try readShaderProps(body)
        var n = 0
        for p in props {
            var next: [Float]
            var before: String
            var after: String
            switch p.name {
            case "_TintColor":
                next = [opt.tintRGB[0], opt.tintRGB[1], opt.tintRGB[2], opt.tintA]
                before = rgb2hex(p.val); after = rgb2hex(next)
            case "_RimColor":
                next = [opt.rimRGB[0], opt.rimRGB[1], opt.rimRGB[2], opt.rimA]
                before = rgb2hex(p.val); after = rgb2hex(next)
            case "_ScanColor":
                next = [opt.scanRGB[0], opt.scanRGB[1], opt.scanRGB[2], opt.scanA]
                before = rgb2hex(p.val); after = rgb2hex(next)
            case "_Line":
                next = opt.lineOn ? [100, 100, 50, 50] : [0, 0, 0, 0]
                before = "(" + p.val.map { trim2($0) }.joined(separator: ", ") + ")"
                after = "(" + next.map { trim2($0) }.joined(separator: ", ") + ")"
            case "_LineAndGlitch":
                next = opt.glitchOn ? [0.5, 0.5, 5, 0.1] : [0, 0, 0, 0]
                before = "(" + p.val.map { trim2($0) }.joined(separator: ", ") + ")"
                after = "(" + next.map { trim2($0) }.joined(separator: ", ") + ")"
            default:
                continue
            }
            for i in 0..<4 { body.putF32(p.valOff + i * 4, next[i]) }
            n += 1
            rows.append([label, p.name, before, after])
        }

        // zTest — thứ thực sự làm xuyên tường
        let want: Float = opt.xrayOn ? 8 : 4
        let zs = try tree.findZTest(body)
        for off in zs {
            let old = body.leF32(off)
            if old == want { continue }
            body.putF32(off, want)
            n += 1
            let oldInt = (old.isFinite && abs(old) < 1000) ? Int(old) : -1
            let oldName = zTestNames[oldInt] ?? "?"
            rows.append([label, "zTest (xuyên tường)", "\(trim2(old)) · \(oldName)", "\(trim2(want)) · \(zTestNames[Int(want)] ?? "?")"])
        }
        if zs.isEmpty { rows.append([label, "zTest", "không tìm thấy", "— bỏ qua"]) }
        return n
    }

    static func applyPreset4(_ orig: Bytes, _ b: UnityBundle, _ opt: MakeOptions) throws -> MakeResult {
        guard let node = b.nodes.first else { throw MakeToolsError("Bundle không có node nào.") }
        let (data, spans) = try b.decompressAll(orig)
        let cab = data.sub(node.off, node.off + node.size)
        let sf = try SerializedFile.parse(cab)

        let shaders = sf.objs.filter { $0.cid == 48 }
        guard let firstShader = shaders.first else {
            throw MakeToolsError("Bundle này không có shader nào — đây có phải optionalavatarres_commonab_shader không?")
        }
        let holo = MakeToolsBlobs.hologram
        let holoBody = try holo.bytes()
        var rows: [[String]] = []
        let tree = try sf.tree(for: firstShader.tid)
        var painted = holoBody
        let nSet = try paintHolo(&painted, opt, &rows, "hologram", tree)

        var repl: [Int64: Bytes] = [:]
        var swapped = 0
        var skipped = 0
        for o in shaders {
            if o.size < painted.count { skipped += 1; continue }
            var body = Bytes(repeating: 0, count: o.size)
            body.putBytes(0, painted)
            repl[o.pid] = body
            swapped += 1
        }
        if swapped == 0 { throw MakeToolsError("Không shader nào đủ chỗ để thay bằng hologram.") }
        rows.append(["— áp dụng —", "\(swapped) shader", "\(shaders.count) shader trong bundle",
                     "thay \(swapped)" + (skipped > 0 ? ", bỏ qua \(skipped) (quá nhỏ)" : "")])

        let out = try UnityRebuild.rebuildShaders(orig: orig, b: b, data: data, spans: spans, sf: sf, node: node, repl: repl)
        return MakeResult(out: out,
                          note: "Đã thay \(swapped) shader nhân vật bằng hologram và đặt màu — \(nSet) giá trị, dung lượng giữ nguyên \(viNum(out.count)) byte.",
                          cols: ["Vùng", "Property", "Trước", "Sau"], rows: rows)
    }

    // MARK: Điều phối

    static func apply(preset id: String, orig: Bytes, bundle b: UnityBundle, options opt: MakeOptions) throws -> MakeResult {
        switch id {
        case "1": return try applyPreset1(orig, b)
        case "2": return try applyPreset2(orig, b, opt)
        case "3": return try applyPreset3(orig, b, opt)
        case "4": return try applyPreset4(orig, b, opt)
        case "5": return try applyPreset5(orig, b, opt)
        case "6": return try applyPreset6(orig, b, opt)
        case "7": return try applyPreset7(orig, b, opt)
        case "8": return try applyPreset8(orig, b, opt)
        case "9", "10", "11", "12", "13": return try applyAimlockCustom(orig, b, opt)
        case "14": return try applyHitbox(.body, orig, b, opt)
        case "15": return try applyHitbox(.drag, orig, b, opt)
        case "16": return try applyHitbox(.neck, orig, b, opt)
        case "17": return try applyHitboxMagic(orig, b, opt)
        case "18": return try applyHitbox(.chest, orig, b, opt)
        default: throw MakeToolsError("Preset không hợp lệ: \(id)")
        }
    }

    // MARK: Nhận diện bundle

    struct BuildInfo {
        var name: String
        var size: Int
        var objs: Int
        var items: Int
        var shaders: Int
    }

    static let umaBuilds = [
        BuildInfo(name: "Free Fire Thường", size: 46096, objs: 24, items: 8, shaders: 0),
        BuildInfo(name: "Free Fire Max", size: 46640, objs: 24, items: 12, shaders: 0)
    ]
    static let shaderBuilds = [
        BuildInfo(name: "Free Fire Thường", size: 1443632, objs: 0, items: 0, shaders: 146),
        BuildInfo(name: "Free Fire Max", size: 1419165, objs: 0, items: 0, shaders: 144)
    ]
    static let holoBuilds = [
        BuildInfo(name: "Free Fire Thường", size: 382493, objs: 0, items: 0, shaders: 48),
        BuildInfo(name: "Free Fire Max", size: 391791, objs: 0, items: 0, shaders: 50)
    ]

    /// Tên gốc trên CDN = Base64(SHA1(nội dung)), '/'→~2F '+'→~2B '='→~3D
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

    static func detect(_ orig: Bytes, _ b: UnityBundle) -> MakeDetection {
        guard let node = b.nodes.first else { return MakeDetection(kind: nil, why: "Bundle không có node nào.") }

        var isUMA = false
        if !b.hasCompressedBlocks {
            let from = b.dataStart + node.off
            let hay = orig.sub(from, from + node.size)
            for kw in ["bone_Hips", "bone_Left_Spine_Backpack", "UMAAssetIndexer"] where find(hay, utf8Bytes(kw)) {
                isUMA = true
                break
            }
        }

        do {
            let (data, _) = try b.decompressAll(orig)
            let cab = data.sub(node.off, node.off + node.size)
            let sf = try SerializedFile.parse(cab)
            let nShader = sf.objs.filter { $0.cid == 48 }.count

            if nShader > 0 {
                var hit = 0
                var hasHolo = false
                var hasDecal = false
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
                    build = umaBuilds.first { $0.items == it }
                    guess = build != nil
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
