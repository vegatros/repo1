import SwiftUI

struct TrackListView: View {
    @EnvironmentObject var audioManager: AudioManager

    var body: some View {
        if audioManager.tracks.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "music.note.list")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                Text("No Tracks Found")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text("Add audio files to the app bundle\nto see them here.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                Spacer()
            }
        } else {
            List {
                ForEach(audioManager.tracks) { track in
                    TrackRowView(track: track)
                        .onTapGesture {
                            audioManager.play(track: track)
                        }
                        .listRowBackground(
                            audioManager.currentTrack == track
                                ? Color.white.opacity(0.08)
                                : Color.clear
                        )
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

struct TrackRowView: View {
    @EnvironmentObject var audioManager: AudioManager
    let track: Track

    private var isCurrentTrack: Bool {
        audioManager.currentTrack == track
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                Image(systemName: isCurrentTrack && audioManager.isPlaying ? "waveform" : "music.note")
                    .font(.title3)
                    .foregroundColor(.white)
                    .symbolEffect(.variableColor.iterative, isActive: isCurrentTrack && audioManager.isPlaying)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(isCurrentTrack ? .purple : .white)
                    .lineLimit(1)

                Text("\(track.artist) — \(track.album)")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            Text(track.formattedDuration)
                .font(.caption)
                .foregroundColor(.gray)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
