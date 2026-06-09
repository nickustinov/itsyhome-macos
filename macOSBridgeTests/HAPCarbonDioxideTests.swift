import XCTest
import HAPCore
@testable import macOSBridge

final class HAPCarbonDioxideTests: XCTestCase {
    func test_carbonDioxideSensor_hasDetectedCharacteristic() {
        let svc = HAPService.carbonDioxideSensor(startIID: 2)
        XCTAssertEqual(svc.type, .carbonDioxideSensor)
        XCTAssertEqual(svc.characteristics.count, 1)
        let ch = svc.characteristics[0]
        XCTAssertEqual(ch.type, .carbonDioxideDetected)
        XCTAssertEqual(ch.iid, 2)
        XCTAssertEqual(ch.value, .uint8(0))
    }

    func test_carbonDioxide_typeRawValues_matchHomeKit() {
        XCTAssertEqual(HAPServiceType.carbonDioxideSensor.rawValue, "97")
        XCTAssertEqual(HAPCharacteristicType.carbonDioxideDetected.rawValue, "92")
    }
}
