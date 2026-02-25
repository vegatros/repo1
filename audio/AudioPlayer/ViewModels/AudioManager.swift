import Foundation
import AVFoundation
import MediaPlayer
import Combine

enum RepeatMode {
    case off, all, one
}

class AudioManager: ObservableObject {
    @Published var tracks: [Track] = []
    @Published var currentTrack: Track?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isShuffled = false
    @Published var repeatMode: RepeatMode = .off

    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var originalOrder: [Track] = []

    init() {
        setupAudioSession()
        loadTracks()
        setupRemoteControls()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    func loadTracks() {
        let bundle = Bundle.main
        let supportedExtensions = ["mp3", "m4a", "wav", "aac", "flac", "aiff"]

        var discovered: [Track] = []

        for ext in supportedExtensions {
            if let urls = bundle.urls(forResourcesWithExtension: ext, subdirectory: nil) {
                for url in urls {
                    let asset = AVURLAsset(url: url)
                    let metadata = asset.metadata

                    let title = metadata.first(where: { $0.commonKey == .commonKeyTitle })?.stringValue
                        ?? url.deletingPathExtension().lastPathComponent
                    let artist = metadata.first(where: { $0.commonKey == .commonKeyArtist })?.stringValue
                        ?? "Unknown Artist"
                    let album = metadata.first(where: { $0.commonKey == .commonKeyAlbumName })?.stringValue
                        ?? "Unknown Album"

                    let durationSeconds = CMTimeGetSeconds(asset.duration)

                    let track = Track(
                        title: title,
                        artist: artist,
                        album: album,
                        fileName: url.deletingPathExtension().lastPathComponent,
                        fileExtension: ext,
                        duration: durationSeconds.isNaN ? 0 : durationSeconds,
                        artwork: nil
                    )
                    discovered.append(track)
                }
            }
        }

        tracks = discovered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        originalOrder = tracks
    }

    func play(track: Track) {
        guard let url = Bundle.main.url(forResource: track.fileName, withExtension: track.fileExtension) else {
            print("File not found: \(track.fileName).\(track.fileExtension)")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.play()
            currentTrack = track
            isPlaying = true
            duration = player?.duration ?? 0
            startTimer()
            updateNowPlaying()
        } catch {
            print("Playback error: \(error)")
        }
    }

    func togglePlayPause() {
        guard let player = player else { return }

        if player.isPlaying {
            player.pause()
            isPlaying = false
            stopTimer()
        } else {
            player.play()
            isPlaying = true
            startTimer()
        }
        updateNowPlaying()
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
        updateNowPlaying()
    }

    func next() {
        guard let current = currentTrack,
              let index = tracks.firstIndex(of: current) else { return }

        if repeatMode == .one {
            seek(to: 0)
            player?.play()
            isPlaying = true
            return
        }

        let nextIndex = (index + 1) % tracks.count
        if nextIndex == 0 && repeatMode == .off {
            stop()
            return
        }
        play(track: tracks[nextIndex])
    }

    func previous() {
        if currentTime > 3 {
            seek(to: 0)
            return
        }

        guard let current = currentTrack,
              let index = tracks.firstIndex(of: current) else { return }

        let prevIndex = index > 0 ? index - 1 : tracks.count - 1
        play(track: tracks[prevIndex])
    }

    func stop() {
        player?.stop()
        isPlaying = false
        currentTime = 0
        stopTimer()
    }

    func toggleShuffle() {
        isShuffled.toggle()
        if isShuffled {
            let current = currentTrack
            tracks.shuffle()
            if let current = current, let index = tracks.firstIndex(of: current) {
                tracks.remove(at: index)
                tracks.insert(current, at: 0)
            }
        } else {
            tracks = originalOrder
        }
    }

    func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.currentTime = player.currentTime

            if !player.isPlaying && self.isPlaying && player.currentTime >= player.duration - 0.1 {
                self.next()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func setupRemoteControls() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: event.positionTime)
            }
            return .success
        }
    }

    private func updateNowPlaying() {
        guard let track = currentTrack else { return }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
