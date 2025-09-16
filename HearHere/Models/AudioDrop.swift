import Foundation
import CoreLocation

struct AudioDrop: Identifiable, Codable {
    struct Coordinate: Codable, Hashable {
        var latitude: Double
        var longitude: Double

        var clCoordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        init(latitude: Double, longitude: Double) {
            self.latitude = latitude
            self.longitude = longitude
        }

        init(_ coordinate: CLLocationCoordinate2D) {
            self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
    }

    var id: UUID
    var coordinate: Coordinate
    var audioFilename: String
    var owner: String
    var createdAt: Date
    var notes: String
}

extension AudioDrop {
    static let placeholder = AudioDrop(
        id: UUID(),
        coordinate: .init(latitude: 37.3349, longitude: -122.00902),
        audioFilename: "sample.m4a",
        owner: "Previewer",
        createdAt: .now,
        notes: "Sample audio drop"
    )

    var title: String {
        owner.isEmpty ? "Someone" : owner
    }

    func distance(from location: CLLocation?) -> Measurement<UnitLength>? {
        guard let location else { return nil }
        let dropLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return Measurement(value: dropLocation.distance(from: location), unit: .meters)
    }
}
