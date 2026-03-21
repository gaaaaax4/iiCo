import SwiftUI

struct PlayView: View {
    @StateObject private var proximityManager = ProximityManager()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            proximityManager.backgroundColor
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.4), value: proximityManager.isContacting)


            VStack(spacing: 40) {
                if proximityManager.isContacting {
                    ContactCharacterView(
                        myEmoji: proximityManager.myEmoji,
                        peerEmoji: proximityManager.receivedEmoji
                    )
                } else {
                    WaitingCharacterView(emoji: proximityManager.myEmoji)

                    if proximityManager.isReady {
                        PulsingCircleView()
                    } else {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(2.0)
                                .tint(AppColors.highlight)
                            Text("Bluetooth 準備中...")
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(AppColors.headline.opacity(0.5))
                        }
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(false)
        .onAppear {
            proximityManager.start()
        }
        .onDisappear {
            proximityManager.stop()
        }
        .alert("エラー", isPresented: $proximityManager.showError) {
            Button("OK") { dismiss() }
        } message: {
            Text(proximityManager.errorMessage)
        }
    }
}

// MARK: - Waiting Character

private struct WaitingCharacterView: View {
    let emoji: String
    @State private var offsetY: CGFloat = 0
    @State private var rotation: Double = 0

    var body: some View {
        Text(emoji)
            .font(.system(size: 120))
            .offset(y: offsetY)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                ) {
                    offsetY = -16
                }
                withAnimation(
                    .easeInOut(duration: 1.8).repeatForever(autoreverses: true)
                ) {
                    rotation = 8
                }
            }
    }
}

// MARK: - Contact Character

private struct ContactCharacterView: View {
    let myEmoji: String
    let peerEmoji: String?

    @State private var myScale: CGFloat = 1.0
    @State private var peerScale: CGFloat = 0.3
    @State private var peerOpacity: Double = 0
    @State private var arrowOpacity: Double = 0
    @State private var badgeScale: CGFloat = 0.1

    private var receivedRarity: EmojiRarity {
        EmojiPicker.rarity(of: peerEmoji ?? "")
    }
    private var rarityLabel: (text: String, color: Color)? {
        switch receivedRarity {
        case .uncommon:  return ("UNCOMMON ✨", .yellow)
        case .rare:      return ("RARE 💎", .cyan)
        case .superRare: return ("SUPER RARE 👑", .yellow)
        case .common:    return nil
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 32) {
                // 相手の絵文字（受け取った）
                VStack(spacing: 6) {
                    Text(peerEmoji ?? "❓")
                        .font(.system(size: 100))
                        .scaleEffect(peerScale)
                        .opacity(peerOpacity)

                    if let label = rarityLabel {
                        Text(label.text)
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(label.color)
                            .clipShape(Capsule())
                            .scaleEffect(badgeScale)
                            .opacity(peerOpacity)
                    }
                }

                // 矢印
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(arrowOpacity)

                // 自分の絵文字（渡した）
                Text(myEmoji)
                    .font(.system(size: 100))
                    .scaleEffect(myScale)
            }

            // 星パーティクル（superRare は金色の王冠で増量）
            HStack(spacing: 8) {
                let particle = receivedRarity == .superRare ? "👑" : "⭐️"
                let count    = receivedRarity == .superRare ? 7 : 5
                ForEach(0..<count, id: \.self) { _ in
                    Text(particle)
                        .font(.system(size: 22))
                        .opacity(arrowOpacity)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                peerScale = 1.0
                peerOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.3).delay(0.15)) {
                arrowOpacity = 1.0
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4).delay(0.1)) {
                myScale = 1.1
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.4).delay(0.25)) {
                badgeScale = 1.0
            }
        }
    }
}

// MARK: - Pulsing Animation

private struct PulsingCircleView: View {
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.6

    var body: some View {
        ZStack {
            Circle()
                .fill(AppColors.secondary.opacity(opacity))
                .frame(width: 120, height: 120)
                .scaleEffect(scale)
            Circle()
                .fill(AppColors.highlight.opacity(0.85))
                .frame(width: 60, height: 60)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
            ) {
                scale = 1.4
                opacity = 0.1
            }
        }
    }
}

#Preview {
    NavigationStack {
        PlayView()
    }
}

