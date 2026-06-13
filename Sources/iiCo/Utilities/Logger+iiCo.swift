import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.n2o.iico"

    /// MultipeerConnectivity 関連ログ
    static let mc = Logger(subsystem: subsystem, category: "MultipeerConnectivity")

    /// NearbyInteraction (UWB) 関連ログ
    static let ni = Logger(subsystem: subsystem, category: "NearbyInteraction")

    /// フィードバック (音・振動・画面) 関連ログ
    static let feedback = Logger(subsystem: subsystem, category: "Feedback")
}
