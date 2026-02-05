import SwiftUI

// MARK: - Practice View

struct PracticeView: View {

    @EnvironmentObject var dataManager: DataManager
    @State private var showCategoryPicker = false
    @State private var showPaywall = false

    // This represents an "active run" (questions + selected category)
    @State private var activeRun: PracticeRun?

    var body: some View {
        NavigationStack {
            if let run = activeRun {
                PracticeSessionView(
                    questions: run.questions,
                    category: run.category,
                    onComplete: { result in
                        // Save the summary (uses your existing PracticeSession model)
                        dataManager.savePracticeSession(result)
                        activeRun = nil
                    },
                    onExit: {
                        activeRun = nil
                    }
                )
            } else {
                practiceMenuView
            }
        }
    }

    // MARK: - Practice Menu

    private var practiceMenuView: some View {
        ScrollView {
            VStack(spacing: 20) {

                VStack(spacing: 8) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)

                    Text("Practice Questions")
                        .font(.title.bold())

                    Text("\(dataManager.allQuestions.count) questions available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)

                if dataManager.totalQuestionsAnswered > 0 {
                    statsCard
                }

                VStack(spacing: 16) {

                    PracticeOptionButton(
                        title: "Quick Practice",
                        subtitle: "10 random questions",
                        icon: "bolt.fill",
                        color: .blue
                    ) {
                        startPractice(count: 10, category: nil)
                    }

                    PracticeOptionButton(
                        title: "Practice by Category",
                        subtitle: "Choose specific topics",
                        icon: "folder.fill",
                        color: .green
                    ) {
                        showCategoryPicker = true
                    }

                    let incorrect = dataManager.getIncorrectQuestions()
                    if !incorrect.isEmpty {
                        PracticeOptionButton(
                            title: "Review Incorrect",
                            subtitle: "\(incorrect.count) questions",
                            icon: "arrow.clockwise",
                            color: .orange
                        ) {
                            startReviewIncorrect()
                        }
                    }

                    if !dataManager.hasUnlockedFullAccess {
                        PracticeOptionButton(
                            title: "Full Practice Session",
                            subtitle: "\(MockTest.questionsPerTest) questions • Premium",
                            icon: "star.fill",
                            color: .yellow,
                            isPremium: true
                        ) {
                            showPaywall = true
                        }
                    } else {
                        PracticeOptionButton(
                            title: "Full Practice Session",
                            subtitle: "\(MockTest.questionsPerTest) questions",
                            icon: "star.fill",
                            color: .yellow
                        ) {
                            startPractice(count: MockTest.questionsPerTest, category: nil)
                        }
                    }
                }
                .padding(.horizontal)

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Practice")
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerView { category in
                showCategoryPicker = false
                startPractice(count: 10, category: category)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(spacing: 12) {
            Text("Your Progress")
                .font(.headline)

            HStack(spacing: 30) {
                StatItem(value: "\(dataManager.totalQuestionsAnswered)", label: "Answered")
                StatItem(value: String(format: "%.0f%%", dataManager.overallAccuracy), label: "Accuracy")
                StatItem(value: "\(dataManager.practiceSessions.count)", label: "Sessions")
            }
        }
        .padding()
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Actions

    private func startPractice(count: Int, category: QuestionCategory?) {
        let questions = dataManager.getRandomQuestions(count: count, category: category)
        guard !questions.isEmpty else { return }
        activeRun = PracticeRun(questions: questions, category: category)
    }

    private func startReviewIncorrect() {
        let questions = dataManager.getIncorrectQuestions()
        guard !questions.isEmpty else { return }
        activeRun = PracticeRun(questions: Array(questions.prefix(10)), category: nil)
    }
}

// MARK: - Active practice run model (UI-only)

struct PracticeRun: Equatable {
    let questions: [Question]
    let category: QuestionCategory?
}

// MARK: - Practice Option Button

struct PracticeOptionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    var isPremium: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 50, height: 50)
                    .background(color.opacity(0.15))
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)

                        if isPremium {
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
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        }
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.accentColor)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Category Picker

struct CategoryPickerView: View {
    let onSelect: (QuestionCategory) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(QuestionCategory.allCases, id: \.self) { category in
                    Button {
                        onSelect(category)
                    } label: {
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(.accentColor)
                                .frame(width: 30)

                            Text(category.displayName)
                                .foregroundColor(.primary)

                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Choose Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PracticeView()
        .environmentObject(DataManager())
}
