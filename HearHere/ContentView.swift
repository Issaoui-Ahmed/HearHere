import SwiftUI
import MapKit

struct ContentView: View {
    @ObservedObject var viewModel: AudioDropViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            mapView
                .ignoresSafeArea()

            VStack(spacing: 12) {
                statusBanner

                metadataFields

                recordingControls

                dropList
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.95)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding()
        }
        .task {
            await viewModel.onAppear()
        }
        .alert("Permission Needed", isPresented: $viewModel.showLocationPermissionAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("HearHere needs access to your location to drop and discover audio clips.")
        }
        .alert("Microphone Restricted", isPresented: $viewModel.showMicrophonePermissionAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enable microphone access in Settings to record new audio drops.")
        }
    }

    private var mapView: some View {
        Map(
            coordinateRegion: Binding(
                get: { viewModel.mapRegion },
                set: { viewModel.updateRegion($0) }
            ),
            interactionModes: .all,
            showsUserLocation: true,
            annotationItems: viewModel.drops
        ) { drop in
            MapAnnotation(coordinate: drop.coordinate.clCoordinate) {
                AudioDropAnnotationView(isSelected: drop.id == viewModel.selectedDrop?.id)
                    .onTapGesture {
                        viewModel.select(drop)
                    }
            }
        }
    }

    private var statusBanner: some View {
        HStack {
            Label(viewModel.statusMessage, systemImage: viewModel.statusIconName)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            if let location = viewModel.currentLocation {
                Text("Lat: \(location.coordinate.latitude, specifier: "%.3f"), Lng: \(location.coordinate.longitude, specifier: "%.3f")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var metadataFields: some View {
        VStack(spacing: 8) {
            TextField("Your name (optional)", text: $viewModel.displayName)
                .textFieldStyle(.roundedBorder)
            TextField("Leave a note for listeners", text: $viewModel.notes)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var recordingControls: some View {
        VStack(spacing: 8) {
            if viewModel.isRecording {
                Label("Recording...", systemImage: "waveform.badge.mic")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
            HStack(spacing: 16) {
                Button(action: viewModel.toggleRecording) {
                    Label(viewModel.isRecording ? "Stop Recording" : "Drop Audio", systemImage: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.isRecording ? .red : .blue)
                .disabled(!viewModel.canRecord)

                Button(action: viewModel.recenterMap) {
                    Label("Recenter", systemImage: "location.circle.fill")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var dropList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Nearby Drops")
                    .font(.headline)
                Spacer()
                Button(action: viewModel.refreshDrops) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }

            if viewModel.drops.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("No audio drops yet", systemImage: "ear")
                        .foregroundStyle(.secondary)
                    Text("Record a clip to leave behind something to hear here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(viewModel.drops) { drop in
                            AudioDropCardView(drop: drop, isSelected: drop.id == viewModel.selectedDrop?.id, playAction: {
                                viewModel.play(drop)
                            })
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

struct AudioDropCardView: View {
    let drop: AudioDrop
    let isSelected: Bool
    let playAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "waveform")
                Text(drop.owner.isEmpty ? "Someone" : drop.owner)
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                Text(drop.createdAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(drop.notes.isEmpty ? "Tap play to listen" : drop.notes)
                .font(.caption)
                .lineLimit(2)

            Button(action: playAction) {
                Label("Listen", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 220)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? Color.blue.opacity(0.15) : Color(.secondarySystemBackground))
        )
    }
}

struct AudioDropAnnotationView: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? .blue : .teal)
                .frame(width: 32, height: 32)
            Image(systemName: "waveform")
                .foregroundStyle(.white)
        }
        .shadow(radius: 4)
    }
}

#Preview {
    ContentView(viewModel: AudioDropViewModel.preview)
}
