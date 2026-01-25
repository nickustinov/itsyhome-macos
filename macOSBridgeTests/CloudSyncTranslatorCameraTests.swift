//
//  CloudSyncTranslatorCameraTests.swift
//  macOSBridgeTests
//
//  Tests for camera ID and overlay translation
//

import XCTest
@testable import macOSBridge

final class CloudSyncTranslatorCameraTests: CloudSyncTranslatorTestCase {

    // MARK: - Camera ID translation tests

    func testUpdateMenuDataBuildsCameraLookups() {
        let cameraId = UUID()
        let data = makeMenuData(cameras: [CameraData(uniqueIdentifier: cameraId, name: "Front Door")])

        translator.updateMenuData(data)

        XCTAssertEqual(translator.cameraIdToName[cameraId.uuidString], "Front Door")
        XCTAssertEqual(translator.cameraNameToId["Front Door"], cameraId.uuidString)
    }

    func testTranslateCameraIdsToStable() {
        let camId = UUID()
        let data = makeMenuData(cameras: [CameraData(uniqueIdentifier: camId, name: "Backyard")])
        translator.updateMenuData(data)

        let result = translator.translateIdsToStable([camId.uuidString], type: .camera)

        XCTAssertEqual(result, ["Backyard"])
    }

    func testTranslateStableToCameraIds() {
        let camId = UUID()
        let data = makeMenuData(cameras: [CameraData(uniqueIdentifier: camId, name: "Backyard")])
        translator.updateMenuData(data)

        let result = translator.translateStableToIds(["Backyard"], type: .camera)

        XCTAssertEqual(result, [camId.uuidString])
    }

    func testCameraIdRoundTrip() {
        let camId = UUID()
        let data = makeMenuData(cameras: [CameraData(uniqueIdentifier: camId, name: "Garage")])
        translator.updateMenuData(data)

        let ids = [camId.uuidString]
        let names = translator.translateIdsToStable(ids, type: .camera)
        let backToIds = translator.translateStableToIds(names, type: .camera)

        XCTAssertEqual(backToIds, ids)
    }

    func testCameraTranslationPreservesOrder() {
        let cam1 = UUID()
        let cam2 = UUID()
        let cam3 = UUID()
        let data = makeMenuData(cameras: [
            CameraData(uniqueIdentifier: cam1, name: "Front"),
            CameraData(uniqueIdentifier: cam2, name: "Back"),
            CameraData(uniqueIdentifier: cam3, name: "Side")
        ])
        translator.updateMenuData(data)

        let result = translator.translateIdsToStable(
            [cam3.uuidString, cam1.uuidString, cam2.uuidString],
            type: .camera
        )

        XCTAssertEqual(result, ["Side", "Front", "Back"])
    }

    func testCameraTranslationDropsUnknownIds() {
        let data = makeMenuData(cameras: [CameraData(uniqueIdentifier: UUID(), name: "Known")])
        translator.updateMenuData(data)

        let result = translator.translateIdsToStable([UUID().uuidString], type: .camera)

        XCTAssertTrue(result.isEmpty)
    }

    func testCameraCrossDeviceTranslation() {
        let mac1CamId = UUID()
        let mac1Data = makeMenuData(cameras: [CameraData(uniqueIdentifier: mac1CamId, name: "Front Door")])
        var mac1Translator = CloudSyncTranslator()
        mac1Translator.updateMenuData(mac1Data)

        let stableNames = mac1Translator.translateIdsToStable([mac1CamId.uuidString], type: .camera)

        let mac2CamId = UUID()
        let mac2Data = makeMenuData(cameras: [CameraData(uniqueIdentifier: mac2CamId, name: "Front Door")])
        var mac2Translator = CloudSyncTranslator()
        mac2Translator.updateMenuData(mac2Data)

        let mac2Ids = mac2Translator.translateStableToIds(stableNames, type: .camera)

        XCTAssertEqual(mac2Ids, [mac2CamId.uuidString])
        XCTAssertNotEqual(mac2Ids, [mac1CamId.uuidString])
    }

    // MARK: - Camera overlay accessories translation tests

    func testTranslateCameraOverlaysToCloud() throws {
        let roomId = UUID()
        let camId = UUID()
        let svcId = UUID()
        let service = makeService(id: svcId, name: "Light", accessoryName: "Lamp", roomId: roomId)
        let accessory = makeAccessory(name: "Lamp", roomId: roomId, services: [service])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Bedroom")],
            accessories: [accessory],
            cameras: [CameraData(uniqueIdentifier: camId, name: "Hallway")]
        )
        translator.updateMenuData(data)

        let overlays: [String: [String]] = [camId.uuidString: [svcId.uuidString]]
        let localData = try JSONEncoder().encode(overlays)

        let cloudData = translator.translateCameraOverlaysToCloud(localData)!
        let decoded = try JSONDecoder().decode([String: [String]].self, from: cloudData)

        XCTAssertEqual(decoded["Hallway"], ["Bedroom::Lamp::Light"])
    }

    func testTranslateCameraOverlaysFromCloud() throws {
        let roomId = UUID()
        let camId = UUID()
        let svcId = UUID()
        let service = makeService(id: svcId, name: "Light", accessoryName: "Lamp", roomId: roomId)
        let accessory = makeAccessory(name: "Lamp", roomId: roomId, services: [service])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Bedroom")],
            accessories: [accessory],
            cameras: [CameraData(uniqueIdentifier: camId, name: "Hallway")]
        )
        translator.updateMenuData(data)

        let cloudOverlays: [String: [String]] = ["Hallway": ["Bedroom::Lamp::Light"]]
        let cloudData = try JSONEncoder().encode(cloudOverlays)

        let localData = translator.translateCameraOverlaysFromCloud(cloudData)!
        let decoded = try JSONDecoder().decode([String: [String]].self, from: localData)

        XCTAssertEqual(decoded[camId.uuidString], [svcId.uuidString])
    }

    func testCameraOverlaysRoundTrip() throws {
        let roomId = UUID()
        let camId = UUID()
        let svc1Id = UUID()
        let svc2Id = UUID()
        let s1 = makeService(id: svc1Id, name: "Light", accessoryName: "Lamp", roomId: roomId)
        let s2 = makeService(id: svc2Id, name: "Fan", accessoryName: "Lamp", roomId: roomId)
        let accessory = makeAccessory(name: "Lamp", roomId: roomId, services: [s1, s2])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Bedroom")],
            accessories: [accessory],
            cameras: [CameraData(uniqueIdentifier: camId, name: "Hallway")]
        )
        translator.updateMenuData(data)

        let original: [String: [String]] = [camId.uuidString: [svc1Id.uuidString, svc2Id.uuidString]]
        let localData = try JSONEncoder().encode(original)

        let cloudData = translator.translateCameraOverlaysToCloud(localData)!
        let roundTripped = translator.translateCameraOverlaysFromCloud(cloudData)!
        let decoded = try JSONDecoder().decode([String: [String]].self, from: roundTripped)

        XCTAssertEqual(decoded[camId.uuidString], [svc1Id.uuidString, svc2Id.uuidString])
    }

    func testCameraOverlaysDropsUnknownCamera() throws {
        let roomId = UUID()
        let svcId = UUID()
        let service = makeService(id: svcId, name: "Light", accessoryName: "Lamp", roomId: roomId)
        let accessory = makeAccessory(name: "Lamp", roomId: roomId, services: [service])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Bedroom")],
            accessories: [accessory]
            // No cameras
        )
        translator.updateMenuData(data)

        let overlays: [String: [String]] = [UUID().uuidString: [svcId.uuidString]]
        let localData = try JSONEncoder().encode(overlays)

        let cloudData = translator.translateCameraOverlaysToCloud(localData)!
        let decoded = try JSONDecoder().decode([String: [String]].self, from: cloudData)

        XCTAssertTrue(decoded.isEmpty)
    }

    func testCameraOverlaysDropsUnknownServices() throws {
        let camId = UUID()
        let data = makeMenuData(cameras: [CameraData(uniqueIdentifier: camId, name: "Hallway")])
        translator.updateMenuData(data)

        let overlays: [String: [String]] = [camId.uuidString: [UUID().uuidString]]
        let localData = try JSONEncoder().encode(overlays)

        let cloudData = translator.translateCameraOverlaysToCloud(localData)!
        let decoded = try JSONDecoder().decode([String: [String]].self, from: cloudData)

        // Camera with no translatable services is dropped
        XCTAssertTrue(decoded.isEmpty)
    }

    func testCameraOverlaysCrossDevice() throws {
        let roomId1 = UUID()
        let mac1CamId = UUID()
        let mac1SvcId = UUID()
        let mac1Service = makeService(id: mac1SvcId, name: "Light", accessoryName: "Lamp", roomId: roomId1)
        let mac1Acc = makeAccessory(name: "Lamp", roomId: roomId1, services: [mac1Service])
        let mac1Data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId1, name: "Bedroom")],
            accessories: [mac1Acc],
            cameras: [CameraData(uniqueIdentifier: mac1CamId, name: "Hallway")]
        )
        var mac1Translator = CloudSyncTranslator()
        mac1Translator.updateMenuData(mac1Data)

        let overlays: [String: [String]] = [mac1CamId.uuidString: [mac1SvcId.uuidString]]
        let localData = try JSONEncoder().encode(overlays)
        let cloudData = mac1Translator.translateCameraOverlaysToCloud(localData)!

        // Mac 2 has different UUIDs
        let roomId2 = UUID()
        let mac2CamId = UUID()
        let mac2SvcId = UUID()
        let mac2Service = makeService(id: mac2SvcId, name: "Light", accessoryName: "Lamp", roomId: roomId2)
        let mac2Acc = makeAccessory(name: "Lamp", roomId: roomId2, services: [mac2Service])
        let mac2Data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId2, name: "Bedroom")],
            accessories: [mac2Acc],
            cameras: [CameraData(uniqueIdentifier: mac2CamId, name: "Hallway")]
        )
        var mac2Translator = CloudSyncTranslator()
        mac2Translator.updateMenuData(mac2Data)

        let mac2LocalData = mac2Translator.translateCameraOverlaysFromCloud(cloudData)!
        let decoded = try JSONDecoder().decode([String: [String]].self, from: mac2LocalData)

        XCTAssertEqual(decoded[mac2CamId.uuidString], [mac2SvcId.uuidString])
    }

    func testCameraOverlaysFromInvalidData() {
        translator.updateMenuData(makeMenuData())
        let invalidData = "not json".data(using: .utf8)!

        XCTAssertNil(translator.translateCameraOverlaysToCloud(invalidData))
        XCTAssertNil(translator.translateCameraOverlaysFromCloud(invalidData))
    }
}
