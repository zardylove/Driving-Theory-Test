import Foundation
import StoreKit
import SwiftUI

@MainActor
final class DataManager: ObservableObject {

    // MARK: - Published Properties (Purchases)

    @Published var hasUnlockedFullAccess: Bool = false
    @Published var fullAccessProduct: Product?

    // MARK: - Constants

    private let fullAccessProductID = "full_access_299"
    let supportEmailValue = "support@yourapp.com" // TODO: Change this later

    // MARK: - Questions Data

    @Published var allQuestions: [Question] = []
    @Published var practiceHistory: [UserAnswer] = []
    @Published var practiceSessions: [PracticeSession] = []

    // MARK: - Mock Tests Data

    @Published var mockTestHistory = MockTestHistory()

    // MARK: - Storage Keys

    private enum StorageKey {
        static let practiceHistory = "practice_history"
        static let practiceSessions = "practice_sessions"
        static let mockTestHistory = "mock_test_history"
    }

    // MARK: - Private Properties

    private var transactionListenerTask: Task<Void, Never>?

    // MARK: - Initialization

    init() {
        transactionListenerTask = listenForTransactions()

        Task {
            await checkPurchaseStatus()
            await loadProducts()
            await loadQuestions()

            loadPracticeHistory()
            loadMockTestHistory()
        }
    }

    deinit {
        transactionListenerTask?.cancel()
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
                let transaction = try checkVerified(verification)
                hasUnlockedFullAccess = true
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
        // ✅ This tells the App Store to re-check purchases and refresh entitlements.
        try await AppStore.sync()

        var foundPurchase = false

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
            }
        }

        if !foundPurchase {
            print("ℹ️ No purchases to restore")
        }
    }

    // MARK: - Check Purchase Status

    func checkPurchaseStatus() async {
        var hasEntitlement = false

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
        print(hasEntitlement ? "✅ Full access unlocked" : "🔒 Full access locked")
    }

    // MARK: - Transaction Listener

    /// Listens for StoreKit transaction updates safely (without touching MainActor state from a detached task).
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }

            for await result in Transaction.updates {
                await self.handleTransactionUpdate(result)
            }
        }
    }

    /// Runs on MainActor (because DataManager is @MainActor).
    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        do {
            let transaction = try checkVerified(result)

            if transaction.productID == fullAccessProductID {
                hasUnlockedFullAccess = true
                print("✅ Transaction update: Access granted")
            }

            await transaction.finish()
        } catch {
            print("⚠️ Transaction verification failed: \(error)")
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            print("❌ Verification failed: \(error)")
            throw error
        case .verified(let safe):
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
            allQuestions = Question.samples
            return
        }

        do {
            // Avoid blocking the main thread with Data(contentsOf:)
            let data = try await Task.detached(priority: .utility) {
                try Data(contentsOf: url)
            }.value

            let decoder = JSONDecoder()
            let result = try decoder.decode(QuestionData.self, from: data)

            allQuestions = result.questions
            print("✅ Loaded \(allQuestions.count) questions (version \(result.version ?? "unknown"))")
        } catch {
            print("❌ Failed to load questions: \(error.localizedDescription)")
            allQuestions = Question.samples
        }
    }

    // MARK: - Question Helpers

    func getRandomQuestions(count: Int, category: QuestionCategory? = nil) -> [Question] {
        var questions = allQuestions

        if let category = category {
            questions = questions.filter { $0.category == category }
        }

        return Array(questions.shuffled().prefix(count))
    }

    func getUnansweredQuestions(count: Int, category: QuestionCategory? = nil) -> [Question] {
        let answeredIDs = Set(practiceHistory.map { $0.questionID })

        var questions = allQuestions.filter { !answeredIDs.contains($0.id) }
        if let category = category {
            questions = questions.filter { $0.category == category }
        }

        return Array(questions.shuffled().prefix(count))
    }

    func getIncorrectQuestions() -> [Question] {
        let incorrectIDs = Set(practiceHistory.filter { !$0.isCorrect }.map { $0.questionID })
        return allQuestions.filter { incorrectIDs.contains($0.id) }
    }

    func generateBalancedMockTest(count: Int = 50) -> [Question]? {
        guard allQuestions.count >= count else { return nil }

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

        var byCategory: [QuestionCategory: [Question]] = [:]
        for question in allQuestions {
            byCategory[question.category, default: []].append(question)
        }

        var selected: [Question] = []

        for (category, targetCount) in targetDistribution {
            let available = byCategory[category] ?? []
            let shuffled = available.shuffled()
            let take = min(targetCount, shuffled.count)
            selected.append(contentsOf: shuffled.prefix(take))
        }

        while selected.count < count {
            let remaining = allQuestions.filter { q in
                !selected.contains(where: { $0.id == q.id })
            }

            if let random = remaining.randomElement() {
                selected.append(random)
            } else {
                break
            }
        }

        return Array(selected.shuffled().prefix(count))
    }

    // MARK: - Practice History

    func recordAnswer(_ answer: UserAnswer) {
        if !hasUnlockedFullAccess && practiceHistory.count >= 20 {
            practiceHistory.removeFirst()
        }

        practiceHistory.append(answer)
        savePracticeData()
    }

    func savePracticeSession(_ session: PracticeSession) {
        if !hasUnlockedFullAccess && practiceSessions.count >= 5 {
            practiceSessions.removeFirst()
        }

        practiceSessions.append(session)
        savePracticeData()
    }

    private func savePracticeData() {
        let encoder = JSONEncoder()

        if let historyData = try? encoder.encode(practiceHistory) {
            UserDefaults.standard.set(historyData, forKey: StorageKey.practiceHistory)
        }

        if let sessionsData = try? encoder.encode(practiceSessions) {
            UserDefaults.standard.set(sessionsData, forKey: StorageKey.practiceSessions)
        }
    }

    private func loadPracticeHistory() {
        let decoder = JSONDecoder()

        if let historyData = UserDefaults.standard.data(forKey: StorageKey.practiceHistory),
           let history = try? decoder.decode([UserAnswer].self, from: historyData) {
            practiceHistory = history
        }

        if let sessionsData = UserDefaults.standard.data(forKey: StorageKey.practiceSessions),
           let sessions = try? decoder.decode([PracticeSession].self, from: sessionsData) {
            practiceSessions = sessions
        }
    }

    // MARK: - Statistics

    var totalQuestionsAnswered: Int { practiceHistory.count }

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

    func generateMockTest() -> MockTest? {
        if let balancedQuesti
