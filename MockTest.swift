import Foundation

// MARK: - Mock Test

struct MockTest: Identifiable, Codable {
    let id: UUID
    let startDate: Date
    var endDate: Date?
    let questions: [Question]
    var answers: [UserAnswer]
    let timerEnabled: Bool
    var totalTimeSpent: TimeInterval  // Total elapsed time
    
    // Constants
    static let questionsPerTest = 50
    static let passingScore = 43
    
    init(questions: [Question], timerEnabled: Bool = true) {
        self.id = UUID()
        self.startDate = Date()
        self.questions = questions
        self.answers = []
        self.timerEnabled = timerEnabled
        self.totalTimeSpent = 0
    }
    
    // MARK: - Computed Properties
    
    var isComplete: Bool {
        answers.count == questions.count
    }
    
    var score: Int {
        answers.filter { $0.isCorrect }.count
    }
    
    var isPassed: Bool {
        score >= MockTest.passingScore
    }
    
    var percentage: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(score) / Double(questions.count) * 100
    }
    
    var incorrectAnswers: [UserAnswer] {
        answers.filter { !$0.isCorrect }
    }
    
    var incorrectQuestions: [Question] {
        let incorrectIDs = Set(incorrectAnswers.map { $0.questionID })
        return questions.filter { incorrectIDs.contains($0.id) }
    }
    
    // Category breakdown
    var categoryBreakdown: [QuestionCategory: CategoryStats] {
        var breakdown: [QuestionCategory: CategoryStats] = [:]
        
        for question in questions {
            let category = question.category
            let answer = answers.first(where: { $0.questionID == question.id })
            
            if var stats = breakdown[category] {
                stats.total += 1
                if answer?.isCorrect == true {
                    stats.correct += 1
                }
                breakdown[category] = stats
            } else {
                breakdown[category] = CategoryStats(
                    total: 1,
                    correct: answer?.isCorrect == true ? 1 : 0
                )
            }
        }
        
        return breakdown
    }
    
    var weakCategories: [QuestionCategory] {
        categoryBreakdown
            .filter { $0.value.accuracy < 70 }
            .sorted { $0.value.accuracy < $1.value.accuracy }
            .map { $0.key }
    }
    
    var formattedTime: String {
        let minutes = Int(totalTimeSpent) / 60
        let seconds = Int(totalTimeSpent) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startDate)
    }
}

// MARK: - Category Stats

struct CategoryStats: Codable {
    var total: Int
    var correct: Int
    
    var accuracy: Double {
        guard total > 0 else { return 0 }
        return Double(correct) / Double(total) * 100
    }
}

// MARK: - Mock Test History

struct MockTestHistory: Codable {
    var completedTests: [MockTest]
    
    init() {
        self.completedTests = []
    }
    
    // MARK: - Statistics
    
    var totalTestsTaken: Int {
        completedTests.count
    }
    
    var testsPassed: Int {
        completedTests.filter { $0.isPassed }.count
    }
    
    var testsFailed: Int {
        totalTestsTaken - testsPassed
    }
    
    var passRate: Double {
        guard totalTestsTaken > 0 else { return 0 }
        return Double(testsPassed) / Double(totalTestsTaken) * 100
    }
    
    var averageScore: Double {
        guard !completedTests.isEmpty else { return 0 }
        let total = completedTests.reduce(0) { $0 + $1.score }
        return Double(total) / Double(completedTests.count)
    }
    
    var averagePercentage: Double {
        guard !completedTests.isEmpty else { return 0 }
        let total = completedTests.reduce(0.0) { $0 + $1.percentage }
        return total / Double(completedTests.count)
    }
    
    var bestScore: Int {
        completedTests.map { $0.score }.max() ?? 0
    }
    
    var recentTests: [MockTest] {
        Array(completedTests.suffix(5).reversed())
    }
    
    // Most struggled categories across all tests
    var weakestCategories: [QuestionCategory] {
        var categoryTotals: [QuestionCategory: (correct: Int, total: Int)] = [:]
        
        for test in completedTests {
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
        
        return categoryTotals
            .map { category, stats in
                let accuracy = Double(stats.correct) / Double(stats.total) * 100
                return (category, accuracy)
            }
            .sorted { $0.1 < $1.1 }
            .prefix(3)
            .map { $0.0 }
    }
}

// MARK: - Mock Test Extensions

extension MockTest {
    static let sample = MockTest(
        questions: Array(Question.samples.prefix(50)),
        timerEnabled: true
    )
}

// MARK: - Free User Limits

extension MockTestHistory {
    /// Check if user can take another mock test (free users limited to 1)
    func canTakeMockTest(isPremium: Bool) -> Bool {
        if isPremium {
            return true
        }
        return completedTests.isEmpty
    }
    
    var freeTestsRemaining: Int {
        return max(0, 1 - completedTests.count)
    }
}
