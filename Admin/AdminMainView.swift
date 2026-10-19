import SwiftUI

struct AdminMainView: View {
    var onLogout: () -> Void
    
    @State private var selectedTab: Int = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            AdminTheme.bgDark.ignoresSafeArea()
            
            Group {
                switch selectedTab {
                case 0:
                    AdminApplicationsView()
                case 1:
                    AdminStatusesView()
                case 2:
                    AdminUsersView()
                default:
                    AdminApplicationsView()
                }
            }
            
            // Custom Glass Admin Tab Bar
            AdminCustomTabBar(selectedTab: $selectedTab, onLogout: onLogout)
        }
    }
}

// MARK: - Admin Custom Tab Bar
struct AdminCustomTabBar: View {
    @Binding var selectedTab: Int
    var onLogout: () -> Void
    
    var body: some View {
        #if available(iOS 26.0, *)
        HStack {
            AdminTabButton(icon: "doc.text.fill", title: "Заявки", tag: 0, selection: $selectedTab)
            AdminTabButton(icon: "sparkles.rectangle.stack.fill", title: "Статусы", tag: 1, selection: $selectedTab)
            AdminTabButton(icon: "person.2.fill", title: "Клиенты", tag: 2, selection: $selectedTab)
            
            Button(action: onLogout) {
                VStack(spacing: 4) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 18, weight: .medium))
                    Text("Выход")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(AdminTheme.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .glassEffect()
        .tabBarMinimizeBehavior(.onScrollDown)
        .cornerRadius(32)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        #else
        HStack {
            AdminTabButton(icon: "doc.text.fill", title: "Заявки", tag: 0, selection: $selectedTab)
            AdminTabButton(icon: "sparkles.rectangle.stack.fill", title: "Статусы", tag: 1, selection: $selectedTab)
            AdminTabButton(icon: "person.2.fill", title: "Клиенты", tag: 2, selection: $selectedTab)
            
            Button(action: onLogout) {
                VStack(spacing: 4) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 18, weight: .medium))
                    Text("Выход")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(AdminTheme.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.85))
        .background(.ultraThinMaterial)
        .cornerRadius(32)
        .overlay(RoundedRectangle(cornerRadius: 32).stroke(AdminTheme.border, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        #endif
    }
}

struct AdminTabButton: View {
    let icon: String
    let title: String
    let tag: Int
    @Binding var selection: Int
    
    var isSelected: Bool { selection == tag }
    
    var body: some View {
        Button(action: {
            UINotificationFeedbackGenerator().impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selection = tag
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: isSelected ? .bold : .medium))
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
            }
            .foregroundColor(isSelected ? AdminTheme.gold : AdminTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                isSelected ? AdminTheme.gold.opacity(0.14) : Color.clear,
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
    }
}
