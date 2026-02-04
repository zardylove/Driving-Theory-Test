import SwiftUI

// MARK: - Mock Tests View

struct MockTestsView: View {

    @EnvironmentObject var dataManager: DataManager
    @State private var showPaywall = false
    @State private var showStartTest = false
    @State private var activeTest: MockTest?
    @State private var isInTest = false

    @State private var showError = false
    @State private var errorMessage = ""

    private var canStartTest: Bool {
        dataManager.hasUnlockedFullAccess || dataManager.canTakeMockTest()
    }

    private var questionsPerTest: Int { MockTest.questionsPerTest }

    var body: some View {
        NavigationStack {

            if isInTest, let test = activeTest {
                MockTestSessionView(
                    test: test,
                    onComplete: { completedTest in
                        dataManager.saveMockTest(completedTest)
                        isInTest = false
                        activeTest = nil
                    },
                    onExit: {
                        isInTest = false
                        activeTest = nil
                    }
                )
            } else {
                mockTestsMenuView
            }
        }
    }

    // MARK: - Mock Tests Menu

    private var mockTestsMenuView: some View {
        ScrollView {
            VStack(spacing: 20) {

                VStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)

                    Text("Mock Tests")
                        .font(.title.bold())

                    Text("Full-length practice tests")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)

                infoCard

                if canStartTest {
                    startTestButton
                } else {
                    premiumUpsellButton
                }

                if !dataManager.mockTestHistory.completedTests.isEmpty {
                    historySection
                }

                if dataManager.mockTestHistory.totalTestsTaken > 0 {
                    statisticsSection
                }

                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("Mock Tests")
        .confirmationDialog("Start Mock Test", isPresented: $showStartTest) {
            Button("Start with Timer") {
                startMockTest(timerEnabled: true)
            }

            Button("Start without Timer") {
                startMockTest(timerEnabled: false)
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose whether to enable the timer for this test.")
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .alert("Unable to Start Test", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Format")
                .font(.headline)

            HStack(spacing: 20) {
                InfoItem(icon: "list.number", text: "\(questionsPerTest) Questions")
                InfoItem(icon: "checkmark.circle", text: "Pass: 43/\(questionsPerTest)")
                InfoItem(icon: "timer", text: "Timer Optional")
            }

            if !dataManager.hasUnlockedFullAccess {
                Divider()

                HStack {
                    Image(systemName: dataManager.canTakeMockTest() ? "checkmark.circle.fill" : "lock.fill")
                        .foregroundColor(dataManager.canTakeMockTest() ? .green : .orange)

                    Text(dataManager.canTakeMockTest() ? "1 free test available" : "Unlock unlimited tests")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Start Test Button

    private var startTestButton: some View {
        Button(action: { showStartTest = true }) {
            HStack {
                Image(systemName: "play.fill")
                Text("Start Mock Test")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .cornerRadius(12)
        }
    }

    // MARK: - Premium Upsell Button

    private var premiumUpsellButton: some View {
        Button(action: { showPaywall = true }) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock Unlimited Tests")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("You've used your free test")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.white)
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [.orange, .pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Tests")
                .font(.headline)

            ForEach(dataManager.mockTestHistory.recentTests) { test in
                NavigationLink(destination: MockTestResultView(test: test)) {
                    MockTestHistoryRow(test: test, questionsPerTest: questionsPerTest)
                }
            }
        }
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overall Statistics")
                .font(.headline)

            VStack(spacing: 12) {
                StatRow(label: "Tests Taken", value: "\(dataManager.mockTestHistory.totalTestsTaken)")

                StatRow(
                    label: "Pass Rate",
                    value: String(format: "%.0f%%", dataManager.mockTestHistory.passRate),
                    valueColor: dataManager.mockTestHistory.passRate >= 80 ? .green : .orange
                )

                StatRow(
                    label: "Average Score",
                    value: String(format: "%.1f/%d", dataManager.mockTestHistory.averageScore, questionsPerTest)
                )

                StatRow(
                    label: "Best Score",
                    value: "\(dataManager.mockTestHistory.bestScore)/\(questionsPerTest)"
                )
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        }
    }

    // MARK: - Actions

    private func startMockTest(timerEnabled: Bool) {
        guard let test = dataManager.generateMockTest() else {
            errorMessage = "Not enough questions are available to generate a mock test."
            showError = true
            return
        }

        var testCopy = test
        testCopy.timerEnabled = timerEnabled

        activeTest = testCopy
        isInTest = true
    }
}

// MARK: - Info Item

struct InfoItem: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Mock Test History Row

struct MockTestHistoryRow: View {
    let test: MockTest
    let questionsPerTest: Int

    var body: some View {
        HStack {
            Image(systemName: test.isPassed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(test.isPassed ? .green : .red)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(test.isPassed ? "Passed" : "Failed")
                        .font(.headline)

                    Text("\(test.score)/\(questionsPerTest)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    Text(test.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if test.timerEnabled {
                        Text("•").foregroundColor(.secondary)

                        HStack(spacing: 2) {
                            Image(systemName: "timer")
                            Text(test.formattedTime)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.headline)
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - Preview

#Preview {
    MockTestsView()
        .environmentObject(DataManager())
}
