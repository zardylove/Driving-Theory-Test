import SwiftUI

// MARK: - Mock Test Session View

struct MockTestSessionView: View {
    
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var test: MockTest
    @State private var currentQuestionIndex = 0
    @State private var selectedAnswer: Int?
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var showExitAlert = false
    
    let onComplete: (MockTest) -> Void
    let onExit: () -> Void
    
    init(test: MockTest, onComplete: @escaping (MockTest) -> Void, onExit: @escaping () -> Void) {
        _test = State(initialValue: test)
        self.onComplete = onComplete
        self.onExit = onExit
    }
    
    private var currentQuestion: Question {
        test.questions[currentQuestionIndex]
    }
    
    private var progress: Double {
        Double(test.answers.count) / Double(test.questions.count)
    }
    
    private var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Header
            headerView
            
            // Question content
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Question number and text
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Question \(currentQuestionIndex + 1) of 50")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Label(currentQuestion.category.rawValue, systemImage: currentQuestion.category.icon)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
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
                            MockTestAnswerButton(
                                text: option,
                                isSelected: selectedAnswer == index
                            ) {
                                selectAnswer(index)
                            }
                        }
                    }
                }
                .padding()
            }
            
            // Bottom navigation
            navigationButtons
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
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .alert("Exit Mock Test?", isPresented: $showExitAlert) {
            Button("Keep Going", role: .cancel) { }
            Button("Exit", role: .destructive) {
                stopTimer()
                onExit()
            }
        } message: {
            Text("Your progress will not be saved if you exit now.")
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                // Progress
                VStack(alignment: .leading, spacing: 4) {
                    Text("Progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(test.answers.count)/50 answered")
                        .font(.caption.bold())
                        .foregroundColor(.accentColor)
                }
                
                Spacer()
                
                // Timer
                if test.timerEnabled {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formattedTime)
                            .font(.caption.bold())
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .padding(.horizontal)
            
            ProgressView(value: progress)
                .tint(.accentColor)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack(spacing: 12) {
            // Previous Button
            Button(action: goToPrevious) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Previous")
                }
                .font(.subheadline)
                .foregroundColor(.accentColor)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
            .disabled(currentQuestionIndex == 0)
            .opacity(currentQuestionIndex == 0 ? 0.5 : 1)
            
            // Next/Submit Button
            Button(action: goToNext) {
                HStack {
                    Text(currentQuestionIndex == test.questions.count - 1 ? "Submit Test" : "Next")
                    if currentQuestionIndex < test.questions.count - 1 {
                        Image(systemName: "chevron.right")
                    }
                }
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedAnswer != nil ? Color.accentColor : Color.gray)
                .cornerRadius(12)
            }
            .disabled(selectedAnswer == nil)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Actions
    
    private func selectAnswer(_ index: Int) {
        selectedAnswer = index
    }
    
    private func goToNext() {
        guard let answer = selectedAnswer else { return }
        
        // Record answer if not already recorded for this question
        if !test.answers.contains(where: { $0.questionID == currentQuestion.id }) {
            let isCorrect = currentQuestion.isCorrect(answer)
            
            let userAnswer = UserAnswer(
                questionID: currentQuestion.id,
                selectedAnswer: answer,
                isCorrect: isCorrect,
                timeSpent: 0  // We track total time for mock tests
            )
            
            test.answers.append(userAnswer)
        }
        
        // Move to next question or finish
        if currentQuestionIndex < test.questions.count - 1 {
            currentQuestionIndex += 1
            
            // Load previous answer if exists
            if let existingAnswer = test.answers.first(where: { $0.questionID == test.questions[currentQuestionIndex].id }) {
                selectedAnswer = existingAnswer.selectedAnswer
            } else {
                selectedAnswer = nil
            }
        } else {
            finishTest()
        }
    }
    
    private func goToPrevious() {
        guard currentQuestionIndex > 0 else { return }
        
        currentQuestionIndex -= 1
        
        // Load previous answer if exists
        if let existingAnswer = test.answers.first(where: { $0.questionID == currentQuestion.id }) {
            selectedAnswer = existingAnswer.selectedAnswer
        } else {
            selectedAnswer = nil
        }
    }
    
    private func finishTest() {
        stopTimer()
        
        test.endDate = Date()
        test.totalTimeSpent = elapsedTime
        
        onComplete(test)
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        guard test.timerEnabled else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime += 1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Mock Test Answer Button

struct MockTestAnswerButton: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 2)
            )
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MockTestSessionView(
            test: MockTest.sample,
            onComplete: { _ in },
            onExit: { }
        )
        .environmentObject(DataManager())
    }
}
