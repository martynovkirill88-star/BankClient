import SwiftUI

@main
struct AdminApp: App {
    @State private var isAuthenticated: Bool = false
    
    var body: some Scene {
        WindowGroup {
            if isAuthenticated {
                AdminMainView(onLogout: {
                    isAuthenticated = false
                })
                .preferredColorScheme(.dark)
            } else {
                AdminLoginView(onLoginSuccess: {
                    isAuthenticated = true
                })
                .preferredColorScheme(.dark)
            }
        }
    }
}
