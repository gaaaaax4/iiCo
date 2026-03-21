#!/usr/bin/env swift

// iiCo BLE 疑似端末スクリプト
// MacBook 上で iiCo と同じ Service UUID をアドバタイズ・スキャンし、
// 実機 iPhone のテスト相手として機能する。
//
// 使い方:
//   chmod +x iiko_ble_tester.swift
//   swift iiko_ble_tester.swift

import CoreBluetooth
import Foundation

// iiCo と同じ UUID
let serviceUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")

// MARK: - Peripheral (アドバタイズ側)

class BLEAdvertiser: NSObject, CBPeripheralManagerDelegate {
    var peripheralManager: CBPeripheralManager!

    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            print("[Peripheral] Bluetooth ON - アドバタイズ開始")
            peripheral.startAdvertising([
                CBAdvertisementDataServiceUUIDsKey: [serviceUUID]
            ])
        case .poweredOff:
            print("[Peripheral] Bluetooth OFF")
        case .unauthorized:
            print("[Peripheral] Bluetooth 権限なし - システム環境設定でアクセスを許可してください")
        default:
            print("[Peripheral] State: \(peripheral.state.rawValue)")
        }
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("[Peripheral] アドバタイズ失敗: \(error.localizedDescription)")
        } else {
            print("[Peripheral] アドバタイズ中 ✅  UUID: \(serviceUUID.uuidString)")
        }
    }
}

// MARK: - Central (スキャン側)

class BLEScanner: NSObject, CBCentralManagerDelegate {
    var centralManager: CBCentralManager!

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("[Central] スキャン開始")
            central.scanForPeripherals(
                withServices: [serviceUUID],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let rssiValue = RSSI.intValue
        let bar = String(repeating: "█", count: max(0, (rssiValue + 100) / 5))
        print("[Central] iPhone 検出  RSSI: \(rssiValue) dBm  \(bar)")
    }
}

// MARK: - Run

print("==============================================")
print("  iiCo BLE テスター (MacBook 疑似端末)")
print("==============================================")
print("UUID: \(serviceUUID.uuidString)")
print("このまま待機します。Ctrl+C で終了。")
print("----------------------------------------------")

let advertiser = BLEAdvertiser()
let scanner = BLEScanner()

// メインループを維持
RunLoop.main.run()
