import Foundation
import SwiftUI
import UIKit

/// 単体オフライン動作用のランダムキャラクターマネージャー
///
/// 登録画像が1枚以上ある場合は画像を優先し、未登録時は絵文字をランダム表示する。
class ProximityManager: ObservableObject {

    @Published var backgroundColor: Color = AppColors.secondary
    @Published var myEmoji: String = ""
    @Published var myImageID: String? = nil

    func start() {
        pickRandomCharacter()
    }

    func stop() {
        // オフライン表示のみのため停止処理は不要
    }

    func rerollCharacter() {
        withAnimation(.easeInOut(duration: 0.25)) {
            pickRandomCharacter()
        }
    }

    private func pickRandomCharacter() {
        if let imageID = RegisteredImageStore.shared.weightedRandomImageID() {
            myImageID = imageID
            myEmoji = "🖼️"
            triggerImageEffectIfNeeded(for: imageID)
            ImageAudioManager.shared.playAudio(for: imageID)
        } else {
            myImageID = nil
            myEmoji = ""
        }
    }

    private func triggerImageEffectIfNeeded(for imageID: String) {
        guard let image = RegisteredImageStore.shared.imageEntry(for: imageID) else { return }

        switch image.effectType {
        case .none:
            return
        case .vibration:
            break
        }

        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred(intensity: 1.0)

        // 強く長めに感じるよう、短い間隔で追撃する
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            let second = UIImpactFeedbackGenerator(style: .heavy)
            second.prepare()
            second.impactOccurred(intensity: 1.0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
            let third = UIImpactFeedbackGenerator(style: .heavy)
            third.prepare()
            third.impactOccurred(intensity: 1.0)
        }
    }
}
