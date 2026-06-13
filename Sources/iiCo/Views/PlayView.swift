import SwiftUI

struct PlayView: View {
    @StateObject private var proximityManager = ProximityManager()
    @StateObject private var imageStore = RegisteredImageStore.shared

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()


            VStack(spacing: 40) {
                WaitingCharacterView(
                    emoji: proximityManager.myEmoji,
                    imageID: proximityManager.myImageID,
                    imageStore: imageStore
                )
            }
        }
        .navigationBarBackButtonHidden(false)
        .onAppear {
            proximityManager.start()
        }
        .onDisappear {
            proximityManager.stop()
        }
    }
}

// MARK: - Waiting Character

private struct WaitingCharacterView: View {
    let emoji: String
    let imageID: String?
    @ObservedObject var imageStore: RegisteredImageStore
    @State private var offsetY: CGFloat = 0
    @State private var rotation: Double = 0

    var body: some View {
        CharacterDisplayView(emoji: emoji, imageID: imageID, imageStore: imageStore, size: 240)
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

private struct CharacterDisplayView: View {
    let emoji: String
    let imageID: String?
    @ObservedObject var imageStore: RegisteredImageStore
    let size: CGFloat

    var body: some View {
        if let imageID,
           let image = imageStore.uiImage(for: imageID) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.18)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
        } else {
            Text(emoji)
                .font(.system(size: size))
        }
    }
}

#Preview {
    NavigationStack {
        PlayView()
    }
}

