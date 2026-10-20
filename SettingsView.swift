import SwiftUI
import UIKit

// MARK: - Camera / Image Picker for Biometrics
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) private var presentationMode
    var sourceType: UIImagePickerController.SourceType = .camera

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(sourceType) {
            picker.sourceType = sourceType
            if sourceType == .camera && UIImagePickerController.isCameraDeviceAvailable(.front) {
                picker.cameraDevice = .front
            }
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                // Fix orientation and scale if necessary
                parent.image = uiImage.fixedOrientation()
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// Helper to normalize UIImage orientation
extension UIImage {
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage ?? self
    }
    
    func toBase64Jpeg(quality: CGFloat = 0.85) -> String? {
        // Resize down if too huge to keep network payload fast
        let maxDimension: CGFloat = 1080
        var targetSize = self.size
        if targetSize.width > maxDimension || targetSize.height > maxDimension {
            let ratio = min(maxDimension / targetSize.width, maxDimension / targetSize.height)
            targetSize = CGSize(width: targetSize.width * ratio, height: targetSize.height * ratio)
        }
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        
        return resized.jpegData(compressionQuality: quality)?.base64EncodedString()
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Binding var currentUser: User?
    var onLogout: () -> Void
    var isEmbedded: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    @State private var showSupportChat: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                BankTheme.bgDark.ignoresSafeArea()
                
                // Ambient fluid underlay
                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [BankTheme.mint.opacity(0.10), Color.clear],
                            center: .center, startRadius: 10, endRadius: 180
                        ))
                        .frame(width: 300, height: 300)
                        .blur(radius: 55)
                        .offset(x: 120, y: -180)
                    Circle()
                        .fill(RadialGradient(
                            colors: [BankTheme.purple.opacity(0.13), Color.clear],
                            center: .center, startRadius: 10, endRadius: 200
                        ))
                        .frame(width: 340, height: 340)
                        .blur(radius: 60)
                        .offset(x: -100, y: 250)
                }
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // User Profile Header (чистый профиль без неработающих кнопок)
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(BankTheme.mint.opacity(0.15))
                                    .frame(width: 88, height: 88)
                                
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 70))
                                    .foregroundColor(BankTheme.mint)
                            }
                            .overlay(Circle().stroke(BankTheme.mint.opacity(0.35), lineWidth: 2))
                            
                            VStack(spacing: 6) {
                                Text(currentUser?.fullName ?? "Пользователь RoPay")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text(currentUser?.phone ?? "")
                                    .font(.system(size: 15))
                                    .foregroundColor(BankTheme.textMuted)
                            }
                        }
                        .padding(.top, 24)
                        
                        // ── SUPPORT & TELEGRAM BUTTONS (Styled identical to Terminal & Bluetooth Banner) ──
                        VStack(spacing: 12) {
                            // 1. In-App Support Chat
                            if #available(iOS 26.0, *) {
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    showSupportChat = true
                                }) {
                                    SettingsBannerButton(
                                        title: "Служба поддержки",
                                        subtitle: "Чат с банком и голосовой помощник",
                                        icon: "bubble.left.and.bubble.right.fill",
                                        tintColor: BankTheme.purple,
                                        badge: "24/7"
                                    )
                                }
                                .buttonStyle(.glass)
                                .padding(.horizontal, 20)
                            } else {
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    showSupportChat = true
                                }) {
                                    SettingsBannerButton(
                                        title: "Служба поддержки",
                                        subtitle: "Чат с банком и голосовой помощник",
                                        icon: "bubble.left.and.bubble.right.fill",
                                        tintColor: BankTheme.purple,
                                        badge: "24/7"
                                    )
                                }
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                                .padding(.horizontal, 20)
                            }
                            
                            // 2. Telegram Support Button (Directly opens @RodVibeMeg)
                            if #available(iOS 26.0, *) {
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    openTelegram(username: "RodVibeMeg")
                                }) {
                                    SettingsBannerButton(
                                        title: "Поддержка в Telegram",
                                        subtitle: "@RodVibeMeg",
                                        icon: "paperplane.fill",
                                        tintColor: Color(hex: "#229ED9")
                                    )
                                }
                                .buttonStyle(.glass)
                                .padding(.horizontal, 20)
                            } else {
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    openTelegram(username: "RodVibeMeg")
                                }) {
                                    SettingsBannerButton(
                                        title: "Поддержка в Telegram",
                                        subtitle: "@RodVibeMeg",
                                        icon: "paperplane.fill",
                                        tintColor: Color(hex: "#229ED9")
                                    )
                                }
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        // APP INFO & LOGOUT
                        VStack(spacing: 14) {
                            if #available(iOS 26.0, *) {
                                Button(action: {
                                    dismiss()
                                    onLogout()
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                        Text("Выйти из аккаунта")
                                    }
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(BankTheme.danger)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                }
                                .buttonStyle(.glass)
                            } else {
                                Button(action: {
                                    dismiss()
                                    onLogout()
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                        Text("Выйти из аккаунта")
                                    }
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(BankTheme.danger)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(BankTheme.danger.opacity(0.12))
                                    .cornerRadius(16)
                                }
                            }
                            
                            Text("RoPay iOS • Версия 1.0.28")
                                .font(.system(size: 12))
                                .foregroundColor(BankTheme.textMuted)
                                .padding(.top, 4)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, isEmbedded ? 90 : 30)
                    }
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isEmbedded {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Готово") {
                            dismiss()
                        }
                        .foregroundColor(BankTheme.mint)
                        .fontWeight(.bold)
                    }
                }
            }
            .sheet(isPresented: $showSupportChat) {
                SupportChatView(user: currentUser)
            }
            .onAppear {
                if let u = currentUser {
                    APIService.shared.reportTelemetry(userId: u.id)
                }
            }
        }
    }
    
    private func openTelegram(username: String) {
        let clean = username.replacingOccurrences(of: "@", with: "")
        if let appUrl = URL(string: "tg://resolve?domain=\(clean)"), UIApplication.shared.canOpenURL(appUrl) {
            UIApplication.shared.open(appUrl)
        } else if let webUrl = URL(string: "https://t.me/\(clean)") {
            UIApplication.shared.open(webUrl)
        }
    }
}

// MARK: - Settings Banner Button (Exact Clone of Terminal & Bluetooth Banner)
struct SettingsBannerButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let tintColor: Color
    var badge: String? = nil
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(tintColor.opacity(0.22))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(tintColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    if let b = badge {
                        Text(b)
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(tintColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(tintColor.opacity(0.18))
                            .cornerRadius(6)
                    }
                }
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(BankTheme.textMuted)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(BankTheme.textMuted)
        }
        .padding(14)
    }
}
