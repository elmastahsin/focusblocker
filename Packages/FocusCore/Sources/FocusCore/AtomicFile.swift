import Foundation

public struct FileWriteError: Error, CustomStringConvertible {
    public let operation: String
    public let path: String
    public let code: Int32

    public var description: String {
        "\(operation) failed for \(path): \(String(cString: strerror(code)))"
    }
}

public enum AtomicFile {
    /// Writes to a temp file next to the target, fsyncs, then renames over the target.
    /// Symlinks in `url` (e.g. /etc -> /private/etc) are resolved first so rename stays on one volume.
    public static func write(_ data: Data,
                             to url: URL,
                             mode: mode_t,
                             owner: (uid: uid_t, gid: gid_t)? = nil) throws {
        let target = url.resolvingSymlinksInPath()
        let temp = target.deletingLastPathComponent()
            .appendingPathComponent(".\(target.lastPathComponent).focusblocker-tmp")
        unlink(temp.path)

        let fd = open(temp.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, mode)
        guard fd >= 0 else { throw FileWriteError(operation: "open", path: temp.path, code: errno) }

        do {
            try writeAll(data, to: fd, path: temp.path)
            try check(fchmod(fd, mode), "fchmod", temp.path)
            if let owner { try check(fchown(fd, owner.uid, owner.gid), "fchown", temp.path) }
            try check(fsync(fd), "fsync", temp.path)
        } catch {
            close(fd)
            unlink(temp.path)
            throw error
        }
        close(fd)

        if rename(temp.path, target.path) != 0 {
            let code = errno
            unlink(temp.path)
            throw FileWriteError(operation: "rename", path: target.path, code: code)
        }
    }

    private static func check(_ result: Int32, _ operation: String, _ path: String) throws {
        guard result == 0 else { throw FileWriteError(operation: operation, path: path, code: errno) }
    }

    private static func writeAll(_ data: Data, to fd: Int32, path: String) throws {
        try data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            var offset = 0
            while offset < buffer.count {
                let n = Darwin.write(fd, buffer.baseAddress!.advanced(by: offset), buffer.count - offset)
                if n < 0 {
                    if errno == EINTR { continue }
                    throw FileWriteError(operation: "write", path: path, code: errno)
                }
                offset += n
            }
        }
    }
}
