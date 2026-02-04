import SwiftUI

// MARK: - Progress Dashboard View

struct ProgressDashboardView: View {

    @EnvironmentObject var dataManager: DataManager
    @State private var showPaywall = false
    @State private var historyFilter: HistoryFilter = .all
    @State private var timeRangeFilter: TimeRange = .all

    enum HistoryFilter: String, CaseIterable {
        case all = "All"
        case passed = "Passed"
        case failed = "Failed"
    }

    enum TimeRange: String, CaseIterable {
        case all = "All Time"
        case last7Days = "Last 7 Days"
        case last30Days = "Last 30 Days"
    }

    private var isPremium: Bool { dataManager.hasUnlockedFullAccess }
    private var hasData: Bool { dataManager.mockTestHistory.totalTestsTaken > 0 }
    private var questionsPerTest: Int { MockTest.questionsPerTest }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    if !hasData {
                        emptyStateView
                    } else {
                        overviewSection

                        if isPremium {
                            trendSection
                            categoryBreakdownSection
                            historySection
                            recommendationsSection
                        } else {
                            limitedHistorySection
                            premiumUpsellCard
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Progress")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 80))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No Progress Yet")
                .font(.title2.bold())

            Text("Complete your first mock test to see your progress here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Overview Section

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overview")
                .font(.title2.bold())

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {

                StatCard(
                    icon: "doc.text.fill",
                    title: "Tests Taken",
                    value: "\(dataManager.mockTestHistory.totalTestsTaken)",
                    color: .blue
                )

                StatCard(
                    icon: "checkmark.seal.fill",
                    title: "Pass Rate",
                    value: String(format: "%.0f%%", dataManager.mockTestHistory.passRate),
                    color: dataManager.mockTestHistory.passRate >= 80 ? .green : .orange
                )

                StatCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Average Score",
                    value: String(format: "%.1f/%d", dataManager.mockTestHistory.averageScore, questionsPerTest),
                    color: .purple
                )

                StatCard(
                    icon: "trophy.fill",
                    title: "Best Score",
                    value: "\(dataManager.mockTestHistory.bestScore)/\(questionsPerTest)",
                    color: .yellow
                )
            }
        }
    }

    // MARK: - Trend Section

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Performance")
                .font(.title3.bold())

            HStack(spacing: 20) {
                TrendCard(title: "Last 7 Days", tests: testsInRange(days: 7), icon: "calendar")
                TrendCard(title: "Last 30 Days", tests: testsInRange(days: 30), icon: "calendar")
            }
        }
    }

    // MARK: - Category Breakdown Section

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Category Performance")
                .font(.title3.bold())

            HStack(spacing: 12) {
                if let strongest = strongestCategory {
                    CategoryHighlightCard(
                        title: "Strongest",
                        category: strongest.category,
                        accuracy: strongest.accuracy,
                        color: .green
                    )
                }

                if let weakest = weakestCategory {
                    CategoryHighlightCard(
                        title: "Weakest",
                        category: weakest.category,
                        accuracy: weakest.accuracy,
                        color: .red
                    )
                }
            }

            VStack(spacing: 8) {
                ForEach(allCategoryStats.sorted(by: { $0.accuracy > $1.accuracy }), id: \.category) { stat in
                    CategoryPerformanceRow(
                        category: stat.category,
                        correct: stat.correct,
                        total: stat.total,
                        accuracy: stat.accuracy
                    )
                }
            }
        }
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Test History")
                    .font(.title3.bold())

                Spacer()

                Menu {
                    Picker("Filter", selection: $historyFilter) {
                        ForEach(HistoryFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }

                    Picker("Time Range", selection: $timeRangeFilter) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text("Filter")
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
            }

            let filteredTests = getFilteredTests()

            if filteredTests.isEmpty {
                Text("No tests match the current filters.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(filteredTests) { test in
                    NavigationLink(destination: MockTestResultView(test: test)) {
                        HistoryTestRow(test: test, questionsPerTest: questionsPerTest)
                    }
                }
            }
        }
    }

    // MARK: - Limited History (Free Users)

    private var limitedHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Test History")
                .font(.title3.bold())

            if let lastTest = dataManager.mockTestHistory.completedTests.last {
                NavigationLink(destination: MockTestResultView(test: lastTest)) {
                    HistoryTestRow(test: lastTest, questionsPerTest: questionsPerTest)
                }

                Text("Unlock full history and detailed analytics")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Recommendations Section

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recommendations")
                .font(.title3.bold())

            VStack(spacing: 12) {
                ForEach(getRecommendations(), id: \.title) { recommendation in
                    RecommendationCard(recommendation: recommendation)
                }
            }
        }
    }

    // MARK: - Premium Upsell

    private var premiumUpsellCard: some View {
        Button(action: { showPaywall = true }) {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Unlock Full Analytics")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("Get detailed insights, category breakdown, and full test history")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }

                HStack(spacing: 16) {
                    FeatureCheckmark(text: "Performance trends")
                    FeatureCheckmark(text: "Category stats")
                    FeatureCheckmark(text: "Full history")
                }
                .font(.caption2)
            }
            .padding()
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
        }
        .accessibilityLabel("Unlock full analytics")
    }

    // MARK: - Helper Functions

    private func testsInRange(days: Int) -> [MockTest] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return dataManager.mockTestHistory.completedTests.filter { test in
            test.startDate >= cutoffDate
        }
    }

    private func getFilteredTests() -> [MockTest] {
        var tests = dataManager.mockTestHistory.completedTests

        switch historyFilter {
        case .passed:
            tests = tests.filter { $0.isPassed }
        case .failed:
            tests = tests.filter { !$0.isPassed }
        case .all:
            break
        }

        switch timeRangeFilter {
        case .last7Days:
            let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            tests = tests.filter { $0.startDate >= cutoff }
        case .last30Days:
            let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            tests = tests.filter { $0.startDate >= cutoff }
        case .all:
            break
        }

        return tests.reversed()
    }

    private var allCategoryStats: [(category: QuestionCategory, correct: Int, total: Int, accuracy: Double)] {
        var categoryTotals: [QuestionCategory: (correct: Int, total: Int)] = [:]

        for test in dataManager.mockTestHistory.completedTests {
            for (category, stats) in test.categoryBreakdown {
                if var existing = categoryTotals[category] {
                    existing.correct += stats.correct
                    existing.total += stats.total
                    categoryTotals[category] = existing
                } else {
                    categoryTotals[category] = (stats.correct, stats.total)
                }
            }
        }

        return categoryTotals.compactMap { category, stats in
            guard stats.total > 0 else { return nil }
            let accuracy = Double(stats.correct) / Double(stats.total) * 100
            return (category, stats.correct, stats.total, accuracy)
        }
    }

    private var strongestCategory: (category: QuestionCategory, accuracy: Double)? {
        allCategoryStats.max(by: { $0.accuracy < $1.accuracy }).map { ($0.category, $0.accuracy) }
    }

    private var weakestCategory: (category: QuestionCategory, accuracy: Double)? {
        allCategoryStats.min(by: { $0.accuracy < $1.accuracy }).map { ($0.category, $0.accuracy) }
    }

    private func getRecommendations() -> [Recommendation] {
        var recommendations: [Recommendation] = []

        if let weakest = weakestCategory, weakest.accuracy < 70 {
            recommendations.append(Recommendation(
                icon: "target",
                title: "Focus on \(weakest.category.displayName)",
                description: "Your accuracy is \(String(format: "%.0f%%", weakest.accuracy)) in this category. Practice more questions here.",
                color: .orange
            ))
        }

        let timedTests = dataManager.mockTestHistory.completedTests.filter { $0.timerEnabled }
        if timedTests.count < 3 {
            recommendations.append(Recommendation(
                icon: "timer",
                title: "Try a Timed Mock Test",
                description: "Practice with time pressure to simulate the real exam experience.",
                color: .blue
            ))
        }

        if dataManager.mockTestHistory.passRate < 80 {
            recommendations.append(Recommendation(
                icon: "arrow.up.circle",
                title: "Boost Your Pass Rate",
                description: "You're at \(String(format: "%.0f%%", dataManager.mockTestHistory.passRate)). Take more tests to improve consistency.",
                color: .green
            ))
        }

        if dataManager.mockTestHistory.passRate >= 90 && dataManager.mockTestHistory.totalTestsTaken >= 5 {
            recommendations.append(Recommendation(
                icon: "star.fill",
                title: "You're Ready!",
                description: "Excellent performance! You're well-prepared for the real test.",
                color: .yellow
            ))
        }

        return recommendations
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.title.bold())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Trend Card

struct TrendCard: View {
    let title: String
    let tests: [MockTest]
    let icon: String

    private var averageScore: Double {
        guard !tests.isEmpty else { return 0 }
        let total = tests.reduce(0) { $0 + $1.score }
        return Double(total) / Double(tests.count)
    }

    private var passRate: Double {
        guard !tests.isEmpty else { return 0 }
        let passed = tests.filter { $0.isPassed }.count
        return Double(passed) / Double(tests.count) * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.caption.bold())
            }
            .foregroundColor(.secondary)

            Text("\(tests.count) tests")
                .font(.caption2)
                .foregroundColor(.secondary)

            if !tests.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Avg:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f/%d", averageScore, MockTest.questionsPerTest))
                            .font(.caption.bold())
                    }

                    HStack {
                        Text("Pass:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.0f%%", passRate))
                            .font(.caption.bold())
                            .foregroundColor(passRate >= 80 ? .green : .orange)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Category Highlight Card

struct CategoryHighlightCard: View {
    let title: String
    let category: QuestionCategory
    let accuracy: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }

            Text(category.displayName)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(String(format: "%.0f%%", accuracy))
                .font(.title3.bold())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Category Performance Row

struct CategoryPerformanceRow: View {
    let category: QuestionCategory
    let correct: Int
    let total: Int
    let accuracy: Double

    private var barColor: Color {
        if accuracy >= 80 { return .green }
        if accuracy >= 60 { return .orange }
        return .red
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 24)

                Text(category.displayName)
                    .font(.subheadline)

                Spacer()

                Text("\(correct)/\(total)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(String(format: "%.0f%%", accuracy))
                    .font(.subheadline.bold())
                    .foregroundColor(barColor)
                    .frame(width: 50, alignment: .trailing)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.secondary.opacity(0.2))
                    Rectangle()
                        .fill(barColor)
                        .frame(width: geometry.size.width * (accuracy / 100))
                }
            }
            .frame(height: 6)
            .cornerRadius(3)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - History Test Row

struct HistoryTestRow: View {
    let test: MockTest
    let questionsPerTest: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(test.isPassed ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: test.isPassed ? "checkmark" : "xmark")
                    .font(.headline)
                    .foregroundColor(test.isPassed ? .green : .red)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(test.isPassed ? "Passed" : "Failed")
                        .font(.subheadline.bold())
                        .foregroundColor(test.isPassed ? .green : .red)

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
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Recommendation

struct Recommendation: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let color: Color
}

struct RecommendationCard: View {
    let recommendation: Recommendation

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: recommendation.icon)
                .font(.title3)
                .foregroundColor(recommendation.color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.title)
                    .font(.subheadline.bold())

                Text(recommendation.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding()
        .background(recommendation.color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Feature Checkmark

struct FeatureCheckmark: View {
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.accentColor)
            Text(text)
        }
    }
}

// MARK: - Preview

#Preview {
    ProgressDashboardView()
        .environmentObject(DataManager())
}
