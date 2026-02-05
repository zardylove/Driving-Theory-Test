import SwiftUI

// MARK: - Practice Session View (Fixed to match your current models)

struct PracticeSessionView: View {

    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss

    let questions: [Question]
    let category: QuestionCategory?

    let onComplete: (PracticeSession) -> Void
    let onExit: () -> Void

    @State private var currentQuestionIndex = 0
    @State private var selectedAnswer: Int?
    @State private var showingExplanation = false
    @State private var showExitAlert = false

    @State private var startDate = Date()
    @State private var sessionAnswers: [String: UserAnswer] = [:] // questionID -> answer

    private var currentQuestion: Question {
        questions[currentQuestionIndex]
    }

    private var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentQuestionIndex + 1) / Double(questions.count)
    }

    private var answeredCount: Int {
        sessionAnswers.count
    }

    var body: some View {
        VStack(spacing: 0) {

            headerView

            ScrollView {
                VStack(spacing: 24) {

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Question \(currentQuestionIndex + 1) of \(questions.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(currentQuestion.text)
                            .font(.title3)
                            .fontWeight(.medium)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)

                    VStack(spacing: 12) {
                        ForEach(Array(currentQuestion.options.enumerated()), id: \.offset) { index, option in
                            AnswerButton(
                                text: option,
                                isSelected: selectedAnswer == index,
                                isCorrect: showingExplanation ? index == currentQuestion.correctAnswer : nil,
                                isIncorrect: showingExplanation && selectedAnswer == index && index != currentQuestion.correctAnswer
                            ) {
                                selectAnswer(index)
                            }
                            .disabled(showingExplanation)
                        }
                    }

                    if showingExplanation {
                        explanationView
                    }
                }
                .padding()
            }

            bottomButtonView
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { showExitAlert = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text("Exit")
                    }
                }
            }
        }
        .onAppear {
            startDate = Date()
            // If the first question was already answered (unlikely), load it
            loadExistingAnswerForCurrentQuestion()
        }
        .onChange(of: currentQuestionIndex) { _, _ in
            loadExistingAnswerForCurrentQuestion()
        }
        .alert("Exit Practice?", isPresented: $showExitAlert) {
            Button("Keep Practicing", role: .cancel) { }
            Button("Exit", role: .destructive) {
                onExit()
            }
        } message: {
            Text("Your progress will not be saved.")
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: 8) {
            ProgressView(value: progress)
                .tint(.accentColor)

            HStack {
                Label("\(currentQuestionIndex + 1)/\(questions.count)", systemImage: "list.number")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Label(categoryLabelText, systemImage: currentQuestion.category.icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    private var categoryLabelText: String {
        // Show the question's category (more informative), but formatted nicely
        currentQuestion.category.displayName
    }

    // MARK: - Explanation View

    private var explanationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            let isCorrect = selectedAnswer == currentQuestion.correctAnswer

            HStack {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isCorrect ? .green : .red)

                Text(isCorrect ? "Correct!" : "Incorrect")
                    .font(.headline)
            }

            Text(currentQuestion.explanation)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Bottom Button

    private var bottomButtonView: some View {
        VStack {
            if showingExplanation {
                Button(action: moveToNextQuestion) {
                    HStack {
                        Text(currentQuestionIndex < questions.count - 1 ? "Next Question" : "Finish")
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(12)
                }
                .padding()
            } else {
                Button(action: checkAnswer) {
                    Text("Check Answer")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedAnswer != nil ? Color.accentColor : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(selectedAnswer == nil)
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Actions

    private func selectAnswer(_ index: Int) {
        guard !showingExplanation else { return }
        selectedAnswer = index
    }

    private func checkAnswer() {
        guard let answer = selectedAnswer else { return }

        let isCorrect = currentQuestion.isCorrect(answer)

        // Build a UserAnswer matching your current model (no timeSpent)
        let userAnswer = UserAnswer(
            questionID: currentQuestion.id,
            selectedAnswer: answer,
            isCorrect: isCorrect
        )

        // Save locally for this practice run
        sessionAnswers[currentQuestion.id] = userAnswer

        // Also record to global history (DataManager already limits for free users)
        dataManager.recordAnswer(userAnswer)

        withAnimation {
            showingExplanation = true
        }
    }

    private func moveToNextQuestion() {
        if currentQuestionIndex < questions.count - 1 {
            currentQuestionIndex += 1
            showingExplanation = false
        } else {
            finishSession()
        }
    }

    private func loadExistingAnswerForCurrentQuestion() {
        if let existing = sessionAnswers[currentQuestion.id] {
            selectedAnswer = existing.selectedAnswer
            showingExplanation = true
        } else {
            selectedAnswer = nil
            showingExplanation = false
        }
    }

    private func finishSession() {
        let endDate = Date()
        let correctCount = sessionAnswers.values.filter { $0.isCorrect }.count

        let completed = PracticeSession(
            category: category,
            questionCount: questions.count,
            correctCount: correctCount,
            startDate: startDate,
            endDate: endDate
        )

        onComplete(completed)
    }
}

// MARK: - Answer Button

struct AnswerButton: View {
    let text: String
    let isSelected: Bool
    var isCorrect: Bool?
    var isIncorrect: Bool
    let action: () -> Void

    private var backgroundColor: Color {
        if let isCorrect = isCorrect {
            return isCorrect ? .green.opacity(0.2) : .primary.opacity(0.05)
        }
        if isIncorrect {
            return .red.opacity(0.2)
        }
        if isSelected {
            return .accentColor.opacity(0.15)
        }
        return Color(.systemBackground)
    }

    private var borderColor: Color {
        if let isCorrect = isCorrect {
            return isCorrect ? .green : .clear
        }
        if isIncorrect {
            return .red
        }
        if isSelected {
            return .accentColor
        }
        return .secondary.opacity(0.3)
    }

    private var icon: String? {
        if let isCorrect = isCorrect {
            return isCorrect ? "checkmark.circle.fill" : nil
        }
        if isIncorrect {
            return "xmark.circle.fill"
        }
        return nil
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(isIncorrect ? .red : .green)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 2)
            )
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PracticeSessionView(
            questions: Question.samples,
            category: nil,
            onComplete: { _ in },
            onExit: { }
        )
        .environmentObject(DataManager())
    }
}
