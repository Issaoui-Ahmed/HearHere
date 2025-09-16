import Foundation
import Combine
import MapKit
import CoreLocation

@MainActor
final class AudioDropViewModel: ObservableObject {
    @Published var mapRegion: MKCoordinateRegion
    @Published private(set) var drops: [AudioDrop] = []
    @Published private(set) var selectedDrop: AudioDrop?
    @Published private(set) var currentLocation: CLLocation?
    @Published var showLocationPermissionAlert = false
    @Published var showMicrophonePermissionAlert = false
    @Published private(set) var statusMessage = "Initializing..."
    @Published private(set) var statusIconName = "waveform"
    @Published private(set) var isRecording = false
    @Published var displayName: String = ""
    @Published var notes: String = ""

    var canRecord: Bool {
        !isRecording && microphonePermissionGranted && currentLocation != nil
    }

    private let locationManager: LocationManager
    private let dropStore: AudioDropStore
    private let audioRecorder: AudioRecorder
    private let audioPlayer: AudioPlayer
    private var cancellables: Set<AnyCancellable> = []
    private var microphonePermissionGranted = false
    private let isPreview: Bool

    init(
        locationManager: LocationManager = LocationManager(),
        dropStore: AudioDropStore = AudioDropStore(),
        audioRecorder: AudioRecorder = AudioRecorder(),
        audioPlayer: AudioPlayer = AudioPlayer(),
        isPreview: Bool = false
    ) {
        self.locationManager = locationManager
        self.dropStore = dropStore
        self.audioRecorder = audioRecorder
        self.audioPlayer = audioPlayer
        self.isPreview = isPreview
        self.mapRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.00902),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )

        if !isPreview {
            setupBindings()
            refreshDrops()
        } else {
            microphonePermissionGranted = true
        }
    }

    func onAppear() async {
        guard !isPreview else { return }
        locationManager.requestAuthorization()
        await ensureMicrophonePermission()
        updateStatusForCurrentState()
    }

    func refreshDrops() {
        dropStore.refresh()
        drops = dropStore.drops
    }

    func updateRegion(_ region: MKCoordinateRegion) {
        mapRegion = region
    }

    func recenterMap() {
        if let location = currentLocation {
            mapRegion.center = location.coordinate
        } else {
            statusMessage = "Waiting for your location..."
            statusIconName = "location.magnifyingglass"
        }
    }

    func select(_ drop: AudioDrop) {
        selectedDrop = drop
    }

    func play(_ drop: AudioDrop) {
        do {
            try audioPlayer.play(url: dropStore.url(for: drop))
            selectedDrop = drop
            statusMessage = "Playing \(drop.title)'s drop"
            statusIconName = "play.circle.fill"
        } catch {
            statusMessage = "Playback failed"
            statusIconName = "exclamationmark.triangle"
        }
    }

    func toggleRecording() {
        if isRecording {
            Task { await finishRecording() }
        } else {
            Task { await beginRecording() }
        }
    }

    private func beginRecording() async {
        guard await ensureMicrophonePermission() else {
            showMicrophonePermissionAlert = true
            return
        }

        guard let _ = currentLocation else {
            statusMessage = "Waiting for your location before recording"
            statusIconName = "location.magnifyingglass"
            return
        }

        do {
            _ = try audioRecorder.startRecording()
            isRecording = true
            statusMessage = "Recording in progress"
            statusIconName = "waveform.badge.mic"
        } catch {
            statusMessage = "Unable to start recording"
            statusIconName = "exclamationmark.triangle"
        }
    }

    private func finishRecording() async {
        let recordedURL = audioRecorder.stopRecording()
        isRecording = false

        guard let recordedURL else {
            statusMessage = "Recording failed"
            statusIconName = "exclamationmark.triangle"
            return
        }

        guard let location = currentLocation else {
            statusMessage = "Missing location for drop"
            statusIconName = "location.slash"
            try? FileManager.default.removeItem(at: recordedURL)
            return
        }

        do {
            let drop = try dropStore.addDrop(
                from: recordedURL,
                coordinate: location.coordinate,
                owner: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            selectedDrop = drop
            drops = dropStore.drops
            notes = ""
            statusMessage = "Audio dropped!"
            statusIconName = "mappin.circle.fill"
        } catch {
            statusMessage = "Could not save audio drop"
            statusIconName = "exclamationmark.triangle"
        }

        try? FileManager.default.removeItem(at: recordedURL)
    }

    private func ensureMicrophonePermission() async -> Bool {
        if microphonePermissionGranted {
            return true
        }
        let granted = await audioRecorder.requestPermission()
        microphonePermissionGranted = granted
        if !granted {
            showMicrophonePermissionAlert = true
            statusMessage = "Microphone access denied"
            statusIconName = "mic.slash"
        }
        return granted
    }

    private func setupBindings() {
        locationManager.$location
            .sink { [weak self] location in
                guard let self else { return }
                self.currentLocation = location
                if let location {
                    self.mapRegion.center = location.coordinate
                    self.statusMessage = "Listening near \(self.locationDescription(for: location))"
                    self.statusIconName = "location.fill"
                } else {
                    self.statusMessage = "Searching for your location"
                    self.statusIconName = "location.magnifyingglass"
                }
            }
            .store(in: &cancellables)

        locationManager.$authorizationStatus
            .removeDuplicates()
            .sink { [weak self] status in
                self?.handleAuthorizationStatus(status)
            }
            .store(in: &cancellables)

        dropStore.$drops
            .sink { [weak self] drops in
                self?.drops = drops
            }
            .store(in: &cancellables)
    }

    private func handleAuthorizationStatus(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            showLocationPermissionAlert = false
        case .denied, .restricted:
            showLocationPermissionAlert = true
            statusMessage = "Location access denied"
            statusIconName = "location.slash"
        case .notDetermined:
            statusMessage = "Requesting location access"
            statusIconName = "location"
        @unknown default:
            statusMessage = "Location status unknown"
            statusIconName = "questionmark.circle"
        }
    }

    private func updateStatusForCurrentState() {
        if currentLocation == nil {
            statusMessage = "Searching for your location"
            statusIconName = "location.magnifyingglass"
        } else {
            statusMessage = "Ready to drop audio"
            statusIconName = "waveform"
        }
    }

    private func locationDescription(for location: CLLocation) -> String {
        "\(String(format: "%.3f", location.coordinate.latitude)), \(String(format: "%.3f", location.coordinate.longitude))"
    }
}

extension AudioDropViewModel {
    static var preview: AudioDropViewModel {
        let viewModel = AudioDropViewModel(
            locationManager: LocationManager(),
            dropStore: AudioDropStore(),
            audioRecorder: AudioRecorder(),
            audioPlayer: AudioPlayer(),
            isPreview: true
        )
        viewModel.drops = [
            AudioDrop(
                id: UUID(),
                coordinate: .init(latitude: 37.3349, longitude: -122.00902),
                audioFilename: "preview-1.m4a",
                owner: "Previewer",
                createdAt: Date(),
                notes: "Welcome to HearHere"
            )
        ]
        viewModel.currentLocation = CLLocation(latitude: 37.3349, longitude: -122.00902)
        viewModel.mapRegion.center = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.00902)
        viewModel.statusMessage = "Previewing nearby drops"
        viewModel.statusIconName = "waveform"
        return viewModel
    }
}
