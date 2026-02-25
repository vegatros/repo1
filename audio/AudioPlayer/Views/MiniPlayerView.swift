import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var audioManager: AudioManager
    @State private var showFullPlayer = false

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: audioManager.currentTime, total: max(audioManager.duration, 1))
                .tint(.purple)
                .scaleEffect(y: 0.5)

            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: "music.note")
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(audioManager.currentTrack?.title ?? "")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(audioManager.currentTrack?.artist ?? "")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                Spacer()

                Button(action: { audioManager.previous() }) {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }

                Button(action: { audioManager.togglePlayPause() }) {
                    Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 32)
                }

                Button(action: { audioManager.next() }) {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
        .onTapGesture {
            showFullPlayer = true
        }
        .sheet(isPresented: $showFullPlayer) {
            NowPlayingView()
        }
    }
}
