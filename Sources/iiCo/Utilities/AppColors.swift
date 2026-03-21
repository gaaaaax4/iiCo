import SwiftUI

/// アプリ全体で使用するカラーパレット
/// デザイントークン: https://coolors.co 系カラーシステム準拠
enum AppColors {
    /// 背景色 #fffffe
    static let background    = Color(hex: "#fffffe")
    /// 見出しテキスト #2b2c34
    static let headline      = Color(hex: "#2b2c34")
    /// 本文テキスト #2b2c34
    static let paragraph     = Color(hex: "#2b2c34")
    /// ボタン背景 #6246ea
    static let button        = Color(hex: "#6246ea")
    /// ボタンテキスト #fffffe
    static let buttonText    = Color(hex: "#fffffe")
    /// メイン（白系）#fffffe
    static let main          = Color(hex: "#fffffe")
    /// ハイライト #6246ea
    static let highlight     = Color(hex: "#6246ea")
    /// セカンダリ #d1d1e9
    static let secondary     = Color(hex: "#d1d1e9")
    /// ストローク #2b2c34
    static let stroke        = Color(hex: "#2b2c34")
    /// アクセント（接触時など）#e45858
    static let tertiary      = Color(hex: "#e45858")
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let int = UInt64(hex, radix: 16) ?? 0
        let r = Double((int >> 16) & 0xff) / 255
        let g = Double((int >>  8) & 0xff) / 255
        let b = Double( int        & 0xff) / 255
        self.init(red: r, green: g, blue: b)
    }
}
