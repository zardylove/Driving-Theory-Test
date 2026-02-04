import SwiftUI

// MARK: - Home View

struct HomeView: View {

    @EnvironmentObject private var dataManager: DataManager
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    heroHeader

                    if shouldShowContinue {
                        continueSection
                    }

                    quickActionsSection

                    if dataManager.mockTestHistory.totalTestsTaken > 0 {
                        progressSnapshotSection
                    }

                    if !dataManager.mockTestHistory.completedTests.isEmpty {
                        recentActivitySection
                    }

                    if !dataManager.hasUnlockedFullAccess {
                        premiumCard
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Home")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "car.fill")
                .font(.system(size: 50))
                .foregroundColor(.accentColor)

            Text("Ready to Practice?")
                .font(.title.bold())

            if let greeting = timeBasedGreeting {
                Text(greeting)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Continue Section

    private var shouldShowContinue: Bool {
        dataManager.totalQuestionsAnswered > 0 || dataManager.mockTestHistory.totalTestsTaken > 0
    }

    private var continueSection: some View {
        NavigationLink {
            // ✅ Rename this destination to your actual “continue” screen
            PracticeHomeView()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Continue Learning")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(continueSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            .padding()
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(12)
        }
        .accessibilityLabel("Continue learning")
    }

    private var continueSubtitle: String {
        if let lastTest = dataManager.mockTestHistory.completedTests.last,
           let lastTestDate = lastTest.endDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Last test \(formatter.localizedString(for: lastTestDate, relativeTo: Date()))"
        } else if dataManager.totalQuestionsAnswered > 0 {
            return "\(dataManager.totalQuestionsAnswered) questions answered"
        }
        return "Keep practicing"
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            VStack(spacing: 12) {

                // Practice
                NavigationLink {
                    // ✅ Rename this to your actual practice screen
                    PracticeHomeView()
                } label: {
                    QuickActionButton(
                        icon: "book.fill",
                        title: "Practice Questions",
                        subtitle: "\(dataManager.allQuestions.count) available",
                        color: .blue
                    )
                }

                // Mock Test
                Group {
                    if dataManager.canTakeMockTest() || dataManager.hasUnlockedFullAccess {
                        NavigationLink {
                            // ✅ Rename this to your actual mock test entry screen
                            MockTestHomeView()
                        } label: {
                            QuickActionButton(
                                icon: "doc.text.fill",
                                title: "Mock Test",
                                subtitle: "\(MockTest.questionsPerTest) questions",
                                color: .green
                            )
                        }
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            QuickActionButton(
                                icon: "doc.text.fill",
                                title: "Mock Test",
                                subtitle: "Premium required",
                                color: .green,
                                isLocked: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Hazard (Coming Soon)
                QuickActionButton(
                    icon: "exclamationmark.triangle.fill",
                    title: "Hazard Perception",
                    subtitle: "Coming soon",
                    color: .orange,
                    isDisabled: true
                ) { }
            }
        }
    }

    // MARK: - Progress Snapshot

    private var progressSnapshotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Progress")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {

                if let lastTest = dataManager.mockTestHistory.completedTests.last {
                    ProgressSnapshotCard(
                        icon: "doc.text.fill",
                        title: "Last Test",
                        value: "\(lastTest.score)/\(MockTest.questionsPerTest)",
                        subtitle: lastTest.isPassed ? "Passed" : "Not passed",
                        color: lastTest.isPassed ? .green : .red
                    )
                }

                ProgressSnapshotCard(
                    icon: "chart.bar.fill",
                    title: "Average",
                    value: String(format: "%.0f%%", dataManager.mockTestHistory.averagePercentage),
                    subtitle: "\(dataManager.mockTestHistory.totalTestsTaken) tests",
                    color: .blue
                )

                ProgressSnapshotCard(
                    icon: "checkmark.seal.fill",
                    title: "Pass Rate",
                    value: String(format: "%.0f%%", dataManager.mockTestHistory.passRate),
                    subtitle: "\(dataManager.mockTestHistory.testsPassed) passed",
                    color: dataManager.mockTestHistory.passRate >= 80 ? .green : .orange
                )

                if let weakest = dataManager.mockTestHistory.weakestCategories.first {
                    ProgressSnapshotCard(
                        icon: weakest.icon,
                        title: "Focus On",
                        value: weakest.displayName,
                        subtitle: "Needs practice",
                        color: .orange,
                        isCompact: true
                    )
                }
            }
        }
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)

                Spacer()

                if dataManager.mockTestHistory.completedTests.count > 3 {
                    NavigationLink(destination: ProgressView()) {
                        Text("See All")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }
            }

            ForEach(Array(dataManager.mockTestHistory.recentTests.prefix(3))) { test in
                NavigationLink(destination: MockTestResultView(test: test)) {
                    RecentActivityRow(test: test)
                }
            }
        }
    }

    // MARK: - Premium Card

    private var premiumCard: some View {
        Button(action: { showPaywall = true }) {
            HStack(spacing: 16) {
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Unlock Full Access")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Unlimited tests, full progress tracking, and more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.yellow.opacity(0.2), Color.orange.opacity(0.2)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
            )
        }
        .accessibilityLabel("Unlock full access")
    }

    // MARK: - Helpers

    private var timeBasedGreeting: String? {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning! Let's start your practice."
        case 12..<17:
            return "Good afternoon! Time to practice."
        case 17..<22:
            return "Good evening! Keep up the momentum."
        default:
            return nil
        }
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    var isLocked: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    init(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        isLocked: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void = {}
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.color = color
        self.isLocked = isLocked
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)

                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
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
            .opacity(isDisabled ? 0.6 : 1.0)
        }
        .disabled(isDisabled)
    }
}

// MARK: - Progress Snapshot Card

struct ProgressSnapshotCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    var isCompact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Spacer()
            }

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(isCompact ? .headline : .title2.bold())
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Recent Activity Row

struct RecentActivityRow: View {
    let test: MockTest

    private var relativeTime: String {
        guard let endDate = test.endDate else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: endDate, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(test.isPassed ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: test.isPassed ? "checkmark" : "xmark")
                    .font(.caption.bold())
                    .foregroundColor(test.isPassed ? .green : .red)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Mock Test")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    Text("\(test.score)/\(MockTest.questionsPerTest)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•").foregroundColor(.secondary)

                    Text(relativeTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Placeholder destinations (rename these)

/// ✅ Rename/remove these once you plug in your real screens.
/// They exist so you can paste this file without immediate build errors.
struct PracticeHomeView: View {
    var body: some View { Text("Practice").navigationTitle("Practice") }
}

struct MockTestHomeView: View {
    var body: some View { Text("Mock Test").navigationTitle("Mock Test") }
}

// MARK: - Preview

#Preview {
    HomeView()
        .environmentObject(DataManager())
}
