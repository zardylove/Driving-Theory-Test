import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var showClearDataAlert = false
    @State private var showClearTestsAlert = false
    @State private var showRestoreAlert = false
    @State private var isRestoring = false
    @State private var restoreMessage = ""
    
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        NavigationStack {
            List {
                
                // Account Section
                accountSection
                
                // Preferences Section
                preferencesSection
                
                // Data Management Section
                dataManagementSection
                
                // Help & Info Section
                helpSection
                
                // App Info Section
                appInfoSection
            }
            .navigationTitle("Settings")
            .alert("Clear All Data?", isPresented: $showClearDataAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All Data", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("This will delete all your practice history, test results, and progress. This action cannot be undone.")
            }
            .alert("Clear Mock Test History?", isPresented: $showClearTestsAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear Tests", role: .destructive) {
                    clearMockTests()
                }
            } message: {
                Text("This will delete all your mock test results. Your practice question history will remain.")
            }
            .alert("Restore Purchases", isPresented: $showRestoreAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(restoreMessage)
            }
        }
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        Section(header: Text("Account")) {
            if dataManager.hasUnlockedFullAccess {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("Premium Active")
                        .font(.headline)
                }
            } else {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("Free Plan")
                }
            }
            
            Button(action: restorePurchases) {
                HStack {
                    if isRestoring {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Restoring...")
                    } else {
                        Label("Restore Purchases", systemImage: "arrow.clockwise")
                    }
                }
            }
            .disabled(isRestoring)
        }
    }
    
    // MARK: - Preferences Section
    
    private var preferencesSection: some View {
        Section(header: Text("Preferences")) {
            
            Toggle(isOn: $notificationsEnabled) {
                Label("Daily Reminders", systemImage: "bell.fill")
            }
            .tint(.accentColor)
            
            Toggle(isOn: $soundEnabled) {
                Label("Sound Effects", systemImage: "speaker.wave.2.fill")
            }
            .tint(.accentColor)
            
            Toggle(isOn: $hapticsEnabled) {
                Label("Haptic Feedback", systemImage: "waveform")
            }
            .tint(.accentColor)
        }
        .onChange(of: notificationsEnabled) { _, newValue in
            if newValue {
                requestNotificationPermission()
            }
        }
    }
    
    // MARK: - Data Management Section
    
    private var dataManagementSection: some View {
        Section(header: Text("Data Management")) {
            
            // Storage Info
            HStack {
                Label("Practice History", systemImage: "doc.text")
                Spacer()
                Text("\(dataManager.totalQuestionsAnswered) answers")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            
            HStack {
                Label("Mock Tests", systemImage: "doc.text.fill")
                Spacer()
                Text("\(dataManager.mockTestHistory.totalTestsTaken) tests")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            
            // Clear Actions
            Button(role: .destructive, action: { showClearTestsAlert = true }) {
                Label("Clear Mock Test History", systemImage: "trash")
            }
            
            Button(role: .destructive, action: { showClearDataAlert = true }) {
                Label("Clear All Data", systemImage: "trash.fill")
            }
        }
    }
    
    // MARK: - Help Section
    
    private var helpSection: some View {
        Section(header: Text("Help & Information")) {
            
            NavigationLink(destination: AboutView()) {
                Label("About", systemImage: "info.circle")
            }
            
            NavigationLink(destination: PrivacyPolicyView()) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }
            
            NavigationLink(destination: TermsView()) {
                Label("Terms of Use", systemImage: "doc.text")
            }
            
            Button(action: contactSupport) {
                Label("Contact Support", systemImage: "envelope")
            }
            
            if let url = URL(string: "https://www.gov.uk/theory-test/revision-and-practice") {
                Link(destination: url) {
                    HStack {
                        Label("Official DVSA Resources", systemImage: "link")
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - App Info Section
    
    private var appInfoSection: some View {
        Section(header: Text("App Information")) {
            
            HStack {
                Text("Version")
                Spacer()
                Text("\(appVersion) (\(buildNumber))")
                    .foregroundColor(.secondary)
            }
            
            #if DEBUG
            HStack {
                Text("Environment")
                Spacer()
                Text("Development")
                    .foregroundColor(.orange)
            }
            
            Section(header: Text("Developer Tools")) {
                Button("Reset Purchase Status") {
                    dataManager.resetPurchaseForTesting()
                }
                
                Button("Unlock Premium") {
                    dataManager.unlockForTesting()
                }
                
                Button("Load Sample Data") {
                    loadSampleData()
                }
            }
            #endif
        }
    }
    
    // MARK: - Actions
    
    private func restorePurchases() {
        isRestoring = true
        
        Task {
            do {
                try await dataManager.restorePurchases()
                
                await MainActor.run {
                    isRestoring = false
                    if dataManager.hasUnlockedFullAccess {
                        restoreMessage = "Successfully restored your purchase!"
                    } else {
                        restoreMessage = "No previous purchases found for this Apple ID."
                    }
                    showRestoreAlert = true
                }
            } catch {
                await MainActor.run {
                    isRestoring = false
                    restoreMessage = "Unable to restore purchases. Please try again."
                    showRestoreAlert = true
                }
            }
        }
    }
    
    private func clearAllData() {
        dataManager.clearMockTestHistory()
        dataManager.practiceHistory.removeAll()
        dataManager.practiceSessions.removeAll()
        
        // Save empty state
        UserDefaults.standard.removeObject(forKey: "practice_history")
        UserDefaults.standard.removeObject(forKey: "practice_sessions")
        UserDefaults.standard.removeObject(forKey: "mock_test_history")
    }
    
    private func clearMockTests() {
        dataManager.clearMockTestHistory()
    }
    
    private func contactSupport() {
        let email = dataManager.supportEmailValue
        if let url = URL(string: "mailto:\(email)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if !granted {
                DispatchQueue.main.async {
                    notificationsEnabled = false
                }
            }
        }
    }
    
    #if DEBUG
    private func loadSampleData() {
        // Add some sample test results for testing
        for i in 1...5 {
            let questions = Array(dataManager.allQuestions.shuffled().prefix(50))
            var test = MockTest(questions: questions, timerEnabled: i % 2 == 0)
            
            // Simulate random answers
            for question in questions {
                let selectedAnswer = Int.random(in: 0...3)
                let isCorrect = question.isCorrect(selectedAnswer)
                let answer = UserAnswer(
                    questionID: question.id,
                    selectedAnswer: selectedAnswer,
                    isCorrect: isCorrect
                )
                test.answers.append(answer)
            }
            
            test.endDate = Date().addingTimeInterval(-Double(i) * 86400) // i days ago
            test.totalTimeSpent = Double.random(in: 1200...2400)
            
            dataManager.saveMockTest(test)
        }
    }
    #endif
}

// MARK: - DataManager Extension (Add these methods)

extension DataManager {
    
    /// Clear practice history
    func clearPracticeHistory() {
        practiceHistory.removeAll()
        practiceSessions.removeAll()
        UserDefaults.standard.removeObject(forKey: "practice_history")
        UserDefaults.standard.removeObject(forKey: "practice_sessions")
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(DataManager())
    }
}
