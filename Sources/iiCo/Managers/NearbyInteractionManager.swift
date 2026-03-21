import Foundation
import NearbyInteraction
import MultipeerConnectivity
import SwiftUI
import AudioToolbox
import OSLog

/// 近接検知・フィードバックを管理するクラス
///
/// - 通信フロー:
///   1. MultipeerConnectivity でピアを自動発見・接続
///   2. NearbyInteraction の DiscoveryToken を相互交換
///   3. UWB で距離をリアルタイム測定
///   4. 距離が閾値 (0.5m) を下回ったら音・画面変化を双方に発火
class NearbyInteractionManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var isContacting = false
    @Published var backgroundColor: Color = Color(red: 0.75, green: 0.9, blue: 1.0)
    @Published var showError = false
    @Published var errorMessage = ""

    // MARK: - Constants

    /// 接触と判定する距離 (メートル)
    private let contactThreshold: Float = 0.5
    /// 接触フィードバックの継続時間 (秒)
    private let contactDuration: TimeInterval = 3.0
    /// MultipeerConnectivity のサービス識別子 (Bonjour に登録した名称と一致させる)
    private let serviceType = "iico-nearby"

    // MARK: - NearbyInteraction

    private var niSession: NISession?

    // MARK: - MultipeerConnectivity

    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    private var mcSession: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    // MARK: - Feedback Timer

    private var contactResetTimer: Timer?

    // MARK: - Lifecycle

    func start() {
        Logger.ni.info("[NI] start() called")
        guard NISession.deviceCapabilities.supportsPreciseDistanceMeasurement else {
            Logger.ni.error("[NI] Device does not support UWB precise distance measurement")
            showUnsupportedError()
            return
        }
        setupNISession()
        setupMultipeerConnectivity()
    }

    func stop() {
        contactResetTimer?.invalidate()
        contactResetTimer = nil

        niSession?.invalidate()
        niSession = nil

        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        mcSession?.disconnect()

        advertiser = nil
        browser = nil
        mcSession = nil
    }

    // MARK: - Setup

    private func setupNISession() {
        niSession = NISession()
        niSession?.delegate = self
    }

    private func setupMultipeerConnectivity() {
        mcSession = MCSession(
            peer: myPeerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        mcSession?.delegate = self

        advertiser = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: nil,
            serviceType: serviceType
        )
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()

        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    // MARK: - Token Exchange

    private func sendDiscoveryToken() {
        guard
            let session = mcSession,
            let token = niSession?.discoveryToken,
            !session.connectedPeers.isEmpty
        else {
            Logger.ni.warning("[NI] sendDiscoveryToken skipped: session or token not ready")
            return
        }

        guard let data = try? NSKeyedArchiver.archivedData(
            withRootObject: token,
            requiringSecureCoding: true
        ) else {
            Logger.ni.error("[NI] Failed to archive discovery token")
            return
        }

        Logger.ni.info("[NI] Sending discovery token to \(session.connectedPeers.map(\.displayName))")
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    private func handleReceivedToken(_ data: Data) {
        guard let token = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: NIDiscoveryToken.self,
            from: data
        ) else {
            Logger.ni.error("[NI] Failed to unarchive received discovery token")
            return
        }

        Logger.ni.info("[NI] Received discovery token, starting NI session")
        let config = NINearbyPeerConfiguration(peerToken: token)
        niSession?.run(config)
    }

    // MARK: - Contact Feedback

    private func triggerContactFeedback() {
        guard !isContacting else { return }
        Logger.feedback.info("[Feedback] Contact triggered")

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                self.isContacting = true
                self.backgroundColor = Color.orange
            }
        }

        playContactSound()
        triggerHaptic()

        contactResetTimer?.invalidate()
        contactResetTimer = Timer.scheduledTimer(
            withTimeInterval: contactDuration,
            repeats: false
        ) { [weak self] _ in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self?.isContacting = false
                    self?.backgroundColor = Color(red: 0.75, green: 0.9, blue: 1.0)
                }
            }
        }
    }

    private func playContactSound() {
        // System Sound 1016: "tweet" — 明るく短い音
        Logger.feedback.info("[Feedback] Playing system sound 1016")
        AudioServicesPlaySystemSound(1016)
    }

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }

    // MARK: - Error

    private func showUnsupportedError() {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = "この機種はUWBに対応していません。\niPhone 11以降が必要です。"
            self?.showError = true
        }
    }
}

// MARK: - NISessionDelegate

extension NearbyInteractionManager: NISessionDelegate {

    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard
            let peer = nearbyObjects.first,
            let distance = peer.distance
        else { return }

        Logger.ni.debug("[NI] Distance updated: \(distance, format: .fixed(precision: 2))m")

        if distance < contactThreshold {
            triggerContactFeedback()
        }
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
        Logger.ni.error("[NI] Session invalidated: \(error.localizedDescription)")
        // セッションを再起動して再接続
        setupNISession()
        sendDiscoveryToken()
    }

    func sessionWasSuspended(_ session: NISession) {
        Logger.ni.warning("[NI] Session suspended")
    }

    func sessionSuspensionEnded(_ session: NISession) {
        Logger.ni.info("[NI] Session suspension ended, re-sending token")
        sendDiscoveryToken()
    }
}

// MARK: - MCSessionDelegate

extension NearbyInteractionManager: MCSessionDelegate {

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            Logger.mc.info("[MC] Connected: \(peerID.displayName)")
            sendDiscoveryToken()
        case .connecting:
            Logger.mc.info("[MC] Connecting: \(peerID.displayName)")
        case .notConnected:
            Logger.mc.warning("[MC] Disconnected: \(peerID.displayName)")
            DispatchQueue.main.async { [weak self] in
                self?.isContacting = false
                self?.backgroundColor = Color(red: 0.75, green: 0.9, blue: 1.0)
            }
        @unknown default:
            break
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        handleReceivedToken(data)
    }

    // 未使用 delegate メソッド (実装必須)
    func session(_ session: MCSession, didReceive stream: InputStream,
                 withName streamName: String, fromPeer peerID: MCPeerID) {}

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, with progress: Progress) {}

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension NearbyInteractionManager: MCNearbyServiceAdvertiserDelegate {

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // 接続要求を自動承認
        invitationHandler(true, mcSession)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Logger.mc.error("[MC] Advertiser error: \(error.localizedDescription)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension NearbyInteractionManager: MCNearbyServiceBrowserDelegate {

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String: String]?) {
        Logger.mc.info("[MC] Found peer: \(peerID.displayName), inviting...")
        browser.invitePeer(peerID, to: mcSession!, withContext: nil, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Logger.mc.warning("[MC] Lost peer: \(peerID.displayName)")
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Logger.mc.error("[MC] Browser error: \(error.localizedDescription)")
    }
}
