import XCTest
import HAPCore
@testable import macOSBridge

final class VirtualSensorMappingTests: XCTestCase {
    func test_eachType_mapsToHAPService() {
        let expected: [VirtualSensorType: HAPServiceType] = [
            .contact: .contactSensor, .motion: .motionSensor, .occupancy: .occupancySensor,
            .leak: .leakSensor, .smoke: .smokeSensor,
            .carbonMonoxide: .carbonMonoxideSensor, .carbonDioxide: .carbonDioxideSensor,
        ]
        for t in VirtualSensorType.allCases {
            let svc = t.makeHAPService(startIID: 2)
            XCTAssertEqual(svc.type, expected[t], "wrong service for \(t)")
            XCTAssertEqual(svc.characteristics.count, 1)
        }
    }

    func test_homeKitServiceTypeString_matchesServiceTypesConstant() {
        // Used by the MenuData projection; must match Itsyhome/Shared ServiceTypes.
        XCTAssertEqual(VirtualSensorType.contact.homeKitServiceType, ServiceTypes.contactSensor)
        XCTAssertEqual(VirtualSensorType.motion.homeKitServiceType, ServiceTypes.motionSensor)
    }
}
