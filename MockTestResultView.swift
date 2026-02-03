import SwiftUI

// MARK: - Mock Test Result View

struct MockTestResultView: View {
    
    let test: MockTest
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Result Header
                resultHeader
                
                // Score Card
                scoreCard
                
                // Test Details
                testDetails
                
                // Category Breakdown
                categoryBreakdown
                
                // Weak Categories Alert
                if !test.weakCategories.isEmpty {
                    weakCategoriesAlert
                }
                
                // Review Incorrect Button
                if !test.incorrectAnswers.isEmpty {
                    reviewIncorrectButton
                }
                
                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("Test Results")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Result Header
    
    private var resultHeader: some View {
        VStack(spacing: 16) {
            Image(systemName: test.isPassed ? "checkmark.seal.fill" : "xmark.seal.fill")
                .font(.system(size: 80))
                .foregroundColor(test.isPassed ? .green : .red)
            
            Text(test.isPassed ? "Passed!" : "Not Passed")
                .font(.largeTitle.bold())
                .foregroundColor(test.isPassed ? .green : .red)
            
            Text(test.isPassed ? "Well done! You're ready for the real test." : "Keep practicing. You'll get there!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Score Card
    
    private var scoreCard: some View {
        VStack(spacing: 16) {
            // Main Score
            VStack(spacing: 4) {
                Text("\(test.score)")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundColor(.accentColor)
                
                Text("out of 50")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            // Percentage
            Text(String(format: "%.0f%%", test.percentage))
                .font(.title2.bold())
                .foregroundColor(.secondary)
            
            Divider()
            
            // Pass threshold indicator
            HStack {
                Text("Pass Mark")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(MockTest.passingScore)/50")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)
            }
            
            // Score comparison
            let scoreAbovePass = test.score - MockTest.passingScore
            if test.isPassed {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.green)
                    Text("You scored \(scoreAbovePass) marks above the pass mark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.red)
                    Text("You need \(abs(scoreAbovePass)) more marks to pass")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Test Details
    
    private var testDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Details")
                .font(.headline)
            
            VStack(spacing: 12) {
                DetailRow(
                    icon: "calendar",
                    label: "Date",
                    value: test.formattedDate
                )
                
                if test.timerEnabled {
                    DetailRow(
                        icon: "timer",
                        label: "Time Taken",
                        value: test.formattedTime
                    )
                }
                
                DetailRow(
                    icon: "checkmark.circle",
                    label: "Correct Answers",
                    value: "\(test.score)"
                )
                
                DetailRow(
                    icon: "xmark.circle",
                    label: "Incorrect Answers",
                    value: "\(test.incorrectAnswers.count)"
                )
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        }
    }
    
    // MARK: - Category Breakdown
    
    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance by Category")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(Array(test.categoryBreakdown.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { category in
                    if let stats = test.categoryBreakdown[category] {
                        CategoryStatRow(
                            category: category,
                            stats: stats
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Weak Categories Alert
    
    private var weakCategoriesAlert: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                
                Text("Areas to Improve")
                    .font(.headline)
            }
            
            Text("Focus on these categories:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ForEach(test.weakCategories, id: \.self) { category in
                HStack {
                    Image(systemName: category.icon)
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    
                    Text(category.rawValue)
                        .font(.subheadline)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Review Incorrect Button
    
    private var reviewIncorrectButton: some View {
        NavigationLink(destination: ReviewIncorrectView(test: test)) {
            HStack {
                Image(systemName: "arrow.clockwise")
                Text("Review Incorrect Answers")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.orange)
            .cornerRadius(12)
        }
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.headline)
        }
    }
}

// MARK: - Category Stat Row

struct CategoryStatRow: View {
    let category: QuestionCategory
    let stats: CategoryStats
    
    var accuracyColor: Color {
        if stats.accuracy >= 80 {
            return .green
        } else if stats.accuracy >= 60 {
            return .orange
        } else {
            return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                
                Text(category.rawValue)
                    .font(.subheadline)
                
                Spacer()
                
                Text("\(stats.correct)/\(stats.total)")
                    .font(.subheadline.bold())
                    .foregroundColor(accuracyColor)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                    
                    Rectangle()
                        .fill(accuracyColor)
                        .frame(width: geometry.size.width * (stats.accuracy / 100))
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

// MARK: - Review Incorrect View

struct ReviewIncorrectView: View {
    
    let test: MockTest
    @State private var currentIndex = 0
    @Environment(\.dismiss) var dismiss
    
    private var incorrectQuestions: [(question: Question, userAnswer: UserAnswer)] {
        test.incorrectAnswers.compactMap { answer in
            guard let question = test.questions.first(where: { $0.id == answer.questionID }) else {
                return nil
            }
            return (question, answer)
        }
    }
    
    private var current: (question: Question, userAnswer: UserAnswer)? {
        guard !incorrectQuestions.isEmpty, currentIndex < incorrectQuestions.count else {
            return nil
        }
        return incorrectQuestions[currentIndex]
    }
    
    var body: some View {
        if let current = current {
            VStack(spacing: 0) {
                
                // Header
                VStack(spacing: 8) {
                    HStack {
                        Text("Incorrect Answer \(currentIndex + 1) of \(incorrectQuestions.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    ProgressView(value: Double(currentIndex + 1) / Double(incorrectQuestions.count))
                        .tint(.orange)
                }
                .padding(.vertical, 8)
                .background(Color(.systemGroupedBackground))
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Question
                        VStack(alignment: .leading, spacing: 12) {
                            Label(current.question.category.rawValue, systemImage: current.question.category.icon)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(current.question.text)
                                .font(.title3)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        
                        // Answers with feedback
                        VStack(spacing: 12) {
                            ForEach(Array(current.question.options.enumerated()), id: \.offset) { index, option in
                                ReviewAnswerButton(
                                    text: option,
                                    isUserAnswer: index == current.userAnswer.selectedAnswer,
                                    isCorrect: index == current.question.correctAnswer
                                )
                            }
                        }
                        
                        // Explanation
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.orange)
                                Text("Explanation")
                                    .font(.headline)
                            }
                            
                            Text(current.question.explanation)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding()
                }
                
                // Navigation
                HStack(spacing: 12) {
                    Button(action: { currentIndex -= 1 }) {
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
                    .disabled(currentIndex == 0)
                    .opacity(currentIndex == 0 ? 0.5 : 1)
                    
                    Button(action: {
                        if currentIndex < incorrectQuestions.count - 1 {
                            currentIndex += 1
                        } else {
                            dismiss()
                        }
                    }) {
                        HStack {
                            Text(currentIndex < incorrectQuestions.count - 1 ? "Next" : "Done")
                            if currentIndex < incorrectQuestions.count - 1 {
                                Image(systemName: "chevron.right")
                            }
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(12)
                    }
                }
                .padding()
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Review Incorrect")
            .navigationBarTitleDisplayMode(.inline)
            
        } else {
            Text("No incorrect answers to review")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Review Answer Button

struct ReviewAnswerButton: View {
    let text: String
    let isUserAnswer: Bool
    let isCorrect: Bool
    
    var backgroundColor: Color {
        if isCorrect {
            return .green.opacity(0.2)
        } else if isUserAnswer {
            return .red.opacity(0.2)
        }
        return Color(.systemBackground)
    }
    
    var borderColor: Color {
        if isCorrect {
            return .green
        } else if isUserAnswer {
            return .red
        }
        return .secondary.opacity(0.3)
    }
    
    var body: some View {
        HStack {
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            if isCorrect {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if isUserAnswer {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 2)
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MockTestResultView(test: MockTest.sample)
    }
}
