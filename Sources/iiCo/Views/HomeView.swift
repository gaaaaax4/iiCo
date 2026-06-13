import SwiftUI
import PhotosUI

struct HomeView: View {
    @State private var navigateToPlay = false
    @State private var showImageLibrary = false
    @StateObject private var imageStore = RegisteredImageStore.shared

    private var isStartEnabled: Bool {
        !imageStore.images.isEmpty && imageStore.totalAssignedPercentage() == 100
    }

    private var startValidationMessage: String? {
        if imageStore.images.isEmpty {
            return "画像を1枚以上登録してください。"
        }
        let total = imageStore.totalAssignedPercentage()
        if total != 100 {
            return "画像の確率合計を100%にしてください。（現在: \(total)%）"
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()

                VStack(spacing: 48) {
                    Button(action: {
                        if isStartEnabled {
                            navigateToPlay = true
                        }
                    }) {
                        Text("iiCo")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.buttonText)
                            .frame(width: 200, height: 200)
                            .background(AppColors.button)
                            .clipShape(Circle())
                            .shadow(color: AppColors.button.opacity(0.35), radius: 12, x: 0, y: 6)
                            .opacity(isStartEnabled ? 1.0 : 0.45)
                    }
                    .disabled(!isStartEnabled)

                    if let message = startValidationMessage {
                        Text(message)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.red.opacity(0.86))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                    }

                    if !imageStore.images.isEmpty {
                        VStack(spacing: 10) {
                            Text("登録画像: \(imageStore.images.count)枚")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.headline)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(imageStore.images.prefix(8)) { image in
                                        if let uiImage = imageStore.uiImage(for: image.id) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 42, height: 42)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                            .frame(height: 48)
                        }
                    }
                }

                VStack {
                    HStack {
                        Spacer()
                        Button {
                            showImageLibrary = true
                        } label: {
                            Image(systemName: "photo.stack")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AppColors.buttonText)
                                .frame(width: 44, height: 44)
                                .background(AppColors.button)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    Spacer()
                }

                // フッター：バージョン・コピーライト
                VStack(spacing: 4) {
                    Spacer()
                    Text("version 0.0.1")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(AppColors.paragraph.opacity(0.4))
                    Text("©n2o")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(AppColors.paragraph.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 24)
            }
            .navigationDestination(isPresented: $navigateToPlay) {
                PlayView()
            }
            .sheet(isPresented: $showImageLibrary) {
                ImageLibrarySheetView()
            }
        }
    }
}

private struct ImageLibrarySheetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var imageStore = RegisteredImageStore.shared
    @StateObject private var audioManager = ImageAudioManager.shared
    @State private var selectedItems: [PhotosPickerItem] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("登録枚数: \(imageStore.images.count)/\(RegisteredImageStore.maxImageCount)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.paragraph.opacity(0.75))

                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: max(1, min(20, imageStore.remainingImageSlots)),
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label(
                        imageStore.canAddMoreImages ? "画像を追加" : "上限100枚に達しました",
                        systemImage: "plus"
                    )
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.buttonText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppColors.button)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .opacity(imageStore.canAddMoreImages ? 1.0 : 0.45)
                }
                .disabled(!imageStore.canAddMoreImages)

                if imageStore.images.isEmpty {
                    Spacer()
                    Text("まだ画像が登録されていません")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(AppColors.paragraph.opacity(0.7))
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(imageStore.images) { image in
                                HStack(spacing: 12) {
                                    if let uiImage = imageStore.uiImage(for: image.id) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 72, height: 72)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }

                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("出現率")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(AppColors.paragraph.opacity(0.7))

                                        Menu {
                                            ForEach(Array(stride(from: 0, through: 100, by: 5)), id: \.self) { value in
                                                Button("\(value)%") {
                                                    imageStore.updateAppearancePercentage(id: image.id, percentage: value)
                                                }
                                            }
                                        } label: {
                                            HStack(spacing: 6) {
                                                Text("\(image.appearancePercentage)%")
                                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .font(.system(size: 12, weight: .bold))
                                            }
                                            .foregroundColor(AppColors.buttonText)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(AppColors.button)
                                            .clipShape(Capsule())
                                        }

                                        Text("エフェクト")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(AppColors.paragraph.opacity(0.7))

                                        Menu {
                                            ForEach(ImageDisplayEffectType.allCases) { effect in
                                                Button(effect.title) {
                                                    imageStore.updateEffectType(id: image.id, effectType: effect)
                                                }
                                            }
                                        } label: {
                                            HStack(spacing: 6) {
                                                Text(image.effectType.title)
                                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .font(.system(size: 12, weight: .bold))
                                            }
                                            .foregroundColor(AppColors.buttonText)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(AppColors.button)
                                            .clipShape(Capsule())
                                        }

                                        Text("音声")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(AppColors.paragraph.opacity(0.7))

                                        HStack(spacing: 8) {
                                            Button {
                                                audioManager.toggleRecording(for: image.id)
                                            } label: {
                                                Image(systemName: audioManager.isRecording(id: image.id) ? "stop.circle.fill" : "mic.fill")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .frame(width: 30, height: 30)
                                                    .background(audioManager.isRecording(id: image.id) ? .red : AppColors.button)
                                                    .clipShape(Circle())
                                            }

                                            Button {
                                                if audioManager.isPlaying(id: image.id) {
                                                    audioManager.stopPlayback()
                                                } else {
                                                    audioManager.playAudio(for: image.id)
                                                }
                                            } label: {
                                                Image(systemName: audioManager.isPlaying(id: image.id) ? "stop.fill" : "play.fill")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .frame(width: 30, height: 30)
                                                    .background(imageStore.hasAudio(for: image.id) ? AppColors.button : AppColors.button.opacity(0.35))
                                                    .clipShape(Circle())
                                            }
                                            .disabled(!imageStore.hasAudio(for: image.id))

                                            Button {
                                                audioManager.deleteAudio(for: image.id)
                                            } label: {
                                                Image(systemName: "waveform.badge.minus")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .frame(width: 30, height: 30)
                                                    .background(imageStore.hasAudio(for: image.id) ? .orange.opacity(0.9) : .orange.opacity(0.35))
                                                    .clipShape(Circle())
                                            }
                                            .disabled(!imageStore.hasAudio(for: image.id))
                                        }

                                        Text(imageStore.hasAudio(for: image.id) ? "録音済み" : "未録音")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundColor(AppColors.paragraph.opacity(0.65))
                                    }

                                    Spacer()

                                    Button {
                                        audioManager.deleteAudio(for: image.id)
                                        imageStore.remove(id: image.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 36, height: 36)
                                            .background(.red.opacity(0.8))
                                            .clipShape(Circle())
                                    }
                                }
                                .padding(10)
                                .background(AppColors.buttonText.opacity(0.14))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.bottom, 12)
                    }
                }
            }
            .padding(16)
            .navigationTitle("ライブラリ")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedItems) { items in
                Task {
                    let limitedItems = Array(items.prefix(imageStore.remainingImageSlots))
                    for item in limitedItems {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            _ = imageStore.addImage(from: data)
                        }
                    }
                    selectedItems = []
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
