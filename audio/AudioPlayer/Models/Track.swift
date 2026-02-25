import Foundation

struct Track: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let artist: String
    let album: String
    let fileName: String
    let fileExtension: String
    let duration: TimeInterval
    let artwork: String?

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }
}
