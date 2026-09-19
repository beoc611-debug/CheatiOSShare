import Foundation

// MARK: - Lỗi + tiện ích byte

struct MakeToolsError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

typealias Bytes = [UInt8]

@inline(__always) func a4(_ n: Int) -> Int { (n + 3) & ~3 }

/// Các hàm đọc/ghi an toàn: đọc ngoài biên trả 0, ghi ngoài biên bị bỏ qua — không bao giờ crash
/// khi gặp file lạ hoặc bị hỏng.
extension Array where Element == UInt8 {
    func at(_ p: Int) -> UInt8 { (p >= 0 && p < count) ? self[p] : 0 }

    func leU16(_ p: Int) -> Int { Int(at(p)) | (Int(at(p + 1)) << 8) }

    func leU32(_ p: Int) -> UInt32 {
        var v: UInt32 = 0
        for i in 0..<4 { v |= UInt32(at(p + i)) << UInt32(8 * i) }
        return v
    }

    func leI32(_ p: Int) -> Int32 { Int32(bitPattern: leU32(p)) }

    func leU64(_ p: Int) -> UInt64 {
        var v: UInt64 = 0
        for i in 0..<8 { v |= UInt64(at(p + i)) << UInt64(8 * i) }
        return v
    }

    func leI64(_ p: Int) -> Int64 { Int64(bitPattern: leU64(p)) }

    func leF32(_ p: Int) -> Float { Float(bitPattern: leU32(p)) }

    func leF64(_ p: Int) -> Double { Double(bitPattern: leU64(p)) }

    func beU16(_ p: Int) -> Int { (Int(at(p)) << 8) | Int(at(p + 1)) }

    func beU32(_ p: Int) -> UInt32 {
        var v: UInt32 = 0
        for i in 0..<4 { v = (v << 8) | UInt32(at(p + i)) }
        return v
    }

    func beI64(_ p: Int) -> Int64 {
        var v: UInt64 = 0
        for i in 0..<8 { v = (v << 8) | UInt64(at(p + i)) }
        return Int64(bitPattern: v)
    }

    /// Cắt [a, b) và tự kẹp vào biên mảng.
    func sub(_ a: Int, _ b: Int) -> Bytes {
        let lo = Swift.max(0, a)
        let hi = Swift.min(count, b)
        return lo < hi ? Array(self[lo..<hi]) : []
    }

    mutating func putU8(_ p: Int, _ v: UInt8) {
        if p >= 0 && p < count { self[p] = v }
    }

    mutating func putU32LE(_ p: Int, _ v: UInt32) {
        for i in 0..<4 { putU8(p + i, UInt8((v >> UInt32(8 * i)) & 0xFF)) }
    }

    mutating func putF32(_ p: Int, _ v: Float) { putU32LE(p, v.bitPattern) }

    mutating func putU32BE(_ p: Int, _ v: UInt32) {
        for i in 0..<4 { putU8(p + i, UInt8((v >> UInt32(8 * (3 - i))) & 0xFF)) }
    }

    mutating func putU16BE(_ p: Int, _ v: Int) {
        putU8(p, UInt8((v >> 8) & 0xFF))
        putU8(p + 1, UInt8(v & 0xFF))
    }

    mutating func putI64BE(_ p: Int, _ v: Int64) {
        let u = UInt64(bitPattern: v)
        for i in 0..<8 { putU8(p + i, UInt8((u >> UInt64(8 * (7 - i))) & 0xFF)) }
    }

    mutating func putBytes(_ p: Int, _ b: Bytes) {
        for i in 0..<b.count { putU8(p + i, b[i]) }
    }
}

func hexString(_ v: Int, pad: Int = 0) -> String {
    let s = String(v, radix: 16)
    return s.count >= pad ? s : String(repeating: "0", count: pad - s.count) + s
}

func utf8Bytes(_ s: String) -> Bytes { Array(s.utf8) }

// MARK: - CRC32

enum CRC32 {
    static let table: [UInt32] = {
        var t = [UInt32](repeating: 0, count: 256)
        for n in 0..<256 {
            var c = UInt32(n)
            for _ in 0..<8 { c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1) }
            t[n] = c
        }
        return t
    }()

    static func hash(_ b: Bytes) -> UInt32 {
        var c: UInt32 = 0xFFFFFFFF
        for x in b { c = table[Int((c ^ UInt32(x)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFFFFFF
    }
}

// MARK: - LZ4

enum LZ4 {
    static func decode(_ src: Bytes, outSize: Int) throws -> Bytes {
        if outSize < 0 || outSize > 1_500_000_000 { throw MakeToolsError("LZ4: kích thước đầu ra không hợp lệ") }
        var dst = Bytes(repeating: 0, count: outSize)
        let n = src.count
        var i = 0
        var o = 0
        while i < n {
            let tok = Int(src[i]); i += 1

            var lit = tok >> 4
            if lit == 15 {
                var b = 255
                while b == 255 {
                    if i >= n { throw MakeToolsError("LZ4: hết dữ liệu ở độ dài literal") }
                    b = Int(src[i]); i += 1
                    lit += b
                }
            }
            if lit > 0 {
                if i + lit > n { throw MakeToolsError("LZ4: literal vượt biên") }
                if o + lit > outSize { throw MakeToolsError("LZ4: literal vượt kích thước đầu ra") }
                for k in 0..<lit { dst[o + k] = src[i + k] }
                i += lit
                o += lit
            }

            // token cuối chỉ có literal, không kèm match
            if i >= n { break }
            if i + 1 >= n { throw MakeToolsError("LZ4: thiếu offset") }

            let off = Int(src[i]) | (Int(src[i + 1]) << 8)
            i += 2
            if off == 0 || off > o { throw MakeToolsError("LZ4: offset không hợp lệ (\(off))") }
            var ml = tok & 15
            if ml == 15 {
                var b = 255
                while b == 255 {
                    if i >= n { throw MakeToolsError("LZ4: hết dữ liệu ở độ dài match") }
                    b = Int(src[i]); i += 1
                    ml += b
                }
            }
            ml += 4
            if o + ml > outSize { throw MakeToolsError("LZ4: match vượt kích thước đầu ra") }
            // copy từng byte — vùng match có thể chồng lấn khi off < ml
            var sp = o - off
            for _ in 0..<ml {
                dst[o] = dst[sp]
                o += 1
                sp += 1
            }
        }
        if o != outSize { throw MakeToolsError("LZ4: giải ra \(o) byte, cần \(outSize)") }
        return dst
    }

    /// Nén LZ4 block (greedy hash-chain). Tỉ lệ kém LZ4HC vài phần trăm nhưng đủ dùng.
    static func encode(_ src: Bytes) -> Bytes {
        let n = src.count
        if n == 0 { return [] }
        var out = Bytes()
        out.reserveCapacity(n / 2 + 64)
        let hlog = 16
        let hsize = 1 << hlog
        var head = [Int32](repeating: -1, count: hsize)
        var prev = [Int32](repeating: -1, count: n)
        let mflimit = 12
        let lastlit = 5
        let maxdist = 65535
        let chain = 32

        func h4(_ i: Int) -> Int {
            let v = UInt32(src[i]) | (UInt32(src[i + 1]) << 8) | (UInt32(src[i + 2]) << 16) | (UInt32(src[i + 3]) << 24)
            return Int((v &* 2654435761) >> UInt32(32 - hlog))
        }
        func same4(_ a: Int, _ b: Int) -> Bool {
            src[a] == src[b] && src[a + 1] == src[b + 1] && src[a + 2] == src[b + 2] && src[a + 3] == src[b + 3]
        }
        func pushLen(_ len: Int) {
            var r = len - 15
            while r >= 255 { out.append(255); r -= 255 }
            out.append(UInt8(r))
        }
        func emit(_ ls: Int, _ le: Int, _ mlen: Int, _ moff: Int) {
            let litlen = le - ls
            let ml = mlen > 0 ? mlen - 4 : 0
            let t1 = litlen >= 15 ? 15 : litlen
            let t2 = ml >= 15 ? 15 : ml
            out.append(UInt8((t1 << 4) | t2))
            if litlen >= 15 { pushLen(litlen) }
            if litlen > 0 { out.append(contentsOf: src[ls..<le]) }
            if mlen > 0 {
                out.append(UInt8(moff & 255))
                out.append(UInt8((moff >> 8) & 255))
                if ml >= 15 { pushLen(ml) }
            }
        }

        var anchor = 0
        var i = 0
        while i < n - mflimit {
            let hv = h4(i)
            var bestLen = 0
            var bestOff = 0
            var cur = Int(head[hv])
            var cnt = 0
            while cur >= 0 && cnt < chain {
                let off = i - cur
                if off > maxdist { break }
                if same4(cur, i) {
                    var l = 4
                    let lim = n - lastlit - i
                    while l < lim && src[cur + l] == src[i + l] { l += 1 }
                    if l > bestLen {
                        bestLen = l
                        bestOff = off
                        if l >= 255 { break }
                    }
                }
                cur = Int(prev[cur])
                cnt += 1
            }
            prev[i] = head[hv]
            head[hv] = Int32(i)

            if bestLen >= 4 {
                emit(anchor, i, bestLen, bestOff)
                let stop = Swift.min(i + bestLen, n - 3)
                var k = i + 1
                while k < stop {
                    let hk = h4(k)
                    prev[k] = head[hk]
                    head[hk] = Int32(k)
                    k += 1
                }
                i += bestLen
                anchor = i
            } else {
                i += 1
            }
        }
        // literal cuối
        let litlen = n - anchor
        out.append(UInt8((litlen >= 15 ? 15 : litlen) << 4))
        if litlen >= 15 { pushLen(litlen) }
        if litlen > 0 { out.append(contentsOf: src[anchor..<n]) }
        return out
    }

    /// Truy vết nguồn gốc từng byte của kết quả giải nén: byte đầu ra nào bắt nguồn từ literal
    /// nào trong luồng nén. Dùng để vá thẳng byte trong luồng nén mà không phải nén lại.
    static func trace(_ src: Bytes, outSize: Int) -> [Int] {
        var litOf = [Int](repeating: -1, count: outSize)
        var copyOf = [Int](repeating: -1, count: outSize)
        var i = 0
        var o = 0
        while i < src.count && o < outSize {
            let tok = Int(src[i]); i += 1
            var lit = tok >> 4
            if lit == 15 {
                var b = 255
                while b == 255 { b = Int(src.at(i)); i += 1; lit += b }
            }
            var k = 0
            while k < lit && o < outSize {
                litOf[o] = i
                o += 1
                i += 1
                k += 1
            }
            if i >= src.count { break }
            let off = src.leU16(i)
            i += 2
            var ml = tok & 15
            if ml == 15 {
                var b = 255
                while b == 255 { b = Int(src.at(i)); i += 1; ml += b }
            }
            ml += 4
            var sp = o - off
            var m = 0
            while m < ml && o < outSize {
                if sp >= 0 { copyOf[o] = sp }
                o += 1
                sp += 1
                m += 1
            }
        }
        // Lần về gốc: byte match nào cuối cùng cũng bắt nguồn từ một literal.
        var root = [Int](repeating: -1, count: outSize)
        for k in 0..<outSize {
            var cur = k
            var guardCount = 0
            while litOf[cur] < 0 && copyOf[cur] >= 0 && guardCount < outSize {
                cur = copyOf[cur]
                guardCount += 1
            }
            root[k] = litOf[cur] >= 0 ? litOf[cur] : -1
        }
        return root
    }
}

// MARK: - UnityFS

struct UnityBlock {
    var u: Int
    var c: Int
    var f: Int
}

struct UnityNode {
    var off: Int
    var size: Int
    var flags: Int
    var name: String
}

struct UnityBundle {
    var fmt: Int
    var uv: String
    var rev: String
    var declared: Int
    var ciSize: Int
    var uiSize: Int
    var flags: Int
    var blocks: [UnityBlock]
    var nodes: [UnityNode]
    var dataStart: Int
    var infoOff: Int
    var info: Bytes
    var headerEnd: Int

    var hasCompressedBlocks: Bool { blocks.contains { ($0.f & 0x3F) != 0 } }

    static func parse(_ u8: Bytes) throws -> UnityBundle {
        var p = 0
        func cstr() -> String {
            var s = Bytes()
            while p < u8.count && u8[p] != 0 { s.append(u8[p]); p += 1 }
            p += 1
            return String(decoding: s, as: UTF8.self)
        }

        let sig = cstr()
        if sig != "UnityFS" { throw MakeToolsError("Không phải UnityFS bundle (signature \"\(sig)\")") }
        let fmt = Int(u8.beU32(p)); p += 4
        let uv = cstr()
        let rev = cstr()
        let declared = Int(u8.beI64(p)); p += 8
        let ciSize = Int(u8.beU32(p)); p += 4
        let uiSize = Int(u8.beU32(p)); p += 4
        let flags = Int(u8.beU32(p)); p += 4
        let headerEnd = p
        let ic = flags & 0x3F
        if ciSize <= 0 || ciSize > u8.count || uiSize <= 0 || uiSize > 200_000_000 {
            throw MakeToolsError("Header UnityFS không hợp lệ (kích thước blocksInfo).")
        }

        var infoOff = 0
        var info = Bytes()
        var dataStart = 0

        if (flags & 0x80) != 0 {
            // blocksInfoAtTheEnd: dò ngược để tìm blocksInfo
            dataStart = (headerEnd + 15) & ~15
            var found = false
            let from = Swift.min(declared, u8.count) - ciSize
            let lowest = Swift.max(0, from - 80000)
            var off = from
            while off >= lowest {
                if off >= 0 && off + ciSize <= u8.count {
                    let raw = u8.sub(off, off + ciSize)
                    if ic == 2 || ic == 3 {
                        if let cand = try? LZ4.decode(raw, outSize: uiSize) {
                            info = cand; infoOff = off; found = true; break
                        }
                    } else {
                        info = raw; infoOff = off; found = true; break
                    }
                }
                off -= 1
            }
            if !found { throw MakeToolsError("Không tìm được blocksInfo ở cuối file.") }
        } else {
            if fmt >= 7 || (flags & 0x200) != 0 { p = (p + 15) & ~15 }
            infoOff = p
            if infoOff + ciSize > u8.count { throw MakeToolsError("blocksInfo vượt quá dung lượng file.") }
            let infoRaw = u8.sub(p, p + ciSize)
            if ic == 2 || ic == 3 { info = try LZ4.decode(infoRaw, outSize: uiSize) }
            else if ic == 0 { info = infoRaw }
            else { throw MakeToolsError("blocksInfo nén kiểu \(ic) (chưa hỗ trợ)") }
            dataStart = infoOff + ciSize
            if (flags & 0x200) != 0 { dataStart = (dataStart + 15) & ~15 }
        }

        var q = 16
        let nB = Int(info.beU32(q)); q += 4
        if nB < 0 || nB > 200_000 { throw MakeToolsError("Số block bất thường: \(nB)") }
        var blocks: [UnityBlock] = []
        for _ in 0..<nB {
            blocks.append(UnityBlock(u: Int(info.beU32(q)), c: Int(info.beU32(q + 4)), f: info.beU16(q + 8)))
            q += 10
        }
        let nN = Int(info.beU32(q)); q += 4
        if nN < 0 || nN > 200_000 { throw MakeToolsError("Số node bất thường: \(nN)") }
        var nodes: [UnityNode] = []
        for _ in 0..<nN {
            let off = Int(info.beI64(q))
            let sz = Int(info.beI64(q + 8))
            let nf = Int(info.beU32(q + 16))
            q += 20
            var nm = Bytes()
            while q < info.count && info[q] != 0 { nm.append(info[q]); q += 1 }
            q += 1
            nodes.append(UnityNode(off: off, size: sz, flags: nf, name: String(decoding: nm, as: UTF8.self)))
        }
        return UnityBundle(fmt: fmt, uv: uv, rev: rev, declared: declared, ciSize: ciSize, uiSize: uiSize,
                           flags: flags, blocks: blocks, nodes: nodes, dataStart: dataStart,
                           infoOff: infoOff, info: info, headerEnd: headerEnd)
    }

    /// Giải nén mọi block; ghi lại block nào phủ vùng nào.
    struct BlockSpan {
        var start: Int
        var end: Int
        var comp: Int
        var ct: Int
        var srcOff: Int
    }

    func decompressAll(_ orig: Bytes) throws -> (data: Bytes, spans: [BlockSpan]) {
        var data = Bytes()
        var spans: [BlockSpan] = []
        var pos = dataStart
        var outPos = 0
        for blk in blocks {
            if pos + blk.c > orig.count { throw MakeToolsError("Block vượt quá dung lượng file.") }
            let raw = orig.sub(pos, pos + blk.c)
            let ct = blk.f & 0x3F
            var dec = raw
            if ct == 2 || ct == 3 { dec = try LZ4.decode(raw, outSize: blk.u) }
            data.append(contentsOf: dec)
            spans.append(BlockSpan(start: outPos, end: outPos + blk.u, comp: blk.c, ct: ct, srcOff: pos))
            outPos += blk.u
            pos += blk.c
        }
        return (data, spans)
    }
}

// MARK: - SerializedFile

struct SFTypeNode {
    var level: Int
    var to: UInt32
    var no: UInt32
    var meta: Int
}

struct SFType {
    var cid: Int
    var nodes: [SFTypeNode]?
    var sb: Bytes?
}

struct SFObject {
    var pid: Int64
    var off: Int
    var size: Int
    var tid: Int
    var cid: Int
    var ent: Int
}

final class SerializedFile {
    let cab: Bytes
    let version: Int
    let dataOffset: Int
    let types: [SFType]
    let objs: [SFObject]
    private var treeCache: [Int: TTTree] = [:]

    init(cab: Bytes, version: Int, dataOffset: Int, types: [SFType], objs: [SFObject]) {
        self.cab = cab
        self.version = version
        self.dataOffset = dataOffset
        self.types = types
        self.objs = objs
    }

    static func parse(_ cab: Bytes) throws -> SerializedFile {
        let version = Int(cab.beU32(8))
        if version != 22 { throw MakeToolsError("SerializedFile v\(version) (tool chỉ hỗ trợ v22)") }
        let dataOffset = Int(cab.beI64(32))
        if dataOffset <= 0 || dataOffset > cab.count { throw MakeToolsError("SerializedFile: dataOffset không hợp lệ.") }

        var p = 48
        func cstr() { while p < cab.count && cab[p] != 0 { p += 1 }; p += 1 }
        cstr()                                   // unityVersion
        p += 4                                   // targetPlatform
        let hasTT = cab.at(p) != 0
        p += 1

        func i32() -> Int { let v = Int(cab.leI32(p)); p += 4; return v }

        let tcount = i32()
        if tcount < 0 || tcount > 20_000 { throw MakeToolsError("Số type bất thường: \(tcount)") }
        var types: [SFType] = []
        for _ in 0..<tcount {
            let cid = i32()
            p += 1                               // stripped
            p += 2                               // scriptTypeIndex
            if cid == 114 { p += 16 }            // scriptHash
            p += 16                              // typeHash
            var nodes: [SFTypeNode]? = nil
            var sb: Bytes? = nil
            if hasTT {
                let nn = i32()
                let sbs = i32()
                if nn < 0 || nn > 200_000 || sbs < 0 || sbs > 50_000_000 { throw MakeToolsError("TypeTree bất thường.") }
                var list: [SFTypeNode] = []
                list.reserveCapacity(nn)
                for _ in 0..<nn {
                    list.append(SFTypeNode(level: Int(cab.at(p + 2)), to: cab.leU32(p + 4), no: cab.leU32(p + 8), meta: Int(cab.leI32(p + 20))))
                    p += 32
                }
                nodes = list
                sb = cab.sub(p, p + sbs)
                p += sbs
                let nd = i32()
                if nd < 0 || nd > 1_000_000 { throw MakeToolsError("typeDependencies bất thường.") }
                p += nd * 4
            }
            types.append(SFType(cid: cid, nodes: nodes, sb: sb))
        }

        let ocount = i32()
        if ocount < 0 || ocount > 2_000_000 { throw MakeToolsError("Số object bất thường: \(ocount)") }
        var objs: [SFObject] = []
        objs.reserveCapacity(ocount)
        for _ in 0..<ocount {
            p = a4(p)
            let ent = p
            let pid = cab.leI64(p)
            let off = Int(cab.leI64(p + 8))
            let size = Int(cab.leU32(p + 16))
            let tid = Int(cab.leI32(p + 20))
            p += 24
            if tid < 0 || tid >= types.count { throw MakeToolsError("Object tham chiếu type không tồn tại.") }
            objs.append(SFObject(pid: pid, off: off, size: size, tid: tid, cid: types[tid].cid, ent: ent))
        }
        return SerializedFile(cab: cab, version: version, dataOffset: dataOffset, types: types, objs: objs)
    }

    func body(_ o: SFObject) -> Bytes { cab.sub(dataOffset + o.off, dataOffset + o.off + o.size) }

    func tree(for tid: Int) throws -> TTTree {
        if let t = treeCache[tid] { return t }
        let t = try TTTree.build(types[tid])
        treeCache[tid] = t
        return t
    }

    func read(_ o: SFObject, trace: TTTrace? = nil) throws -> TTValue {
        let tree = try self.tree(for: o.tid)
        let r = TTReader(body(o))
        return try tree.readValue(0, r, trace)
    }
}

// MARK: - Typetree

let ttCommonStrings = "AABB\0AnimationClip\0AnimationCurve\0AnimationState\0Array\0Base\0BitField\0bitset\0bool\0char\0ColorRGBA\0Component\0data\0deque\0double\0dynamic_array\0FastPropertyName\0first\0float\0Font\0GameObject\0Generic Mono\0GradientNEW\0GUID\0GUIStyle\0int\0list\0long long\0map\0Matrix4x4f\0MdFour\0MonoBehaviour\0MonoScript\0m_ByteSize\0m_Curve\0m_EditorClassIdentifier\0m_EditorHideFlags\0m_Enabled\0m_ExtensionPtr\0m_GameObject\0m_Index\0m_IsArray\0m_IsStatic\0m_MetaFlag\0m_Name\0m_ObjectHideFlags\0m_PrefabInternal\0m_PrefabParentObject\0m_Script\0m_StaticEditorFlags\0m_Type\0m_Version\0Object\0pair\0PPtr<Component>\0PPtr<GameObject>\0PPtr<Material>\0PPtr<MonoBehaviour>\0PPtr<MonoScript>\0PPtr<Object>\0PPtr<Prefab>\0PPtr<Sprite>\0PPtr<TextAsset>\0PPtr<Texture>\0PPtr<Texture2D>\0PPtr<Transform>\0Prefab\0Quaternionf\0Rectf\0RectInt\0RectOffset\0second\0set\0short\0size\0SInt16\0SInt32\0SInt64\0SInt8\0staticvector\0string\0TextAsset\0TextMesh\0Texture\0Texture2D\0Transform\0TypelessData\0UInt16\0UInt32\0UInt64\0UInt8\0unsigned int\0unsigned long long\0unsigned short\0vector\0Vector2f\0Vector3f\0Vector4f\0m_ScriptingClassIdentifier\0Gradient\0Type*\0int2_storage\0int3_storage\0BoundsInt\0m_CorrespondingSourceObject\0m_PrefabInstance\0m_PrefabAsset\0FileSize\0Hash128\0"

private let ttCommonBytes: Bytes = Array(ttCommonStrings.utf8)

struct TTNode {
    var type: String
    var name: String
    var level: Int
    var meta: Int
}

enum TTValue {
    case int(Int64)
    case uint(UInt64)
    case double(Double)
    case bool(Bool)
    case string(String)
    case bytes(Bytes)
    case array([TTValue])
    case object([String: TTValue])

    subscript(key: String) -> TTValue? {
        if case .object(let d) = self { return d[key] }
        return nil
    }

    var int64: Int64? {
        switch self {
        case .int(let v): return v
        case .uint(let v): return Int64(bitPattern: v)
        case .double(let v): return Int64(v)
        case .bool(let b): return b ? 1 : 0
        default: return nil
        }
    }

    var double: Double? {
        switch self {
        case .double(let v): return v
        case .int(let v): return Double(v)
        case .uint(let v): return Double(v)
        default: return nil
        }
    }

    var string: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    var array: [TTValue]? {
        if case .array(let a) = self { return a }
        return nil
    }
}

struct TTTraceEntry {
    var node: String
    var start: Int
    var len: Int
    var val: String
}

/// Ghi lại vị trí byte của mọi chuỗi đọc được.
final class TTTrace {
    var entries: [TTTraceEntry] = []
}

final class TTReader {
    let data: Bytes
    var p = 0
    init(_ d: Bytes) { data = d }

    func need(_ n: Int) throws {
        if n < 0 || p < 0 || p + n > data.count { throw MakeToolsError("Đọc vượt vùng dữ liệu (typetree).") }
    }
    func align() { p = a4(p) }
}

struct TTTree {
    let nodes: [TTNode]
    let kids: [[Int]]

    static func build(_ t: SFType) throws -> TTTree {
        guard let tn = t.nodes, let sb = t.sb else { throw MakeToolsError("Type không có typetree.") }
        func sname(_ off: UInt32) -> String {
            let buf = (off & 0x80000000) != 0 ? ttCommonBytes : sb
            var o = Int(off & 0x7fffffff)
            var s = Bytes()
            while o < buf.count && buf[o] != 0 { s.append(buf[o]); o += 1 }
            return String(decoding: s, as: UTF8.self)
        }
        var nodes: [TTNode] = []
        nodes.reserveCapacity(tn.count)
        for n in tn { nodes.append(TTNode(type: sname(n.to), name: sname(n.no), level: n.level, meta: n.meta)) }
        var kids = [[Int]](repeating: [], count: nodes.count)
        var stack: [Int] = []
        for j in 0..<nodes.count {
            while let top = stack.last, nodes[top].level >= nodes[j].level { stack.removeLast() }
            if let top = stack.last { kids[top].append(j) }
            stack.append(j)
        }
        return TTTree(nodes: nodes, kids: kids)
    }

    func readValue(_ i: Int, _ r: TTReader, _ trace: TTTrace?) throws -> TTValue {
        let n = nodes[i]
        let doAlign = (n.meta & 0x4000) != 0
        let ks = kids[i]
        var v: TTValue
        switch n.type {
        case "SInt8":
            try r.need(1); v = .int(Int64(Int8(bitPattern: r.data[r.p]))); r.p += 1
        case "UInt8", "char":
            try r.need(1); v = .uint(UInt64(r.data[r.p])); r.p += 1
        case "SInt16", "short":
            try r.need(2); v = .int(Int64(Int16(bitPattern: UInt16(r.data.leU16(r.p))))); r.p += 2
        case "UInt16", "unsigned short":
            try r.need(2); v = .uint(UInt64(r.data.leU16(r.p))); r.p += 2
        case "SInt32", "int", "Type*":
            try r.need(4); v = .int(Int64(r.data.leI32(r.p))); r.p += 4
        case "UInt32", "unsigned int":
            try r.need(4); v = .uint(UInt64(r.data.leU32(r.p))); r.p += 4
        case "SInt64", "long long":
            try r.need(8); v = .int(r.data.leI64(r.p)); r.p += 8
        case "UInt64", "unsigned long long", "FileSize":
            try r.need(8); v = .uint(r.data.leU64(r.p)); r.p += 8
        case "float":
            try r.need(4); v = .double(Double(r.data.leF32(r.p))); r.p += 4
        case "double":
            try r.need(8); v = .double(r.data.leF64(r.p)); r.p += 8
        case "bool":
            try r.need(1); v = .bool(r.data[r.p] != 0); r.p += 1
        case "string":
            let st = r.p
            try r.need(4)
            let ln = Int(r.data.leI32(r.p)); r.p += 4
            try r.need(ln)
            let s = String(decoding: r.data.sub(r.p, r.p + ln), as: UTF8.self)
            r.p += ln
            r.align()
            trace?.entries.append(TTTraceEntry(node: n.name, start: st, len: ln, val: s))
            v = .string(s)
        case "TypelessData":
            try r.need(4)
            let ln = Int(r.data.leI32(r.p)); r.p += 4
            try r.need(ln)
            v = .bytes(r.data.sub(r.p, r.p + ln))
            r.p += ln
        default:
            if let first = ks.first, nodes[first].type == "Array" {
                let ai = first
                let ak = kids[ai]
                if ak.count < 2 { throw MakeToolsError("Mảng typetree thiếu phần tử mẫu.") }
                try r.need(4)
                let size = Int(r.data.leI32(r.p)); r.p += 4
                if size < 0 || size > 20_000_000 { throw MakeToolsError("Kích thước mảng bất thường: \(size)") }
                var list: [TTValue] = []
                list.reserveCapacity(Swift.min(size, 100_000))
                for _ in 0..<size { list.append(try readValue(ak[1], r, trace)) }
                if (nodes[ai].meta & 0x4000) != 0 { r.align() }
                v = .array(list)
            } else {
                var d: [String: TTValue] = [:]
                for c in ks { d[nodes[c].name] = try readValue(c, r, trace) }
                v = .object(d)
            }
        }
        if doAlign { r.align() }
        return v
    }

    /// Duyệt typetree chỉ để tìm offset của mọi `m_State.zTest` (float 4 byte) trong một Shader object.
    func findZTest(_ body: Bytes) throws -> [Int] {
        let r = TTReader(body)
        var hits: [Int] = []
        func walk(_ i: Int, _ inState: Bool) throws {
            let n = nodes[i]
            let align = (n.meta & 0x4000) != 0
            let ks = kids[i]
            let start = r.p
            switch n.type {
            case "SInt8", "UInt8", "char", "bool": try r.need(1); r.p += 1
            case "SInt16", "UInt16", "short", "unsigned short": try r.need(2); r.p += 2
            case "SInt32", "int", "Type*", "UInt32", "unsigned int", "float": try r.need(4); r.p += 4
            case "SInt64", "UInt64", "long long", "unsigned long long", "FileSize", "double": try r.need(8); r.p += 8
            case "string":
                try r.need(4)
                let ln = Int(r.data.leI32(r.p))
                r.p += 4
                try r.need(ln)
                r.p += ln
                r.align()
            case "TypelessData":
                try r.need(4)
                let ln = Int(r.data.leI32(r.p))
                r.p += 4
                try r.need(ln)
                r.p += ln
            default:
                if let first = ks.first, nodes[first].type == "Array" {
                    let ai = first
                    let ak = kids[ai]
                    if ak.count < 2 { throw MakeToolsError("Mảng typetree thiếu phần tử mẫu.") }
                    try r.need(4)
                    let size = Int(r.data.leI32(r.p))
                    r.p += 4
                    if size < 0 || size > 20_000_000 { throw MakeToolsError("Kích thước mảng bất thường.") }
                    for _ in 0..<size { try walk(ak[1], inState) }
                    if (nodes[ai].meta & 0x4000) != 0 { r.align() }
                } else {
                    for c in ks { try walk(c, inState || n.name == "m_State") }
                }
            }
            if align { r.align() }
            if n.name == "zTest" && inState { hits.append(start) }
        }
        try walk(0, false)
        return hits
    }
}

// MARK: - Dựng lại bundle

enum UnityRebuild {
    /// Ghi một chuỗi Unity: [int32 độ dài][bytes][đệm căn 4]
    static func wstr(_ s: String) -> Bytes {
        let sb = utf8Bytes(s)
        var f = Bytes(repeating: 0, count: a4(4 + sb.count))
        f.putU32LE(0, UInt32(sb.count))
        f.putBytes(4, sb)
        return f
    }

    /// Dựng lại CAB với các object đã thay.
    static func rebuildCab(_ sf: SerializedFile, _ repl: [Int64: Bytes]) throws -> Bytes {
        let old = Array(sf.cab[sf.dataOffset...])
        let order = sf.objs.sorted { $0.off < $1.off }
        var data = Bytes()
        var newOff: [Int64: Int] = [:]
        var prevEnd = 0
        for o in order {
            data.append(contentsOf: old.sub(prevEnd, o.off))
            let body = repl[o.pid] ?? old.sub(o.off, o.off + o.size)
            newOff[o.pid] = data.count
            data.append(contentsOf: body)
            prevEnd = o.off + o.size
        }
        data.append(contentsOf: old.sub(prevEnd, old.count))

        var meta = sf.cab.sub(0, sf.dataOffset)
        for o in sf.objs {
            if meta.leI64(o.ent) != o.pid { throw MakeToolsError("Lệch bảng object.") }
            let sz = repl[o.pid]?.count ?? o.size
            meta.putU32LE(o.ent + 8, UInt32(truncatingIfNeeded: newOff[o.pid] ?? 0))
            meta.putU32LE(o.ent + 12, UInt32(truncatingIfNeeded: (newOff[o.pid] ?? 0) >> 32))
            meta.putU32LE(o.ent + 16, UInt32(truncatingIfNeeded: sz))
        }
        let cabLen = sf.dataOffset + data.count
        meta.putI64BE(0x18, Int64(cabLen))         // m_FileSize (big-endian)
        return meta + data
    }

    /// Dựng lại bundle 1 block thô, tái dùng luồng LZ4 blocksInfo của file gốc.
    static func rebuildBundle(orig: Bytes, b: UnityBundle, cab: Bytes) throws -> Bytes {
        guard let node = b.nodes.first else { throw MakeToolsError("Bundle không có node nào.") }
        let sumU = b.blocks.reduce(0) { $0 + $1.u }
        let pad = sumU - node.size
        var block = cab
        if pad > 0 { block.append(contentsOf: Bytes(repeating: 0, count: pad)) }

        var info = b.info
        info.putU32BE(20, UInt32(block.count))     // block.u
        info.putU32BE(24, UInt32(block.count))     // block.c
        info.putI64BE(42, Int64(cab.count))        // node.size

        let ic = b.flags & 0x3F
        var infoOut: Bytes
        if ic == 0 {
            infoOut = info
        } else {
            // Vá thẳng các byte kích thước trong luồng LZ4 đã nén để giữ đúng độ dài bản gốc.
            let compOrig = orig.sub(b.infoOff, b.infoOff + b.ciSize)
            let root = LZ4.trace(compOrig, outSize: b.uiSize)
            var patched = compOrig
            var want: [Int: UInt8] = [:]
            for i in 0..<info.count {
                let src = i < root.count ? root[i] : -1
                if src < 0 {
                    if info[i] != b.info.at(i) { throw MakeToolsError("blocksInfo: byte \(i) không truy được về literal.") }
                    continue
                }
                if let w = want[src], w != info[i] {
                    throw MakeToolsError("blocksInfo: byte \(i) xung đột với byte khác dùng chung nguồn.")
                }
                want[src] = info[i]
            }
            for (src, v) in want { patched.putU8(src, v) }
            let check = try LZ4.decode(patched, outSize: b.uiSize)
            if check.count < info.count { throw MakeToolsError("blocksInfo vá xong không khớp.") }
            for i in 0..<info.count where check[i] != info[i] {
                throw MakeToolsError("blocksInfo vá xong không khớp.")
            }
            infoOut = patched
        }

        var head = Bytes()
        head.append(contentsOf: utf8Bytes("UnityFS")); head.append(0)
        var fb = Bytes(repeating: 0, count: 4)
        fb.putU32BE(0, UInt32(b.fmt))
        head.append(contentsOf: fb)
        head.append(contentsOf: utf8Bytes(b.uv)); head.append(0)
        head.append(contentsOf: utf8Bytes(b.rev)); head.append(0)
        var tailH = Bytes(repeating: 0, count: 20)
        tailH.putU32BE(8, UInt32(infoOut.count))
        tailH.putU32BE(12, UInt32(b.uiSize))
        tailH.putU32BE(16, UInt32(b.flags))
        head.append(contentsOf: tailH)
        let hl = head.count
        let padded = (b.fmt >= 7 || (b.flags & 0x200) != 0) ? ((hl + 15) & ~15) : hl
        var hdr = Bytes(repeating: 0, count: padded)
        hdr.putBytes(0, head)
        let sizePos = hl - 20
        let total = padded + infoOut.count + block.count
        hdr.putI64BE(sizePos, Int64(total))
        return hdr + infoOut + block
    }

    /// Dựng lại bundle shader sau khi thay/sơn shader: ghi đè tại chỗ vào luồng đã giải nén, nén lại
    /// đúng những block bị đụng, đệm 0 cho bằng dung lượng file nguồn.
    static func rebuildShaders(orig: Bytes, b: UnityBundle, data dataIn: Bytes, spans: [UnityBundle.BlockSpan],
                               sf: SerializedFile, node: UnityNode, repl: [Int64: Bytes]) throws -> Bytes {
        var data = dataIn
        var touched = Set<Int>()
        for o in sf.objs {
            guard let body = repl[o.pid] else { continue }
            if body.count != o.size {
                throw MakeToolsError("Object \(o.pid) đổi kích thước (\(o.size) → \(body.count)) — chưa hỗ trợ.")
            }
            let absOff = node.off + sf.dataOffset + o.off
            data.putBytes(absOff, body)
            for (i, s) in spans.enumerated() where absOff < s.end && absOff + body.count > s.start { touched.insert(i) }
        }
        if touched.isEmpty { throw MakeToolsError("Không có gì thay đổi.") }

        var parts: [Bytes] = []
        var newBlocks: [UnityBlock] = []
        for i in 0..<b.blocks.count {
            let blk = b.blocks[i]
            let at = spans[i]
            if !touched.contains(i) {
                parts.append(orig.sub(at.srcOff, at.srcOff + blk.c))
                newBlocks.append(UnityBlock(u: blk.u, c: blk.c, f: blk.f))
                continue
            }
            let raw = data.sub(at.start, at.end)
            var comp: Bytes
            var flags = blk.f
            if (blk.f & 0x3F) == 0 {
                comp = raw
            } else {
                comp = LZ4.encode(raw)
                let back = try LZ4.decode(comp, outSize: raw.count)
                if back != raw { throw MakeToolsError("Nén lại block \(i) sai.") }
                if comp.count >= raw.count { comp = raw; flags = blk.f & ~0x3F }
            }
            parts.append(comp)
            newBlocks.append(UnityBlock(u: blk.u, c: comp.count, f: flags))
        }

        var info = b.info
        var q = 20
        for nb in newBlocks {
            info.putU32BE(q, UInt32(nb.u))
            info.putU32BE(q + 4, UInt32(nb.c))
            info.putU16BE(q + 8, nb.f)
            q += 10
        }
        let infoOut: Bytes = (b.flags & 0x3F) == 0 ? info : LZ4.encode(info)

        let dataLen = parts.reduce(0) { $0 + $1.count }
        let atEnd = (b.flags & 0x80) != 0
        let headLen = atEnd ? b.dataStart : b.infoOff
        var core = headLen + dataLen + infoOut.count
        if !atEnd && (b.flags & 0x200) != 0 { core = ((headLen + infoOut.count + 15) & ~15) + dataLen }
        if core > orig.count {
            throw MakeToolsError("Nén lại phình \(core - orig.count) byte so với dung lượng gốc — không đủ chỗ đệm.")
        }

        var out = Bytes(repeating: 0, count: orig.count)
        if atEnd {
            out.putBytes(0, orig.sub(0, headLen))
            var p = headLen
            for x in parts { out.putBytes(p, x); p += x.count }
            out.putBytes(p, infoOut)
        } else {
            out.putBytes(0, orig.sub(0, b.infoOff))
            out.putBytes(b.infoOff, infoOut)
            var p = b.infoOff + infoOut.count
            if (b.flags & 0x200) != 0 { p = (p + 15) & ~15 }
            for x in parts { out.putBytes(p, x); p += x.count }
        }
        let sp = findSizePos(out)
        out.putI64BE(sp, Int64(atEnd ? core : out.count))
        out.putU32BE(sp + 8, UInt32(infoOut.count))     // ciSize
        out.putU32BE(sp + 12, UInt32(info.count))       // uiSize
        return out
    }

    /// Vị trí trường size (int64 BE) trong header UnityFS.
    static func findSizePos(_ u8: Bytes) -> Int {
        var p = 0
        while p < u8.count && u8[p] != 0 { p += 1 }      // "UnityFS"
        p += 1
        p += 4                                            // version
        while p < u8.count && u8[p] != 0 { p += 1 }; p += 1     // unityVersion
        while p < u8.count && u8[p] != 0 { p += 1 }; p += 1     // unityRevision
        return p
    }
}
