import XCTest
import HAPCore
import HAPSwift
import HAPApple
@testable import macOSBridge

final class VirtualBridgeServiceTests: XCTestCase {
    func test_detectedIID_locatesDetectedCharacteristic() async {
        let bridge = HAPBridge(info: HAPCore.AccessoryInfo(
            name: "T", manufacturer: "I", model: "M", serialNumber: "S", firmwareRevision: "1"))
        let aid = await bridge.addAccessory(
            info: HAPCore.AccessoryInfo(name: "Leak", manufacturer: "I", model: "M",
                                        serialNumber: "L1", firmwareRevision: "1"),
            services: [VirtualSensorType.leak.makeHAPService(startIID: 2)])

        guard let iid = await VirtualBridgeService.detectedIID(in: bridge, aid: aid, type: .leak) else {
            return XCTFail("no detected characteristic iid found")
        }
        let value = await bridge.readCharacteristic(aid: aid, iid: iid)
        XCTAssertNotNil(value)
    }
}
