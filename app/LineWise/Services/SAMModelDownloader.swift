import CryptoKit
import Foundation

protocol ModelDownloadTransport: Sendable {
    func download(_ url: URL, progress: @escaping @Sendable (Int64) -> Void) async throws -> URL
}

struct ModelNetworkTransport: ModelDownloadTransport {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 600
        session = URLSession(configuration: config)
    }

    func download(_ url: URL, progress: @escaping @Sendable (Int64) -> Void) async throws -> URL {
        let (temporary, response) = try await session.download(from: url, delegate: DownloadProgress(progress))
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            try? FileManager.default.removeItem(at: temporary)
            throw SAMDownloadError.serverResponse
        }
        return temporary
    }

    private final class DownloadProgress: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
        let report: @Sendable (Int64) -> Void
        init(_ report: @escaping @Sendable (Int64) -> Void) { self.report = report }
        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                        didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
            report(totalBytesWritten)
        }
        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
    }
}

enum SAMDownloadError: Error { case invalidCatalog, serverResponse, integrityCheck, alreadyDownloading }

/// Download to a private staging folder. Only a complete, verified revision becomes available.
actor SAMModelDownloader {
    let catalog: SAMModelCatalog
    let root: URL
    private let transport: any ModelDownloadTransport
    private var downloading = false

    init(catalog: SAMModelCatalog = .tiny, root: URL? = nil, transport: any ModelDownloadTransport = ModelNetworkTransport()) {
        self.catalog = catalog
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HoldModels", isDirectory: true)
        self.transport = transport
    }

    func installedDirectory() throws -> URL? {
        try validateCatalog()
        let directory = root.appendingPathComponent(catalog.version, isDirectory: true)
        return catalog.files.allSatisfy { valid(directory.appendingPathComponent($0.path), file: $0) } ? directory : nil
    }

    func install(progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        try validateCatalog()
        guard !downloading else { throw SAMDownloadError.alreadyDownloading }
        downloading = true
        defer { downloading = false }
        if let installed = try installedDirectory() { progress(1); return installed }

        let staging = root.appendingPathComponent(catalog.version + ".partial", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        var backupValues = URLResourceValues(); backupValues.isExcludedFromBackup = true
        var stagingURL = staging
        try stagingURL.setResourceValues(backupValues)
        var completed: Int64 = 0
        for file in catalog.files {
            try Task.checkCancellation()
            let destination = staging.appendingPathComponent(file.path)
            if !valid(destination, file: file) {
                let before = completed, total = catalog.totalBytes
                let temporary = try await transport.download(catalog.sourceURL(for: file)) { bytes in
                    progress(Double(before + min(file.bytes, max(0, bytes))) / Double(total))
                }
                defer { try? FileManager.default.removeItem(at: temporary) }
                try Task.checkCancellation()
                guard valid(temporary, file: file) else { throw SAMDownloadError.integrityCheck }
                try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
                try FileManager.default.moveItem(at: temporary, to: destination)
            }
            completed += file.bytes
            progress(Double(completed) / Double(catalog.totalBytes))
        }
        try Task.checkCancellation()
        let installed = root.appendingPathComponent(catalog.version, isDirectory: true)
        if FileManager.default.fileExists(atPath: installed.path) { try FileManager.default.removeItem(at: installed) }
        try FileManager.default.moveItem(at: staging, to: installed)
        // Downloaded weights are replaceable and must not fill an iCloud device backup.
        var resource = URLResourceValues(); resource.isExcludedFromBackup = true
        var installedURL = installed
        try installedURL.setResourceValues(resource)
        progress(1)
        return installed
    }

    private func validateCatalog() throws {
        let safe = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._")
        guard !catalog.revision.isEmpty, catalog.revision.unicodeScalars.allSatisfy(safe.contains),
              !catalog.files.isEmpty, catalog.totalBytes > 0, catalog.totalBytes <= 100_000_000,
              Set(catalog.files.map(\.path)).count == catalog.files.count,
              catalog.files.allSatisfy({ f in
                  f.bytes > 0 && f.sha256.count == 64 && f.sha256.allSatisfy { $0.isHexDigit } &&
                  f.path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy {
                      !$0.isEmpty && $0 != "." && $0 != ".." && $0.unicodeScalars.allSatisfy(safe.contains)
                  }
              }) else { throw SAMDownloadError.invalidCatalog }
    }

    private func valid(_ url: URL, file: SAMModelFile) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              (attributes[.size] as? NSNumber)?.int64Value == file.bytes,
              let digest = try? Self.sha256(of: url) else { return false }
        return digest == file.sha256
    }

    static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash = SHA256()
        while let chunk = try handle.read(upToCount: 64 * 1024), !chunk.isEmpty {
            try Task.checkCancellation()
            hash.update(data: chunk)
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
