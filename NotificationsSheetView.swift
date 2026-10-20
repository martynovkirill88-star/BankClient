import SwiftUI

// MARK: - Notifications Sheet View
struct NotificationsSheetView: View {
    let currentUser: User?
    @Environment(\.dismiss) private var dismiss
    
    @State private var notifications: [RoPayNotification] = []
    @State private var unreadCount: Int = 0
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                BankTheme.bgDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header Bar
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Уведомления")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            if unreadCount > 0 {
                                Text("\(unreadCount) новых сообщений")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(BankTheme.mint)
                            } else {
                                Text("Все прочитано")
                                    .font(.system(size: 12))
                                    .foregroundColor(BankTheme.textMuted)
                            }
                        }
                        
                        Spacer()
                        
                        if unreadCount > 0 {
                            Button(action: markAllAsRead) {
                                Text("Прочитать все")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(BankTheme.mint)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(BankTheme.mint.opacity(0.12))
                                    .cornerRadius(12)
                            }
                        }
                        
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(BankTheme.bgCardSecondary)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    
                    Divider().background(BankTheme.border)
                    
                    if isLoading {
                        Spacer()
                        ProgressView().tint(BankTheme.mint)
                        Spacer()
                    } else if notifications.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(BankTheme.bgCardSecondary)
                                    .frame(width: 68, height: 68)
                                Image(systemName: "bell.slash.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(BankTheme.textMuted)
                            }
                            Text("Уведомлений пока нет")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                            Text("Здесь будут отображаться решения по заявкам и важные новости RoPay")
                                .font(.system(size: 13))
                                .foregroundColor(BankTheme.textMuted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(notifications) { notif in
                                    NotificationCard(notification: notif, onTap: {
                                        markOneAsRead(notif)
                                    })
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .refreshable {
                            await loadNotifications()
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                await loadNotifications()
            }
        }
    }
    
    private func loadNotifications() async {
        guard let uid = currentUser?.id else {
            isLoading = false
            return
        }
        do {
            let res = try await APIService.shared.fetchNotifications(userId: uid)
            await MainActor.run {
                self.notifications = res.notifications
                self.unreadCount = res.unreadCount
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func markAllAsRead() {
        guard let uid = currentUser?.id else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation {
            notifications = notifications.map {
                RoPayNotification(
                    id: $0.id,
                    user_id: $0.user_id,
                    title: $0.title,
                    message: $0.message,
                    type: $0.type,
                    is_read: 1,
                    created_at: $0.created_at
                )
            }
            unreadCount = 0
        }
        Task {
            await APIService.shared.markNotificationsRead(userId: uid, notificationId: nil)
        }
    }
    
    private func markOneAsRead(_ notif: RoPayNotification) {
        guard !notif.isRead, let uid = currentUser?.id else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation {
            if let idx = notifications.firstIndex(where: { $0.id == notif.id }) {
                notifications[idx] = RoPayNotification(
                    id: notif.id,
                    user_id: notif.user_id,
                    title: notif.title,
                    message: notif.message,
                    type: notif.type,
                    is_read: 1,
                    created_at: notif.created_at
                )
            }
            unreadCount = max(0, unreadCount - 1)
        }
        Task {
            await APIService.shared.markNotificationsRead(userId: uid, notificationId: notif.id)
        }
    }
}

// MARK: - Notification Card
struct NotificationCard: View {
    let notification: RoPayNotification
    var onTap: () -> Void
    
    var iconBackground: Color {
        switch notification.type {
        case "business_approved":
            return BankTheme.mint.opacity(0.18)
        case "business_rejected":
            return Color.red.opacity(0.18)
        case "broadcast":
            return Color.orange.opacity(0.18)
        default:
            return BankTheme.mint.opacity(0.14)
        }
    }
    
    var iconTint: Color {
        switch notification.type {
        case "business_approved":
            return BankTheme.mint
        case "business_rejected":
            return Color.red
        case "broadcast":
            return Color.orange
        default:
            return BankTheme.mint
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconBackground)
                        .frame(width: 44, height: 44)
                    Image(systemName: notification.iconName)
                        .font(.system(size: 20))
                        .foregroundColor(iconTint)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(notification.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        if !notification.isRead {
                            Circle()
                                .fill(BankTheme.mint)
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    Text(notification.message)
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.82))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if let dateStr = notification.created_at {
                        Text(formatDate(dateStr))
                            .font(.system(size: 11))
                            .foregroundColor(BankTheme.textMuted)
                            .padding(.top, 2)
                    }
                }
            }
            .padding(14)
            .background(
                notification.isRead
                    ? BankTheme.bgCard
                    : BankTheme.bgCardSecondary
            )
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        notification.isRead
                            ? BankTheme.border
                            : BankTheme.mint.opacity(0.35),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func formatDate(_ raw: String) -> String {
        return raw.prefix(16).replacingOccurrences(of: "T", with: " ")
    }
}
