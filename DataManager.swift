import Foundation
import StoreKit
import SwiftUI

@MainActor
class DataManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var hasUnlockedFullAccess = false
    @Published var fullAccessProduct: Product?
    
    // MARK: - Constants
    
    private let fullAccessProductID = "full_access_299"
    let supportEmailValue = "support@yourapp.com" // Change this
    
    // MARK: - Questions Data
    
    @Published var allQuestions: [Question] = []
    @Published var practiceHistory: [UserAnswer] = []
    @Published var practiceSessions: [PracticeSession] = []
    
    // MARK: - Mock Tests Data
    
    @Published var mockTestHistory = MockTestHistory()
    
    // MARK: - Private Properties
    
    private var updateListenerTask: Task<Void, Never>?
    private let questionsKey = "practice_history"
    private let sessionsKey = "practice_sessions"
    private let mockTestsKey = "mock_test_history"
    
    // MARK: - Initialization
    
    init() {
        updateListenerTask = listenForTransactions()
        
        Task {
            await checkPurchaseStatus()
            await loadProducts()
            await loadQuestions()
            loadPracticeHistory()
            loadMockTestHistory()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Load Products
    
    func loadProducts() async {
        do {
            let products = try await Product.products(for: [fullAccessProductID])
            
            if let product = products.first {
                fullAccessProduct = product
                print("✅ Product loaded: \(product.displayName) - \(product.displayPrice)")
            } else {
                print("⚠️ No products found for ID: \(fullAccessProductID)")
            }
            
        } catch {
            print("❌ Failed to load products: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Purchase
    
    enum PurchaseResult {
        case success
        case cancelled
        case pending
        case failed
    }
    
    func purchaseFullAccess() async throws -> PurchaseResult {
        guard let product = fullAccessProduct else {
            throw StoreError.productNotFound
        }
        
        do {
            let result = try await product.purchase()
            
            switch result {
                
            case .success(let verification):
                // Verify the transaction
                let transaction = try checkVerified(verification)
                
                // Grant access
                hasUnlockedFullAccess = true
                
                // Always finish the transaction
                await transaction.finish()
                
                print("✅ Purchase successful")
                return .success
                
            case .userCancelled:
                print("ℹ️ User cancelled purchase")
                return .cancelled
                
            case .pending:
                print("⏳ Purchase pending")
                return .pending
                
            @unknown default:
                print("⚠️ Unknown purchase result")
                return .failed
            }
            
        } catch StoreKitError.userCancelled {
            return .cancelled
            
        } catch {
            print("❌ Purchase error: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async throws {
        var foundPurchase = false
        
        // Check all transactions for this user
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if transaction.productID == fullAccessProductID {
                    hasUnlockedFullAccess = true
                    foundPurchase = true
                    print("✅ Restored purchase: \(transaction.productID)")
                }
                
            } catch {
                print("⚠️ Failed to verify transaction: \(error)")
                // Continue checking other transactions
            }
        }
        
        if !foundPurchase {
            print("ℹ️ No purchases to restore")
        }
    }
    
    // MARK: - Check Purchase Status
    
    func checkPurchaseStatus() async {
        var hasEntitlement = false
        
        // Check current entitlements
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if transaction.productID == fullAccessProductID {
                    hasEntitlement = true
                    print("✅ User has entitlement: \(transaction.productID)")
                    break
                }
                
            } catch {
                print("⚠️ Transaction verification failed: \(error)")
            }
        }
        
        hasUnlockedFullAccess = hasEntitlement
        
        if hasEntitlement {
            print("✅ Full access unlocked")
        } else {
            print("🔒 Full access locked")
        }
    }
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() -> Task<Void, Never> {
        return Task.detached {
            // Listen for transaction updates
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    await MainActor.run {
                        if transaction.productID == self.fullAccessProductID {
                            self.hasUnlockedFullAccess = true
                            print("✅ Transaction update: Access granted")
                        }
                    }
                    
                    // Always finish the transaction
                    await transaction.finish()
                    
                } catch {
                    print("⚠️ Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Verification
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            // Handle verification failure
            print("❌ Verification failed: \(error)")
            throw error
            
        case .verified(let safe):
            // Transaction is verified
            return safe
        }
    }
    
    // MARK: - Store Errors
    
    enum StoreError: LocalizedError {
        case productNotFound
        case verificationFailed
        
        var errorDescription: String? {
            switch self {
            case .productNotFound:
                return "Product not found. Please try again."
            case .verificationFailed:
                return "Could not verify purchase. Please contact support."
            }
        }
    }
    
    // MARK: - Load Questions
    
    func loadQuestions() async {
        guard let url = Bundle.main.url(forResource: "questions", withExtension: "json") else {
            print("❌ questions.json not found")
            // Use sample questions for testing
            allQuestions = Question.samples
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let result = try decoder.decode(QuestionData.self, from: data)
            
            await MainActor.run {
                allQuestions = result.questions
                print("✅ Loaded \(allQuestions.count) questions (version \(result.version ?? "unknown"))")
            }
            
        } catch {
            print("❌ Failed to load questions: \(error.localizedDescription)")
            // Fallback to sample questions
            await MainActor.run {
                allQuestions = Question.samples
            }
        }
    }
    
    // MARK: - Question Helpers
    
    /// Get random questions for practice
    func getRandomQuestions(count: Int, category: QuestionCategory? = nil) -> [Question] {
        var questions = allQuestions
        
        // Filter by category if specified
        if let category = category {
            questions = questions.filter { $0.category == category }
        }
        
        // Shuffle and take requested count
        return Array(questions.shuffled().prefix(count))
    }
    
    /// Get questions not answered yet
    func getUnansweredQuestions(count: Int, category: QuestionCategory? = nil) -> [Question] {
        let answeredIDs = Set(practiceHistory.map { $0.questionID })
        var questions = allQuestions.filter { !answeredIDs.contains($0.id) }
        
        if let category = category {
            questions = questions.filter { $0.category == category }
        }
        
        return Array(questions.shuffled().prefix(count))
    }
    
    /// Get questions the user got wrong
    func getIncorrectQuestions() -> [Question] {
        let incorrectIDs = Set(practiceHistory.filter { !$0.isCorrect }.map { $0.questionID })
        return allQuestions.filter { incorrectIDs.contains($0.id) }
    }
    
    /// Generate balanced mock test with proper distribution
    func generateBalancedMockTest(count: Int = 50) -> [Question]? {
        guard allQuestions.count >= count else { return nil }
        
        // Target distribution (approximate DVSA test)
        let targetDistribution: [QuestionCategory: Int] = [
            .roadAndTrafficSigns: 8,
            .rulesOfTheRoad: 6,
            .hazardAwareness: 6,
            .safetyAndYourVehicle: 5,
            .motorwayRules: 5,
            .vehicleHandling: 5,
            .vulnerableRoadUsers: 5,
            .safetyMargins: 4,
            .attitudeToOtherRoadUsers: 3,
            .alertness: 2,
            .otherTypesOfVehicle: 2,
            .essentialDocuments: 2,
            .incidents: 2,
            .vehicleLoading: 1
        ]
        
        // Group questions by category
        var byCategory: [QuestionCategory: [Question]] = [:]
        for question in allQuestions {
            byCategory[question.category, default: []].append(question)
        }
        
        var selected: [Question] = []
        
        // Select questions according to distribution
        for (category, targetCount) in targetDistribution {
            let available = byCategory[category] ?? []
            let shuffled = available.shuffled()
            let take = min(targetCount, shuffled.count)
            selected.append(contentsOf: shuffled.prefix(take))
        }
        
        // If we don't have enough, fill with random questions
        while selected.count < count {
            let remaining = allQuestions.filter { q in !selected.contains(where: { $0.id == q.id }) }
            if let random = remaining.randomElement() {
                selected.append(random)
            } else {
                break
            }
        }
        
        // Shuffle final selection and return exactly count questions
        return Array(selected.shuffled().prefix(count))
    }
    
    // MARK: - Practice History
    
    func recordAnswer(_ answer: UserAnswer) {
        // Free users: limited history
        if !hasUnlockedFullAccess && practiceHistory.count >= 20 {
            practiceHistory.removeFirst()
        }
        
        practiceHistory.append(answer)
        savePracticeHistory()
    }
    
    func savePracticeSession(_ session: PracticeSession) {
        // Free users: limited sessions
        if !hasUnlockedFullAccess && practiceSessions.count >= 5 {
            practiceSessions.removeFirst()
        }
        
        practiceSessions.append(session)
        savePracticeHistory()
    }
    
    private func savePracticeHistory() {
        let encoder = JSONEncoder()
        
        if let historyData = try? encoder.encode(practiceHistory) {
            UserDefaults.standard.set(historyData, forKey: questionsKey)
        }
        
        if let sessionsData = try? encoder.encode(practiceSessions) {
            UserDefaults.standard.set(sessionsData, forKey: sessionsKey)
        }
    }
    
    private func loadPracticeHistory() {
        let decoder = JSONDecoder()
        
        if let historyData = UserDefaults.standard.data(forKey: questionsKey),
           let history = try? decoder.decode([UserAnswer].self, from: historyData) {
            practiceHistory = history
        }
        
        if let sessionsData = UserDefaults.standard.data(forKey: sessionsKey),
           let sessions = try? decoder.decode([PracticeSession].self, from: sessionsData) {
            practiceSessions = sessions
        }
    }
    
    // MARK: - Statistics
    
    var totalQuestionsAnswered: Int {
        practiceHistory.count
    }
    
    var correctAnswersCount: Int {
        practiceHistory.filter { $0.isCorrect }.count
    }
    
    var overallAccuracy: Double {
        guard totalQuestionsAnswered > 0 else { return 0 }
        return Double(correctAnswersCount) / Double(totalQuestionsAnswered) * 100
    }
    
    func accuracy(for category: QuestionCategory) -> Double {
        let categoryAnswers = practiceHistory.filter { answer in
            allQuestions.first(where: { $0.id == answer.questionID })?.category == category
        }
        
        guard !categoryAnswers.isEmpty else { return 0 }
        
        let correct = categoryAnswers.filter { $0.isCorrect }.count
        return Double(correct) / Double(categoryAnswers.count) * 100
    }
    
    // MARK: - Mock Tests
    
    /// Generate a new mock test with 50 random questions
    func generateMockTest() -> MockTest? {
        // Use balanced distribution if enough questions
        if let balancedQuestions = generateBalancedMockTest(count: MockTest.questionsPerTest) {
            return MockTest(questions: balancedQuestions, timerEnabled: true)
        }
        
        // Fallback to random selection
        guard allQuestions.count >= MockTest.questionsPerTest else {
            print("⚠️ Not enough questions for mock test")
            return nil
        }
        
        let testQuestions = Array(allQuestions.shuffled().prefix(MockTest.questionsPerTest))
        return MockTest(questions: testQuestions, timerEnabled: true)
    }
    
    /// Save completed mock test
    func saveMockTest(_ test: MockTest) {
        // Free users: only keep 1 test
        if !hasUnlockedFullAccess {
            mockTestHistory.completedTests = [test]
        } else {
            mockTestHistory.completedTests.append(test)
            
            // Keep last 50 tests to avoid unbounded growth
            if mockTestHistory.completedTests.count > 50 {
                mockTestHistory.completedTests.removeFirst()
            }
        }
        
        saveMockTestHistory()
    }
    
    /// Check if user can take a mock test (free users get 1)
    func canTakeMockTest() -> Bool {
        mockTestHistory.canTakeMockTest(isPremium: hasUnlockedFullAccess)
    }
    
    private func saveMockTestHistory() {
        let encoder = JSONEncoder()
        
        if let data = try? encoder.encode(mockTestHistory) {
            UserDefaults.standard.set(data, forKey: mockTestsKey)
        }
    }
    
    private func loadMockTestHistory() {
        let decoder = JSONDecoder()
        
        if let data = UserDefaults.standard.data(forKey: mockTestsKey),
           let history = try? decoder.decode(MockTestHistory.self, from: data) {
            mockTestHistory = history
        }
    }
    
    /// Delete all mock test history (for settings)
    func clearMockTestHistory() {
        mockTestHistory = MockTestHistory()
        UserDefaults.standard.removeObject(forKey: mockTestsKey)
    }
}

// MARK: - Testing Helper (Remove in Production)

#if DEBUG
extension DataManager {
    
    /// Reset purchase status for testing
    func resetPurchaseForTesting() {
        hasUnlockedFullAccess = false
        print("⚠️ Purchase reset for testing")
    }
    
    /// Simulate unlock for testing UI without purchase
    func unlockForTesting() {
        hasUnlockedFullAccess = true
        print("⚠️ Unlocked for testing (not a real purchase)")
    }
}
#endif
