import Foundation
import CoreLocation

@MainActor
final class AudioDropStore: ObservableObject {
    @Published private(set) var drops: [AudioDrop] = []

    private let metadataURL: URL
    private let audioDirectory: URL
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let baseDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        self.audioDirectory = baseDirectory.appendingPathComponent("HearHereAudio", isDirectory: true)
        self.metadataURL = audioDirectory.appendingPathComponent("drops.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
        prepareStore()
    }

    private func prepareStore() {
        do {
            if !fileManager.fileExists(atPath: audioDirectory.path) {
                try fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
            }
            try loadDrops()
        } catch {
            #if DEBUG
            print("AudioDropStore failed to prepare: \(error)")
            #endif
        }
    }

    func refresh() {
        try? loadDrops()
    }

    private func loadDrops() throws {
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            drops = []
            return
        }
        let data = try Data(contentsOf: metadataURL)
        let decoded = try decoder.decode([AudioDrop].self, from: data)
        drops = decoded.sorted(by: { $0.createdAt > $1.createdAt })
    }

    func addDrop(from sourceURL: URL, coordinate: CLLocationCoordinate2D, owner: String, notes: String) throws -> AudioDrop {
        let identifier = UUID()
        let filename = identifier.uuidString.appending(".m4a")
        let destination = audioDirectory.appendingPathComponent(filename)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: sourceURL, to: destination)

        let drop = AudioDrop(
            id: identifier,
            coordinate: .init(coordinate),
            audioFilename: filename,
            owner: owner,
            createdAt: Date(),
            notes: notes
        )
        drops.insert(drop, at: 0)
        try persistDrops()
        return drop
    }

    func url(for drop: AudioDrop) -> URL {
        audioDirectory.appendingPathComponent(drop.audioFilename)
    }

    private func persistDrops() throws {
        let data = try encoder.encode(drops)
        try data.write(to: metadataURL, options: .atomic)
    }
}
