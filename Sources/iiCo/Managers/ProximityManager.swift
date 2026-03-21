import Foundation
import CoreBluetooth
import CoreHaptics
import SwiftUI
import AudioToolbox
import OSLog

/// CoreBluetooth を使ったバックグラウンド対応の近接検知マネージャー
///
/// - 動作原理:
///   1. Peripheral として iiCo 専用の Service UUID をアドバタイズ
///   2. Central として同じ UUID をスキャン
///   3. 相手の RSSI が閾値を超えたとき、GATT 経由で自分の絵文字を送信
///   4. 相手の絵文字を受け取ったら表示を入れ替えてフィードバック
///
/// - 絵文字交換フロー:
///   近接検知 → Central が Peripheral に接続 → Characteristic に自分の絵文字を Write
///   → 相手の Characteristic を Read して絵文字を取得 → 双方の絵文字を入れ替え表示
class ProximityManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var isContacting = false
    @Published var backgroundColor: Color = AppColors.secondary
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var isReady = false
    /// 自分の絵文字（起動時にランダム選択）
    @Published var myEmoji: String = EmojiPicker.random()
    /// 交換で受け取った相手の絵文字（接触時に更新）
    @Published var receivedEmoji: String? = nil

    // MARK: - Constants

    /// iiCo 専用サービス UUID
    static let serviceUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")
    /// 絵文字交換用 Characteristic UUID
    static let emojiCharUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567891")
    /// 接触と判定する RSSI 閾値（dBm）。-40 dBm ≈ 0〜5cm
    private let rssiThreshold: Int = -40
    /// 接触フィードバックの継続時間（秒）
    private let contactDuration: TimeInterval = 3.0

    // MARK: - CoreBluetooth

    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?

    /// 接続中の相手 Peripheral
    private var connectedPeripheral: CBPeripheral?
    /// 相手の絵文字 Characteristic（Read 用）
    private var remoteEmojiChar: CBCharacteristic?
    /// 自分の絵文字を保持する Characteristic（Write 受付用）
    private var localEmojiCharacteristic: CBMutableCharacteristic?

    // MARK: - State

    private var isExchanging = false

    // MARK: - Feedback Timer

    private var contactResetTimer: Timer?

    // MARK: - Lifecycle

    func start() {
        Logger.mc.info("[BLE] Starting ProximityManager emoji=\(self.myEmoji)")

        let centralOptions: [String: Any] = [
            CBCentralManagerOptionRestoreIdentifierKey: "iico-central"
        ]
        let peripheralOptions: [String: Any] = [
            CBPeripheralManagerOptionRestoreIdentifierKey: "iico-peripheral"
        ]

        centralManager = CBCentralManager(delegate: self, queue: nil, options: centralOptions)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: peripheralOptions)
        prepareHaptics()
    }

    func stop() {
        Logger.mc.info("[BLE] Stopping ProximityManager")
        contactResetTimer?.invalidate()
        contactResetTimer = nil

        hapticEngine?.stop()
        hapticEngine = nil

        if let p = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(p)
        }
        connectedPeripheral = nil
        remoteEmojiChar = nil

        centralManager?.stopScan()
        peripheralManager?.stopAdvertising()
        centralManager = nil
        peripheralManager = nil

        DispatchQueue.main.async {
            self.isReady = false
            self.isContacting = false
            self.isExchanging = false
            self.backgroundColor = AppColors.secondary
        }
    }

    // MARK: - Scanning & Advertising

    private func startScanIfReady() {
        guard let central = centralManager, central.state == .poweredOn else { return }
        central.scanForPeripherals(
            withServices: [ProximityManager.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        Logger.mc.info("[BLE] Scan started")
    }

    private func startAdvertisingIfReady() {
        guard let peripheral = peripheralManager, peripheral.state == .poweredOn else { return }

        // 絵文字 Characteristic をセットアップ（まだなければ）
        if localEmojiCharacteristic == nil {
            let char = CBMutableCharacteristic(
                type: ProximityManager.emojiCharUUID,
                properties: [.read, .write],
                value: nil,
                permissions: [.readable, .writeable]
            )
            localEmojiCharacteristic = char
            let service = CBMutableService(type: ProximityManager.serviceUUID, primary: true)
            service.characteristics = [char]
            peripheral.add(service)
        }

        peripheral.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [ProximityManager.serviceUUID]
        ])
        Logger.mc.info("[BLE] Advertising started")
    }

    private func updateReadyState() {
        let bothReady = centralManager?.state == .poweredOn
            && peripheralManager?.state == .poweredOn
        DispatchQueue.main.async {
            self.isReady = bothReady
        }
    }

    // MARK: - Emoji Exchange

    /// RSSI が閾値を超えたら接続して絵文字交換を開始
    private func beginExchange(with peripheral: CBPeripheral) {
        guard !isExchanging, !isContacting else { return }
        isExchanging = true
        Logger.mc.info("[Exchange] Connecting to peer for emoji exchange")
        centralManager?.stopScan()
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager?.connect(peripheral, options: nil)
    }

    /// 交換完了 → フィードバックを発火して絵文字を入れ替え
    private func completeExchange(peerEmoji: String) {
        let myOld = myEmoji
        Logger.mc.info("[Exchange] Complete: my=\(myOld) → peer=\(peerEmoji)")

        let isBackground = UIApplication.shared.applicationState != .active

        if isBackground {
            NotificationManager.shared.sendContactNotification()
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.receivedEmoji = peerEmoji
                    self.isContacting = true
                    self.backgroundColor = AppColors.tertiary
                }
                // 交換後に自分の絵文字を相手のものに更新
                self.myEmoji = peerEmoji
            }
            playContactSound()
            triggerHaptic()
        }

        contactResetTimer?.invalidate()
        contactResetTimer = Timer.scheduledTimer(
            withTimeInterval: contactDuration,
            repeats: false
        ) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.isContacting = false
                    self.receivedEmoji = nil
                    self.backgroundColor = AppColors.secondary
                }
            }
            // 切断してスキャン再開
            if let p = self.connectedPeripheral {
                self.centralManager?.cancelPeripheralConnection(p)
            }
            self.connectedPeripheral = nil
            self.remoteEmojiChar = nil
            self.isExchanging = false
            self.startScanIfReady()
        }
    }

    // MARK: - Sound & Haptics

    private func playContactSound() {
        AudioServicesPlaySystemSound(1016)
    }

    private var hapticEngine: CHHapticEngine?

    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            Logger.feedback.error("[Feedback] CHHapticEngine init failed: \(error.localizedDescription)")
        }
    }

    private func triggerHaptic() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = hapticEngine else {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
            return
        }

        var events: [CHHapticEvent] = []
        for time in [0.0, 0.25, 0.50] as [TimeInterval] {
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                ],
                relativeTime: time,
                duration: 0.18
            )
            events.append(event)
        }

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            Logger.feedback.error("[Feedback] Haptic play failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension ProximityManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Logger.mc.info("[BLE Central] State: \(central.state.rawValue)")
        updateReadyState()
        if central.state == .poweredOn {
            startScanIfReady()
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let rssiValue = RSSI.intValue
        Logger.mc.debug("[BLE Central] Peer RSSI: \(rssiValue) dBm")
        guard rssiValue != 127 else { return }
        if rssiValue >= rssiThreshold {
            beginExchange(with: peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        Logger.mc.info("[BLE Central] Connected, discovering services")
        peripheral.discoverServices([ProximityManager.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        Logger.mc.error("[BLE Central] Failed to connect: \(error?.localizedDescription ?? "unknown")")
        isExchanging = false
        startScanIfReady()
    }

    func centralManager(_ central: CBCentralManager,
                        willRestoreState dict: [String: Any]) {
        startScanIfReady()
    }
}

// MARK: - CBPeripheralDelegate

extension ProximityManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: {
            $0.uuid == ProximityManager.serviceUUID
        }) else { return }
        peripheral.discoverCharacteristics([ProximityManager.emojiCharUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let char = service.characteristics?.first(where: {
            $0.uuid == ProximityManager.emojiCharUUID
        }) else { return }
        remoteEmojiChar = char

        // まず自分の絵文字を Write してから Read する
        if let data = myEmoji.data(using: .utf8) {
            peripheral.writeValue(data, for: char, type: .withResponse)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error {
            Logger.mc.error("[Exchange] Write failed: \(error.localizedDescription)")
            isExchanging = false
            startScanIfReady()
            return
        }
        // Write 完了後に相手の絵文字を Read
        peripheral.readValue(for: characteristic)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard error == nil,
              let data = characteristic.value,
              let peerEmoji = String(data: data, encoding: .utf8),
              !peerEmoji.isEmpty else {
            isExchanging = false
            startScanIfReady()
            return
        }
        completeExchange(peerEmoji: peerEmoji)
    }
}

// MARK: - CBPeripheralManagerDelegate

extension ProximityManager: CBPeripheralManagerDelegate {

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        Logger.mc.info("[BLE Peripheral] State: \(peripheral.state.rawValue)")
        updateReadyState()
        if peripheral.state == .poweredOn {
            startAdvertisingIfReady()
        }
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error {
            Logger.mc.error("[BLE Peripheral] Advertising error: \(error.localizedDescription)")
        } else {
            Logger.mc.info("[BLE Peripheral] Advertising started")
        }
    }

    /// 相手 Central から Write されたら自分の絵文字を上書き保存
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if request.characteristic.uuid == ProximityManager.emojiCharUUID,
               let data = request.value,
               let emoji = String(data: data, encoding: .utf8) {
                localEmojiCharacteristic?.value = data
                Logger.mc.info("[BLE Peripheral] Received write emoji=\(emoji)")
            }
            peripheral.respond(to: request, withResult: .success)
        }
    }

    /// Central から Read リクエストが来たら現在の自分の絵文字を返す
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didReceiveRead request: CBATTRequest) {
        if request.characteristic.uuid == ProximityManager.emojiCharUUID {
            let data = myEmoji.data(using: .utf8) ?? Data()
            request.value = data
            peripheral.respond(to: request, withResult: .success)
            Logger.mc.info("[BLE Peripheral] Responded to read emoji=\(self.myEmoji)")
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           willRestoreState dict: [String: Any]) {
        startAdvertisingIfReady()
    }
}

// MARK: - EmojiPicker

enum EmojiRarity: Int {
    case common = 100   // 通常
    case uncommon = 20  // やや出にくい
    case rare = 5       // レア
    case superRare = 1  // 超レア
}

struct EmojiEntry {
    let emoji: String
    let rarity: EmojiRarity
    var weight: Int { rarity.rawValue }
}

enum EmojiPicker {
    static let entries: [EmojiEntry] = [
        // Common
        EmojiEntry(emoji: "🐥", rarity: .common),
        EmojiEntry(emoji: "🐰", rarity: .common),
        EmojiEntry(emoji: "🐸", rarity: .common),
        EmojiEntry(emoji: "🐼", rarity: .common),
        EmojiEntry(emoji: "🐨", rarity: .common),
        EmojiEntry(emoji: "🐮", rarity: .common),
        EmojiEntry(emoji: "🐷", rarity: .common),
        EmojiEntry(emoji: "🐹", rarity: .common),
        // Uncommon
        EmojiEntry(emoji: "🦊", rarity: .uncommon),
        EmojiEntry(emoji: "🐭", rarity: .uncommon),
        EmojiEntry(emoji: "🦁", rarity: .uncommon),
        EmojiEntry(emoji: "🐯", rarity: .uncommon),
        EmojiEntry(emoji: "🐻", rarity: .uncommon),
        EmojiEntry(emoji: "🦆", rarity: .uncommon),
        EmojiEntry(emoji: "🐧", rarity: .uncommon),
        EmojiEntry(emoji: "🦋", rarity: .uncommon),
        // Rare（いつかは出会える）
        // Super Rare（めったに出ない）
        EmojiEntry(emoji: "👽", rarity: .superRare),
    ]

    static func random() -> String {
        let totalWeight = entries.reduce(0) { $0 + $1.weight }
        var roll = Int.random(in: 0..<totalWeight)
        for entry in entries {
            roll -= entry.weight
            if roll < 0 { return entry.emoji }
        }
        return entries.first?.emoji ?? "🐥"
    }

    static func rarity(of emoji: String) -> EmojiRarity {
        entries.first { $0.emoji == emoji }?.rarity ?? .common
    }
}
