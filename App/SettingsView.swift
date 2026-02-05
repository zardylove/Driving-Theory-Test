import SwiftUI
import UIKit

// MARK: - Settings View

struct SettingsView: View {

    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.openURL) private var openURL

    @State private var showClearDataAlert = false
    @State private var showClearTestsAlert = false
    @State private var showRestoreAlert = false
    @State private var isRestoring = false
    @State private var restoreMessage = ""

    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        NavigationStack {
            List {

                accountSection
                preferencesSection
                dataManagementSection
                helpSection
                appInfoSection

#if DEBUG
                developerToolsSection
#endif
            }
            .navigationTitle("Settings")
            .alert("Clear All Data?", isPresented: $showClearDataAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All Data", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("This will delete all your practice history, sessions, and mock test results. This action cannot be undone.")
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

    // MARK: - Sections

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
                        ProgressView().scaleEffect(0.9)
                        Text("Restoring…")
                    } else {
                        Label("Restore Purchases", systemImage: "arrow.clockwise")
                    }
                }
            }
            .disabled(isRestoring)
        }
    }

    private var preferencesSection: some View {
        Section(header: Text("Preferences")) {

            Toggle(isOn: $soundEnabled) {
                Label("Sound Effects", systemImage: "speaker.wave.2.fill")
            }
            .tint(.accentColor)

            Toggle(isOn: $hapticsEnabled) {
                Label("Haptic Feedback", systemImage: "waveform")
            }
            .tint(.accentColor)

            // NOTE:
            // We are intentionally NOT showing "Daily Reminders" yet.
            // It will come back once we implement real scheduling (not just permission).
        }
    }

    private var dataManagementSection: some View {
        Section(header: Text("Data Management")) {

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

            Button(role: .destructive, action: { showClearTestsAlert = true }) {
                Label("Clear Mock Test History", systemImage: "trash")
            }

            Button(role: .destructive, action: { showClearDataAlert = true }) {
                Label("Clear All Data", systemImage: "trash.fill")
            }
        }
    }

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
#endif
        }
    }

#if DEBUG
    private var developerToolsSection: some View {
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
    }
#endif

    // MARK: - Actions

    private func restorePurchases() {
        guard !isRestoring else { return }
        isRestoring = true

        Task {
            do {
                try await dataManager.restorePurchases()

                isRestoring = false
                if dataManager.hasUnlockedFullAccess {
                    restoreMessage = "Successfully restored your purchase!"
                } else {
                    restoreMessage = "No previous purchases were found for this Apple ID."
                }
                showRestoreAlert = true
            } catch {
                isRestoring = false
                restoreMessage = "Unable to restore purchases. Please try again."
                showRestoreAlert = true
            }
        }
    }

    private func clearAllData() {
        dataManager.clearMockTestHistory()
        dataManager.clearPracticeHistory()
    }

    private func clearMockTests() {
        dataManager.clearMockTestHistory()
    }

    private func contactSupport() {
        let email = dataManager.supportEmailValue

        if let url = URL(string: "mailto:\(email)") {
            openURL(url)
        } else {
            UIPasteboard.general.string = email
            restoreMessage = "Support email copied to clipboard: \(email)"
            showRestoreAlert = true
        }
    }

#if DEBUG
    private func loadSampleData() {
        for i in 1...5 {
            let questions = Array(dataManager.allQuestions.shuffled().prefix(MockTest.questionsPerTest))
            var test = MockTest(questions: questions, timerEnabled: i % 2 == 0)

            for question in questions {
                let selectedAnswer = Int.random(in: 0..<max(2, question.options.count))
                let isCorrect = question.isCorrect(selectedAnswer)
                let answer = UserAnswer(
                    questionID: question.id,
                    selectedAnswer: selectedAnswer,
                    isCorrect: isCorrect
                )
                test.answers.append(answer)
            }

            test.endDate = Date().addingTimeInterval(-Double(i) * 86400)
            test.totalTimeSpent = Double.random(in: 1200...2400)

            dataManager.saveMockTest(test)
        }
    }
#endif
}

// MARK: - Simple Info Screens (kept in the same file for beginner simplicity)

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("About")
                    .font(.title.bold())

                Text("Driving Theory Test is a practice app to help you prepare for the UK driving theory test.")
                    .font(.body)

                Text("Note: This app is not affiliated with the DVSA.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                Text("Privacy Policy")
                    .font(.title.bold())

                Text("This app does not collect personal data.")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 10) {
                    Bullet(text: "No accounts (you don’t sign in).")
                    Bullet(text: "No tracking.")
                    Bullet(text: "No analytics SDKs (at this stage).")
                    Bullet(text: "Your progress is stored only on your device using Apple’s standard storage.")
                    Bullet(text: "If you buy Premium, payment is handled by Apple via the App Store (we do not see your payment details).")
                }

                Text("If we add online features later (such as downloading images), we will update this policy and the App Store privacy details.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text("Support")
                    .font(.headline)

                Text("If you have any questions, contact: \(DataManager().supportEmailValue)")
                    .font(.body)
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TermsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                Text("Terms of Use")
                    .font(.title.bold())

                Text("This app is provided for educational practice.")
                    .font(.headline)

                Text("We do our best to provide accurate content, but we do not guarantee that using the app will result in passing the theory test.")
                    .font(.body)

                Text("This app is not affiliated with the DVSA.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("Terms of Use")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Small reusable bullet row

private struct Bullet: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("•")
            Text(text)
            Spacer(minLength: 0)
        }
        .font(.body)
    }
}

// MARK: - DataManager helper (kept here because your project currently has no separate file for it)

extension DataManager {
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
