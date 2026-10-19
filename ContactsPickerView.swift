import SwiftUI
import Contacts

struct PhoneContact: Identifiable {
    let id: String
    let name: String
    let phone: String
    let normalizedPhone: String
    let avatarData: Data?
    var isRoPayClient: Bool = false
    var bankName: String? = nil
}

@MainActor
class ContactsViewModel: ObservableObject {
    @Published var contacts: [PhoneContact] = []
    @Published var isLoading: Bool = false
    @Published var isCheckingBankStatus: Bool = false
    @Published var permissionDenied: Bool = false
    @Published var searchQuery: String = ""
    @Published var filterOnlyRoPay: Bool = false
    
    var filteredContacts: [PhoneContact] {
        contacts.filter { contact in
            let matchesFilter = !filterOnlyRoPay || contact.isRoPayClient
            if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                return matchesFilter
            }
            let query = searchQuery.lowercased()
            let matchesSearch = contact.name.lowercased().contains(query) ||
                                contact.phone.contains(query) ||
                                contact.normalizedPhone.contains(query)
            return matchesFilter && matchesSearch
        }
    }
    
    var roPayClientsCount: Int {
        contacts.filter { $0.isRoPayClient }.count
    }
    
    func checkPermissionAndLoad() {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized:
            fetchContacts()
        case .notDetermined:
            requestPermission()
        case .denied, .restricted:
            permissionDenied = true
        @unknown default:
            permissionDenied = true
        }
    }
    
    private func requestPermission() {
        isLoading = true
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { [weak self] granted, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                if granted {
                    self.fetchContacts()
                } else {
                    self.permissionDenied = true
                }
            }
        }
    }
    
    func fetchContacts() {
        isLoading = true
        permissionDenied = false
        
        Task.detached(priority: .userInitiated) {
            let store = CNContactStore()
            let keysToFetch: [CNKeyDescriptor] = [
                CNContactIdentifierKey as CNKeyDescriptor,
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactThumbnailImageDataKey as CNKeyDescriptor
            ]
            let request = CNContactFetchRequest(keysToFetch: keysToFetch)
            request.sortOrder = .userDefault
            
            var fetched: [PhoneContact] = []
            do {
                try store.enumerateContacts(with: request) { contact, _ in
                    let first = contact.givenName.trimmingCharacters(in: .whitespaces)
                    let last = contact.familyName.trimmingCharacters(in: .whitespaces)
                    let fullName = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
                    let name = fullName.isEmpty ? "Без имени" : fullName
                    
                    for labeledValue in contact.phoneNumbers {
                        let raw = labeledValue.value.stringValue
                        let digits = raw.filter { $0.isNumber }
                        guard !digits.isEmpty else { continue }
                        
                        var norm = digits
                        if norm.count == 11 && norm.hasPrefix("8") {
                            norm = "7" + norm.dropFirst()
                        } else if norm.count == 10 {
                            norm = "7" + norm
                        }
                        let normPhone = "+" + norm
                        
                        let item = PhoneContact(
                            id: "\(contact.identifier)_\(raw)",
                            name: name,
                            phone: raw,
                            normalizedPhone: normPhone,
                            avatarData: contact.thumbnailImageData,
                            isRoPayClient: false,
                            bankName: nil
                        )
                        fetched.append(item)
                    }
                }
            } catch {
                print("Error fetching contacts: \(error)")
            }
            
            // Deduplicate by normalizedPhone
            var uniqueMap: [String: PhoneContact] = [:]
            for c in fetched {
                if uniqueMap[c.normalizedPhone] == nil {
                    uniqueMap[c.normalizedPhone] = c
                }
            }
            var uniqueList = Array(uniqueMap.values)
            
            await MainActor.run {
                self.contacts = uniqueList
                self.isLoading = false
                self.isCheckingBankStatus = true
            }
            
            // Check with backend in batch
            let phonesToCheck = uniqueList.map { $0.normalizedPhone }
            do {
                let clientsMap = try await APIService.shared.checkContacts(phones: phonesToCheck)
                for i in 0..<uniqueList.count {
                    let ph = uniqueList[i].normalizedPhone
                    if let client = clientsMap[ph] {
                        uniqueList[i].isRoPayClient = true
                        uniqueList[i].bankName = client.fullName
                    }
                }
                // Sort: RoPay clients first, then alphabetical
                uniqueList.sort { (a, b) -> Bool in
                    if a.isRoPayClient != b.isRoPayClient {
                        return a.isRoPayClient && !b.isRoPayClient
                    }
                    return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                }
                
                await MainActor.run {
                    self.contacts = uniqueList
                    self.isCheckingBankStatus = false
                }
            } catch {
                await MainActor.run {
                    self.isCheckingBankStatus = false
                }
            }
        }
    }
}

struct ContactsPickerView: View {
    var onSelectContact: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = ContactsViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                BankTheme.bgDark.ignoresSafeArea()
                
                if vm.permissionDenied {
                    permissionDeniedView
                } else {
                    contactsContentView
                }
            }
            .navigationTitle("Контакты")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                        .foregroundColor(BankTheme.mint)
                }
            }
            .onAppear {
                vm.checkPermissionAndLoad()
            }
        }
    }
    
    private var contactsContentView: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(BankTheme.textMuted)
                
                TextField("Поиск по имени или телефону", text: $vm.searchQuery)
                    .foregroundColor(.white)
                    .font(.system(size: 15))
                
                if !vm.searchQuery.isEmpty {
                    Button(action: { vm.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(BankTheme.textMuted)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(BankTheme.bgCard)
            .cornerRadius(14)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // Filter Pills (Все / В RoPay)
            HStack(spacing: 10) {
                FilterTabButton(
                    title: "Все контакты (\(vm.contacts.count))",
                    isSelected: !vm.filterOnlyRoPay
                ) {
                    withAnimation { vm.filterOnlyRoPay = false }
                }
                
                FilterTabButton(
                    title: "В RoPay (\(vm.roPayClientsCount))",
                    isSelected: vm.filterOnlyRoPay,
                    badgeIcon: "checkmark.seal.fill"
                ) {
                    withAnimation { vm.filterOnlyRoPay = true }
                }
                
                Spacer()
                
                if vm.isCheckingBankStatus {
                    ProgressView()
                        .tint(BankTheme.mint)
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 16)
            
            // Contacts List
            if vm.isLoading {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView().tint(BankTheme.mint)
                    Text("Чтение телефонной книги...")
                        .font(.system(size: 14))
                        .foregroundColor(BankTheme.textMuted)
                }
                Spacer()
            } else if vm.filteredContacts.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 44))
                        .foregroundColor(BankTheme.textMuted)
                    Text(vm.filterOnlyRoPay ? "Контактов в RoPay пока нет" : "Контакты не найдены")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text(vm.filterOnlyRoPay ? "Пригласите друзей в банк RoPay" : "Попробуйте изменить поисковый запрос")
                        .font(.system(size: 13))
                        .foregroundColor(BankTheme.textMuted)
                }
                .padding()
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(vm.filteredContacts) { contact in
                            ContactRow(contact: contact) {
                                let gen = UIImpactFeedbackGenerator(style: .medium)
                                gen.impactOccurred()
                                onSelectContact(contact.normalizedPhone, contact.name)
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
    }
    
    private var permissionDeniedView: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(BankTheme.mint.opacity(0.12))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 40))
                    .foregroundColor(BankTheme.mint)
            }
            
            Text("Доступ к контактам закрыт")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text("Чтобы мгновенно переводить деньги близким и видеть, у кого открыт счёт в банке RoPay, разрешите доступ к контактам в Настройках iPhone.")
                .font(.system(size: 14))
                .foregroundColor(BankTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            Button(action: openAppSettings) {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                    Text("Открыть Настройки")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(BankTheme.mint)
                .cornerRadius(14)
            }
            .padding(.top, 8)
        }
        .padding()
    }
    
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}

// Contact Row Card
struct ContactRow: View {
    let contact: PhoneContact
    var onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar
                if let data = contact.avatarData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(contact.isRoPayClient ? AnyShapeStyle(BankTheme.purpleGradient) : AnyShapeStyle(Color.gray.opacity(0.3)))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(initials(for: contact.name))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                
                // Name and Phone
                VStack(alignment: .leading, spacing: 3) {
                    Text(contact.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(contact.phone)
                        .font(.system(size: 13))
                        .foregroundColor(BankTheme.textMuted)
                }
                
                Spacer()
                
                // Status Badge: В RoPay / Не в RoPay
                if contact.isRoPayClient {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                        Text("В RoPay")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(BankTheme.mint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(BankTheme.mint.opacity(0.14))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(BankTheme.mint.opacity(0.4), lineWidth: 1)
                    )
                } else {
                    Text("Не в RoPay")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(BankTheme.textMuted.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(BankTheme.bgCard)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(contact.isRoPayClient ? BankTheme.mint.opacity(0.3) : BankTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2, let f = parts[0].first, let s = parts[1].first {
            return "\(f)\(s)".uppercased()
        } else if let f = name.first {
            return String(f).uppercased()
        }
        return "?"
    }
}

// Filter Tab Button
struct FilterTabButton: View {
    let title: String
    let isSelected: Bool
    var badgeIcon: String? = nil
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon = badgeIcon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(isSelected ? .black : BankTheme.mint)
                }
                Text(title)
                    .font(.system(size: 13, weight: .bold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? AnyShapeStyle(BankTheme.mint) : AnyShapeStyle(BankTheme.bgCard))
            .foregroundColor(isSelected ? .black : BankTheme.textMuted)
            .cornerRadius(12)
        }
    }
}
