import SwiftUI

// MARK: - Practice Session View

struct PracticeSessionView: View {
    
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var session: PracticeSession
    @State private var currentQuestionIndex = 0
    @State private var selectedAnswer: Int?
    @State private var showingExplanation = false
    @State private var questionStartTime = Date()
    @State private var showExitAlert = false
    
    let onComplete: (PracticeSession) -> Void
    let onExit: () -> Void
    
    init(session: PracticeSession, onComplete: @escaping (PracticeSession) -> Void, onExit: @escaping () -> Void) {
        _session = State(initialValue: session)
        self.onComplete = onComplete
        self.onExit = onExit
    }
    
    private var currentQuestion: Question {
        session.questions[currentQuestionIndex]
    }
    
    private var progress: Double {
        Double(currentQuestionIndex + 1) / Double(session.questions.count)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Header with progress
            headerView
            
            // Question content
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Question text
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Question \(currentQuestionIndex + 1) of \(session.questions.count)")
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
                    
                    // Answer options
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
                    
                    // Explanation (shown after answer)
                    if showingExplanation {
                        explanationView
                    }
                }
                .padding()
            }
            
            // Bottom button
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
                Label("\(currentQuestionIndex + 1)/\(session.questions.count)", systemImage: "list.number")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Label(currentQuestion.category.rawValue, systemImage: currentQuestion.category.icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Explanation View
    
    private var explanationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: selectedAnswer == currentQuestion.correctAnswer ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(selectedAnswer == currentQuestion.correctAnswer ? .green : .red)
                
                Text(selectedAnswer == currentQuestion.correctAnswer ? "Correct!" : "Incorrect")
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
                        Text(currentQuestionIndex < session.questions.count - 1 ? "Next Question" : "Finish")
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
        
        let timeSpent = Date().timeIntervalSince(questionStartTime)
        let isCorrect = currentQuestion.isCorrect(answer)
        
        let userAnswer = UserAnswer(
            questionID: currentQuestion.id,
            selectedAnswer: answer,
            isCorrect: isCorrect,
            timeSpent: timeSpent
        )
        
        session.answers.append(userAnswer)
        dataManager.recordAnswer(userAnswer)
        
        withAnimation {
            showingExplanation = true
        }
    }
    
    private func moveToNextQuestion() {
        if currentQuestionIndex < session.questions.count - 1 {
            // Move to next question
            currentQuestionIndex += 1
            selectedAnswer = nil
            showingExplanation = false
            questionStartTime = Date()
        } else {
            // Finish session
            var completedSession = session
            completedSession.endDate = Date()
            onComplete(completedSession)
        }
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
            session: PracticeSession(questions: Question.samples),
            onComplete: { _ in },
            onExit: { }
        )
        .environmentObject(DataManager())
    }
}
