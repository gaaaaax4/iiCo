import SwiftUI

struct HomeView: View {
    @State private var navigateToPlay = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()

                VStack(spacing: 48) {
                    Button(action: {
                        navigateToPlay = true
                    }) {
                        Text("iiCo")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.buttonText)
                            .frame(width: 200, height: 200)
                            .background(AppColors.button)
                            .clipShape(Circle())
                            .shadow(color: AppColors.button.opacity(0.35), radius: 12, x: 0, y: 6)
                    }
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
        }
    }
}

#Preview {
    HomeView()
}
