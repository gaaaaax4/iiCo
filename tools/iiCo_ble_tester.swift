#!/usr/bin/env swift

// iiCo BLE 疑似端末スクリプト
// MacBook 上で ProximityManager と同じ動作をシミュレートし、
// 実機 iPhone のテスト相手として機能する。
//
// 動作:
//   - Peripheral: iiCo サービスをアドバタイズ、絵文字 Characteristic を提供
//   - Central: iiCo デバイスを検出し RSSI 閾値を超えたら GATT で絵文字交換
//
// 使い方:
//   chmod +x iiCo_ble_tester.swift
//   swift iiCo_ble_tester.swift

import CoreBluetooth
import Foundation

// MARK: - UUID (アプリと一致させる)

let serviceUUID  = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")
let emojiCharUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567891")

// MARK: - Settings

/// 接触と判定する RSSI 閾値 (dBm) — アプリの rssiThreshold と合わせる
let rssiThreshold = -40
/// このテスター自身の絵文字
var myEmoji = "💻"

// MARK: - IiCoTester

class IiCoTester: NSObject {

    var centralManager: CBCentralManager!
    var peripheralManager: CBPeripheralManager!

    var localEmojiChar: CBMutableCharacteristic?
    var connectedPeripheral: CBPeripheral?
    var remoteEmojiChar: CBCharacteristic?
    var isExchanging = false

    override init() {
        super.init()
        centralManager  = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    // MARK: - Peripheral Setup

    func startAdvertising() {
        guard peripheralManager.state == .poweredOn else { return }

        if localEmojiChar == nil {
            let char = CBMutableCharacteristic(
                type: emojiCharUUID,
                properties: [.read, .write],
                value: nil,
                permissions: [.readable, .writeable]
            )
            localEmojiChar = char
            let service = CBMutableService(type: serviceUUID, primary: true)
            service.characteristics = [char]
            peripheralManager.add(service)
        }

        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID]
        ])
    }

    // MARK: - Central Scan

    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        centralManager.scanForPeripherals(
            withServices: [serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        print("[Central] スキャン開始")
    }

    // MARK: - Exchange

    func beginExchange(with peripheral: CBPeripheral) {
        guard !isExchanging else { return }
        isExchanging = true
        print("[Exchange] 接続試行: \(peripheral.name ?? peripheral.identifier.uuidString)")
        centralManager.stopScan()
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }

    func resetExchange() {
        if let p = connectedPeripheral {
            centralManager.cancelPeripheralConnection(p)
        }
        connectedPeripheral = nil
        remoteEmojiChar = nil
        isExchanging = false
        startScanning()
    }
}

// MARK: - CBCentralManagerDelegate

extension IiCoTester: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("[Central] State: \(central.state.rawValue)")
        if central.state == .poweredOn { startScanning() }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let rssiValue = RSSI.intValue
        guard rssiValue != 127 else { return }
        let bar = String(repeating: "█", count: max(0, (rssiValue + 100) / 5))
        print("[Central] 検出  RSSI: \(rssiValue) dBm  \(bar)")

        if rssiValue >= rssiThreshold {
            print("[Central] 閾値到達 (\(rssiValue) >= \(rssiThreshold)) → 絵文字交換開始")
            beginExchange(with: peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("[Central] 接続完了 → サービス探索")
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        print("[Central] 接続失敗: \(error?.localizedDescription ?? "unknown")")
        resetExchange()
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        print("[Central] 切断: \(peripheral.name ?? peripheral.identifier.uuidString)")
        if isExchanging { resetExchange() }
    }
}

// MARK: - CBPeripheralDelegate

extension IiCoTester: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
            print("[Exchange] サービスが見つかりません")
            resetExchange()
            return
        }
        peripheral.discoverCharacteristics([emojiCharUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let char = service.characteristics?.first(where: { $0.uuid == emojiCharUUID }) else {
            print("[Exchange] Characteristic が見つかりません")
            resetExchange()
            return
        }
        remoteEmojiChar = char

        // 自分の絵文字を Write
        if let data = myEmoji.data(using: .utf8) {
            print("[Exchange] 自分の絵文字を Write: \(myEmoji)")
            peripheral.writeValue(data, for: char, type: .withResponse)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error {
            print("[Exchange] Write 失敗: \(error.localizedDescription)")
            resetExchange()
            return
        }
        // Write 完了 → 相手の絵文字を Read
        print("[Exchange] Write 完了 → 相手の絵文字を Read")
        peripheral.readValue(for: characteristic)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard error == nil,
              let data = characteristic.value,
              let peerEmoji = String(data: data, encoding: .utf8),
              !peerEmoji.isEmpty else {
            print("[Exchange] Read 失敗")
            resetExchange()
            return
        }

        print("")
        print("╔══════════════════════════════╗")
        print("║  絵文字交換完了！              ║")
        print("║  自分: \(myEmoji)  →  相手: \(peerEmoji)   ║")
        print("╚══════════════════════════════╝")
        print("")

        myEmoji = peerEmoji

        // 3秒後にリセットしてスキャン再開（アプリの contactDuration と合わせる）
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.resetExchange()
        }
    }
}

// MARK: - CBPeripheralManagerDelegate

extension IiCoTester: CBPeripheralManagerDelegate {

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        print("[Peripheral] State: \(peripheral.state.rawValue)")
        switch peripheral.state {
        case .poweredOn:
            print("[Peripheral] Bluetooth ON → アドバタイズ開始")
            startAdvertising()
        case .unauthorized:
            print("[Peripheral] ❌ Bluetooth 権限なし — システム環境設定 > プライバシー > Bluetooth で許可してください")
        default:
            break
        }
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error {
            print("[Peripheral] アドバタイズ失敗: \(error.localizedDescription)")
        } else {
            print("[Peripheral] アドバタイズ中 ✅  emoji=\(myEmoji)")
        }
    }

    /// iPhone から Write されたら自分の Characteristic に保存
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if request.characteristic.uuid == emojiCharUUID,
               let data = request.value,
               let emoji = String(data: data, encoding: .utf8) {
                localEmojiChar?.value = data
                print("[Peripheral] Write 受信: \(emoji)")
            }
            peripheral.respond(to: request, withResult: .success)
        }
    }

    /// iPhone から Read されたら現在の自分の絵文字を返す
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didReceiveRead request: CBATTRequest) {
        if request.characteristic.uuid == emojiCharUUID {
            request.value = myEmoji.data(using: .utf8)
            peripheral.respond(to: request, withResult: .success)
            print("[Peripheral] Read 応答: \(myEmoji)")
        }
    }
}

// MARK: - Run

print("==============================================")
print("  iiCo BLE テスター (MacBook 疑似端末)")
print("==============================================")
print("Service UUID : \(serviceUUID.uuidString)")
print("Emoji Char   : \(emojiCharUUID.uuidString)")
print("自分の絵文字  : \(myEmoji)")
print("RSSI 閾値    : \(rssiThreshold) dBm")
print("このまま待機します。Ctrl+C で終了。")
print("----------------------------------------------")

let tester = IiCoTester()

RunLoop.main.run()
