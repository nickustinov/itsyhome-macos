//
//  HAPService+CarbonDioxide.swift
//  macOSBridge
//
//  Carbon dioxide sensor support. hap-swift (main) defines the other six
//  read-only sensor types but not CO2, so we add the service type (HomeKit
//  short UUID "97"), the detected characteristic ("92"), and a factory that
//  mirrors hap-swift's own sensor factories exactly.
//
import HAPCore

extension HAPServiceType {
    /// HomeKit Carbon Dioxide Sensor service (00000097-...).
    public static let carbonDioxideSensor = HAPServiceType(rawValue: "97")
}

extension HAPCharacteristicType {
    /// HomeKit Carbon Dioxide Detected characteristic (00000092-...).
    public static let carbonDioxideDetected = HAPCharacteristicType(rawValue: "92")
}

extension HAPService {
    /// Read-only carbon dioxide sensor, mirroring hap-swift's sensor factories.
    public static func carbonDioxideSensor(startIID: UInt64) -> HAPService {
        HAPService(type: .carbonDioxideSensor, characteristics: [
            HAPCharacteristic(
                iid: startIID, type: .carbonDioxideDetected, value: .uint8(0),
                permissions: [.read, .notify], format: .uint8,
                minValue: 0, maxValue: 1
            ),
        ])
    }
}
