import SwiftUI

struct ContentView: View {
    @State private var currentUser: User? = nil
    @State private var showWelcomeScreen: Bool = false
    
    var body: some View {
        ZStack {
            if let user = currentUser {
                if showWelcomeScreen {
                    WelcomeView(userName: user.name) {
                        withAnimation {
                            showWelcomeScreen = false
                        }
                    }
                    .transition(.opacity)
                } else {
                    DashboardView(currentUser: $currentUser) {
                        withAnimation {
                            currentUser = nil
                        }
                    }
                    .transition(.opacity)
                }
            } else {
                PinLockView(currentUser: $currentUser, showWelcomeScreen: $showWelcomeScreen)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentUser == nil)
        .animation(.easeInOut(duration: 0.3), value: showWelcomeScreen)
    }
}
