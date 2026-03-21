import UserNotifications
import OSLog

/// ローカル通知を管理するシングルトン
///
/// バックグラウンド中に近接が検知されたとき、
/// 通知音付きのローカル通知を発行してユーザーに知らせる。
final class NotificationManager: NSObject {

    static let shared = NotificationManager()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permission

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error {
                Logger.feedback.error("[Notification] Auth error: \(error.localizedDescription)")
            } else {
                Logger.feedback.info("[Notification] Auth granted: \(granted)")
            }
        }
    }

    // MARK: - Send

    func sendContactNotification() {
        let content = UNMutableNotificationContent()
        content.title = "いっしょ！"
        content.body = "近くに友達がいるよ！"
        content.sound = .default

        // 重複通知を避けるため identifier を固定
        let request = UNNotificationRequest(
            identifier: "iico.contact",
            content: content,
            trigger: nil  // 即時発行
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Logger.feedback.error("[Notification] Failed to schedule: \(error.localizedDescription)")
            } else {
                Logger.feedback.info("[Notification] Contact notification sent (background)")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {

    /// フォアグラウンド中に通知が来た場合も表示する
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // フォアグラウンドでは ProximityManager が直接フィードバックするため通知は無音で非表示
        completionHandler([])
    }
}
