import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var audioManager: AudioManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple.opacity(0.3), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Drag indicator
                Capsule()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)

                Spacer()

                // Album art
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 280, height: 280)
                        .shadow(color: .purple.opacity(0.3), radius: 20, y: 10)

                    Image(systemName: "music.note")
                        .font(.system(size: 80))
                        .foregroundColor(.white.opacity(0.8))
                        .rotationEffect(.degrees(audioManager.isPlaying ? 360 : 0))
                        .animation(
                            audioManager.isPlaying
                                ? .linear(duration: 8).repeatForever(autoreverses: false)
                                : .default,
                            value: audioManager.isPlaying
                        )
                }

                Spacer()

                // Track info
                VStack(spacing: 6) {
                    Text(audioManager.currentTrack?.title ?? "No Track")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(audioManager.currentTrack?.artist ?? "")
                        .font(.body)
                        .foregroundColor(.gray)
                        .lineLimit(1)

                    Text(audioManager.currentTrack?.album ?? "")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.7))
                        .lineLimit(1)
                }
                .padding(.horizontal, 32)

                // Progress bar
                VStack(spacing: 8) {
                    Slider(
                        value: Binding(
                            get: { audioManager.currentTime },
                            set: { audioManager.seek(to: $0) }
                        ),
                        in: 0...max(audioManager.duration, 1)
                    )
                    .tint(.purple)

                    HStack {
                        Text(formatTime(audioManager.currentTime))
                            .font(.caption)
                            .foregroundColor(.gray)
                            .monospacedDigit()

                        Spacer()

                        Text("-\(formatTime(audioManager.duration - audioManager.currentTime))")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, 32)

                // Playback controls
                HStack(spacing: 40) {
                    Button(action: { audioManager.toggleShuffle() }) {
                        Image(systemName: "shuffle")
                            .font(.title3)
                            .foregroundColor(audioManager.isShuffled ? .purple : .gray)
                    }

                    Button(action: { audioManager.previous() }) {
                        Image(systemName: "backward.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }

                    Button(action: { audioManager.togglePlayPause() }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 64, height: 64)

                            Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title)
                                .foregroundColor(.black)
                        }
                    }

                    Button(action: { audioManager.next() }) {
                        Image(systemName: "forward.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }

                    Button(action: { audioManager.cycleRepeatMode() }) {
                        Image(systemName: repeatIcon)
                            .font(.title3)
                            .foregroundColor(audioManager.repeatMode != .off ? .purple : .gray)
                    }
                }
                .padding(.bottom, 16)

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var repeatIcon: String {
        switch audioManager.repeatMode {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
