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
    
    @State private var showCamera: Bool = false
    @State private var capturedImage: UIImage? = nil
    @State private var isUploading: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var isSuccessAlert: Bool = false
    
    var hasFaceBiometrics: Bool {
        guard let user = currentUser else { return false }
        return (user.has_face == true) || (user.photo_filename != nil && !user.photo_filename!.isEmpty)
    }
    
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
                        // User Profile Header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(BankTheme.mint.opacity(0.15))
                                    .frame(width: 80, height: 80)
                                
                                if let captured = capturedImage {
                                    Image(uiImage: captured)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(BankTheme.mint)
                                }
                            }
                            .overlay(Circle().stroke(BankTheme.mint, lineWidth: 2))
                            
                            VStack(spacing: 4) {
                                Text(currentUser?.fullName ?? "Пользователь RoPay")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text(currentUser?.phone ?? "")
                                    .font(.system(size: 14))
                                    .foregroundColor(BankTheme.textMuted)
                            }
                        }
                        .padding(.top, 10)
                        
                        // SECTION 1: FACE ID & BIOMETRICS
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "faceid")
                                    .foregroundColor(BankTheme.mint)
                                    .font(.system(size: 18, weight: .bold))
                                Text("БИОМЕТРИЯ ДЛЯ БАНКОМАТА")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(BankTheme.textMuted)
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Вход по взгляду в банкомате:")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Text(hasFaceBiometrics ? "Подключен ✓" : "Не подключен")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(hasFaceBiometrics ? BankTheme.mint : BankTheme.danger)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(
                                            (hasFaceBiometrics ? BankTheme.mint : BankTheme.danger).opacity(0.15)
                                        )
                                        .cornerRadius(10)
                                }
                                
                                Text("Сделайте снимок лица на фронтальную камеру. Ваше фото будет добавлено в систему распознавания банкоматов RoPay.")
                                    .font(.system(size: 13))
                                    .foregroundColor(BankTheme.textMuted)
                                    .lineSpacing(2)
                                
                                // Preview captured image if taken
                                if let image = capturedImage {
                                    HStack(spacing: 14) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 70, height: 70)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(BankTheme.mint, lineWidth: 2))
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Снимок готов к отправке")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white)
                                            Text("Нажмите кнопку ниже для привязки")
                                                .font(.system(size: 11))
                                                .foregroundColor(BankTheme.textMuted)
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: { capturedImage = nil }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(BankTheme.textMuted)
                                                .font(.system(size: 20))
                                        }
                                    }
                                    .padding(10)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                
                                // Action buttons: Camera + Upload
                                HStack(spacing: 12) {
                                    if #available(iOS 26.0, *) {
                                        Button(action: { showCamera = true }) {
                                            HStack {
                                                Image(systemName: "camera.fill")
                                                Text(capturedImage == nil ? (hasFaceBiometrics ? "Переснять фото" : "Сделать снимок лица") : "Переснять")
                                                    .font(.system(size: 14, weight: .bold))
                                            }
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                        }
                                        .buttonStyle(.glass)
                                        
                                        if capturedImage != nil {
                                            Button(action: uploadBiometrics) {
                                                HStack {
                                                    if isUploading {
                                                        ProgressView().tint(.white)
                                                    } else {
                                                        Image(systemName: "checkmark.circle.fill")
                                                        Text("Привязать")
                                                            .font(.system(size: 14, weight: .bold))
                                                    }
                                                }
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                            }
                                            .buttonStyle(.glass)
                                            .disabled(isUploading)
                                        }
                                    } else {
                                        Button(action: { showCamera = true }) {
                                            HStack {
                                                Image(systemName: "camera.fill")
                                                Text(capturedImage == nil ? (hasFaceBiometrics ? "Переснять фото" : "Сделать снимок лица") : "Переснять")
                                                    .font(.system(size: 14, weight: .bold))
                                            }
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(BankTheme.purpleGradient)
                                            .cornerRadius(14)
                                        }
                                        
                                        if capturedImage != nil {
                                            Button(action: uploadBiometrics) {
                                                HStack {
                                                    if isUploading {
                                                        ProgressView().tint(.black)
                                                    } else {
                                                        Image(systemName: "checkmark.circle.fill")
                                                        Text("Привязать")
                                                            .font(.system(size: 14, weight: .bold))
                                                    }
                                                }
                                                .foregroundColor(.black)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(BankTheme.mint)
                                                .cornerRadius(14)
                                            }
                                            .disabled(isUploading)
                                        }
                                    }
                                }
                            }
                            .padding(18)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .padding(.horizontal, 20)
                        
                        // SECTION 2: SERVER SETTINGS (IMMUTABLE SECURE CONNECTION)
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundColor(BankTheme.mint)
                                    .font(.system(size: 18, weight: .bold))
                                Text("СЕРВЕР БАНКА")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(BankTheme.textMuted)
                                Spacer()
                                Text("SSL Защищено")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(BankTheme.mint)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(BankTheme.mint.opacity(0.12))
                                    .cornerRadius(6)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(BankTheme.mint)
                                        .frame(width: 8, height: 8)
                                    Text("app.uchisplus.online")
                                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                
                                Text("Официальный защищённый сервер RoPay. Настройки адреса зафиксированы и управляются системой.")
                                    .font(.system(size: 12))
                                    .foregroundColor(BankTheme.textMuted)
                            }
                            .padding(18)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .padding(.horizontal, 20)
                        
                        // SECTION 3: APP INFO & LOGOUT
                        VStack(spacing: 12) {
                            if #available(iOS 26.0, *) {
                                Button(action: {
                                    dismiss()
                                    onLogout()
                                }) {
                                    HStack {
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
                                    HStack {
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
                            
                            Text("RoPay iOS • Версия 1.0.15")
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
            .sheet(isPresented: $showCamera) {
                ImagePicker(image: $capturedImage, sourceType: .camera)
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("ОК") {
                    if isSuccessAlert {
                        capturedImage = nil
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func uploadBiometrics() {
        guard let user = currentUser, let image = capturedImage else { return }
        guard let base64String = image.toBase64Jpeg() else {
            alertTitle = "Ошибка"
            alertMessage = "Не удалось сжать снимок."
            showAlert = true
            return
        }
        
        isUploading = true
        Task {
            do {
                let res = try await APIService.shared.attachBiometrics(
                    userId: user.id,
                    imageBase64: base64String
                )
                await MainActor.run {
                    isUploading = false
                    currentUser = res.user
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    alertTitle = "Успешно!"
                    alertMessage = res.message
                    isSuccessAlert = true
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    alertTitle = "Ошибка привязки"
                    alertMessage = error.localizedDescription
                    isSuccessAlert = false
                    showAlert = true
                }
            }
        }
    }
}
