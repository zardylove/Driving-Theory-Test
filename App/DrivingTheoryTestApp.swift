import SwiftUI

@main
struct DrivingTheoryTestApp: App {

    @StateObject private var dataManager = DataManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
        }
    }
}

// MARK: - ContentView (Main Tab View)

struct ContentView: View {

    @EnvironmentObject var dataManager: DataManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {

            // Home
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            // Practice
            PracticeView()
                .tabItem {
                    Label("Practice", systemImage: "book.fill")
                }
                .tag(1)

            // Mock Tests
            MockTestsView()
                .tabItem {
                    Label("Mock Tests", systemImage: "doc.text.fill")
                }
                .tag(2)

            // Hazard
            HazardView()
                .tabItem {
                    Label("Hazard", systemImage: "exclamationmark.triangle.fill")
                }
                .tag(3)

            // Progress  ✅ Renamed to avoid SwiftUI ProgressView clash
            ProgressDashboardView()
                .tabItem {
                    Label("Progress", systemImage: "chart.bar.fill")
                }
                .tag(4)

            // More
            MoreView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle.fill")
                }
                .tag(5)
        }
        // Prefer tint for modern SwiftUI
        .tint(.blue)
    }
}

// MARK: - Hazard View (Placeholder)

struct HazardView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.orange)

                Text("Coming Soon")
                    .font(.title.bold())

                Text("Hazard perception practice will be available in a future update.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .navigationTitle("Hazard Perception")
        }
    }
}

// MARK: - More View

struct MoreView: View {

    @EnvironmentObject var dataManager: DataManager
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {

                // Purchase Section (if not unlocked)
                if !dataManager.hasUnlockedFullAccess {
                    Section {
                        Button(action: { showPaywall = true }) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)

                                VStack(alignment: .leading) {
                                    Text("Unlock Full Access")
                                        .font(.headline)
                                    Text("Get all features")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } else {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Full Access Unlocked")
                                .font(.headline)
                        }
                    }
                }

                // Settings
                Section(header: Text("App")) {
                    NavigationLink(destination: SettingsView()) {
                        Label("Settings", systemImage: "gearshape")
                    }
                }

                // Help & Info
                Section(header: Text("Help & Info")) {

                    NavigationLink(destination: AboutView()) {
                        Label("About", systemImage: "info.circle")
                    }

                    NavigationLink(destination: PrivacyPolicyView()) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }

                    NavigationLink(destination: TermsView()) {
                        Label("Terms of Use", systemImage: "doc.text")
                    }
                }

                // Debug (only in DEBUG builds)
                #if DEBUG
                Section(header: Text("Debug")) {
                    Button("Reset Purchase") {
                        dataManager.resetPurchaseForTesting()
                    }

                    Button("Unlock for Testing") {
                        dataManager.unlockForTesting()
                    }
                }
                #endif
            }
            .navigationTitle("More")
            .sheet(isPresented: $showPaywall) {
                // Explicitly pass env object (extra safe)
                PaywallView()
                    .environmentObject(dataManager)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(DataManager())
}
