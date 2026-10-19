import SwiftUI
import PhotosUI

struct AdminStatusesView: View {
    @StateObject private var api = AdminAPIService.shared
    
    @State private var statuses: [AdminStatusItem] = []
    @State private var isLoading: Bool = false
    @State private var showCreateSheet: Bool = false
    @State private var statusToDelete: AdminStatusItem? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                AdminTheme.bgDark.ignoresSafeArea()
                
                if isLoading && statuses.isEmpty {
                    ProgressView().tint(AdminTheme.mint)
                } else if statuses.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.system(size: 48))
                            .foregroundColor(AdminTheme.gold)
                        Text("Нет опубликованных статусов")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text("Создайте первый статус (историю), который увидят клиенты банка вверху главного экрана.")
                            .font(.system(size: 13))
                            .foregroundColor(AdminTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        Button(action: { showCreateSheet = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Создать статус")
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(AdminTheme.gold)
                            .cornerRadius(14)
                        }
                        .padding(.top, 8)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(statuses) { item in
                                statusCard(item)
                            }
                        }
                        .padding(16)
                    }
                    .refreshable {
                        await loadData()
                    }
                }
            }
            .navigationTitle("Управление статусами")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreateSheet = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AdminTheme.gold)
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateStatusSheet(onCreated: {
                    Task { await loadData() }
                })
            }
            .task {
                await loadData()
            }
            .alert("Удалить статус?", isPresented: Binding(
                get: { statusToDelete != nil },
                set: { if !$0 { statusToDelete = nil } }
            )) {
                Button("Удалить", role: .destructive) {
                    if let s = statusToDelete {
                        Task { await delete(s) }
                    }
                }
                Button("Отмена", role: .cancel) {
                    statusToDelete = nil
                }
            } message: {
                Text("Этот статус исчезнет из шапки приложения у всех пользователей.")
            }
        }
    }
    
    // MARK: - Status Card
    private func statusCard(_ item: AdminStatusItem) -> some View {
        HStack(spacing: 14) {
            // Square Thumbnail
            ZStack {
                AdminTheme.bgCardSecondary
                
                if let url = URL(string: item.media_url), !item.media_url.isEmpty {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            Image(systemName: item.media_type == "video" ? "play.circle.fill" : "photo.fill")
                                .foregroundColor(AdminTheme.gold)
                        }
                    }
                }
            }
            .frame(width: 70, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AdminTheme.gold, lineWidth: 1.5)
            )
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title?.isEmpty == false ? item.title! : "Статус RoPay")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text(item.platformBadge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AdminTheme.mint)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AdminTheme.mint.opacity(0.12))
                        .cornerRadius(6)
                }
                
                if let txt = item.text, !txt.isEmpty {
                    Text(txt)
                        .font(.system(size: 12))
                        .foregroundColor(AdminTheme.textSecondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 12) {
                    Label("\(item.views_count ?? 0) просмотров", systemImage: "eye.fill")
                    Label("\(item.duration ?? 10) сек", systemImage: "timer")
                }
                .font(.system(size: 11))
                .foregroundColor(AdminTheme.textSecondary.opacity(0.8))
            }
            
            // Delete button
            Button(action: { statusToDelete = item }) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AdminTheme.danger)
                    .padding(8)
                    .background(AdminTheme.danger.opacity(0.12))
                    .clipShape(Circle())
            }
        }
        .padding(14)
        .background(AdminTheme.bgCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AdminTheme.border, lineWidth: 1))
    }
    
    private func loadData() async {
        isLoading = true
        do {
            let res = try await api.fetchStatuses()
            await MainActor.run {
                statuses = res
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
    
    private func delete(_ item: AdminStatusItem) async {
        do {
            try await api.deleteStatus(id: item.id)
            await loadData()
        } catch {}
    }
}

// MARK: - Create Status Sheet
struct CreateStatusSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onCreated: () -> Void
    
    @State private var title: String = ""
    @State private var text: String = ""
    @State private var targetPlatform: String = "all" // "all", "ios", "android"
    @State private var duration: Int = 10
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var isUploading: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                AdminTheme.bgDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 18) {
                        // Media Picker Box
                        PhotosPicker(selection: $selectedPhotoItem, matching: .any(of: [.images, .videos])) {
                            ZStack {
                                AdminTheme.bgCard
                                
                                if let img = selectedImage {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 180)
                                        .clipped()
                                } else {
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.system(size: 34))
                                            .foregroundColor(AdminTheme.gold)
                                        Text("Нажмите, чтобы выбрать фото или видео")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(AdminTheme.textSecondary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .cornerRadius(18)
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(AdminTheme.gold.opacity(0.5), lineWidth: 1.5))
                        }
                        .onChange(of: selectedPhotoItem) { newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    await MainActor.run {
                                        self.selectedImageData = data
                                        self.selectedImage = UIImage(data: data)
                                    }
                                }
                            }
                        }
                        
                        // Fields
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ЗАГОЛОВОК СТАТУСА (ДЛЯ ПРЕВЬЮ)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(AdminTheme.textSecondary)
                            TextField("Новинка в банкоматах RoPay", text: $title)
                                .padding()
                                .background(AdminTheme.bgCard)
                                .cornerRadius(14)
                                .foregroundColor(.white)
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AdminTheme.border, lineWidth: 1))
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ТЕКСТ СТАТУСА (ПОЯВИТСЯ ВНИЗУ ПРИ ПРОСМОТРЕ)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(AdminTheme.textSecondary)
                            TextEditor(text: $text)
                                .frame(height: 90)
                                .padding(8)
                                .background(AdminTheme.bgCard)
                                .cornerRadius(14)
                                .foregroundColor(.white)
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AdminTheme.border, lineWidth: 1))
                        }
                        
                        // Platform target picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ДЛЯ КОГО БУДЕТ ВИДЕН СТАТУС")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(AdminTheme.textSecondary)
                            
                            Picker("Платформа", selection: $targetPlatform) {
                                Text("🌐 Для всех (iOS + Android)").tag("all")
                                Text("📱 Только для iPhone").tag("ios")
                                Text("🤖 Только для Android").tag("android")
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        // Duration stepper
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Длительность показа")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Для фотографий (по умолчанию 10 секунд)")
                                    .font(.system(size: 11))
                                    .foregroundColor(AdminTheme.textSecondary)
                            }
                            Spacer()
                            Stepper("\(duration) сек", value: $duration, in: 3...30)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AdminTheme.mint)
                        }
                        .padding(14)
                        .background(AdminTheme.bgCard)
                        .cornerRadius(14)
                        
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundColor(AdminTheme.danger)
                        }
                        
                        Button(action: uploadStatus) {
                            HStack {
                                if isUploading {
                                    ProgressView().tint(.black)
                                } else {
                                    Image(systemName: "arrow.up.circle.fill")
                                    Text("Опубликовать статус")
                                        .font(.system(size: 16, weight: .bold))
                                }
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AdminTheme.gold)
                            .cornerRadius(16)
                        }
                        .disabled(isUploading || selectedImageData == nil)
                        .padding(.top, 10)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Новый статус")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                        .foregroundColor(AdminTheme.gold)
                }
            }
        }
    }
    
    private func uploadStatus() {
        guard let data = selectedImageData else {
            errorMessage = "Выберите фото или видео"
            return
        }
        
        isUploading = true
        errorMessage = ""
        
        Task {
            do {
                try await AdminAPIService.shared.createStatus(
                    mediaData: data,
                    filename: "media_\(Date().timeIntervalSince1970).jpg",
                    title: title,
                    text: text,
                    mediaType: "photo",
                    duration: duration,
                    targetPlatform: targetPlatform
                )
                await MainActor.run {
                    isUploading = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dismiss()
                    onCreated()
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
