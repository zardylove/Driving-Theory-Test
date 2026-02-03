import Foundation

// MARK: - Question Model

struct Question: Identifiable, Codable, Hashable {
    let id: String
    let text: String
    let options: [String]
    let correctAnswer: Int
    let explanation: String
    let category: QuestionCategory
    let difficulty: QuestionDifficulty
    let imageURL: String?
    
    func isCorrect(_ selectedAnswer: Int) -> Bool {
        return selectedAnswer == correctAnswer
    }
}

// MARK: - Question Category

enum QuestionCategory: String, Codable, CaseIterable {
    case alertness = "alertness"
    case attitudeToOtherRoadUsers = "attitudeToOtherRoadUsers"
    case safetyAndYourVehicle = "safetyAndYourVehicle"
    case safetyMargins = "safetyMargins"
    case hazardAwareness = "hazardAwareness"
    case vulnerableRoadUsers = "vulnerableRoadUsers"
    case otherTypesOfVehicle = "otherTypesOfVehicle"
    case vehicleHandling = "vehicleHandling"
    case motorwayRules = "motorwayRules"
    case rulesOfTheRoad = "rulesOfTheRoad"
    case roadAndTrafficSigns = "roadAndTrafficSigns"
    case essentialDocuments = "essentialDocuments"
    case incidents = "incidents"
    case vehicleLoading = "vehicleLoading"
    
    var displayName: String {
        switch self {
        case .alertness: return "Alertness"
        case .attitudeToOtherRoadUsers: return "Attitude to Other Road Users"
        case .safetyAndYourVehicle: return "Safety and Your Vehicle"
        case .safetyMargins: return "Safety Margins"
        case .hazardAwareness: return "Hazard Awareness"
        case .vulnerableRoadUsers: return "Vulnerable Road Users"
        case .otherTypesOfVehicle: return "Other Types of Vehicle"
        case .vehicleHandling: return "Vehicle Handling"
        case .motorwayRules: return "Motorway Rules"
        case .rulesOfTheRoad: return "Rules of the Road"
        case .roadAndTrafficSigns: return "Road and Traffic Signs"
        case .essentialDocuments: return "Essential Documents"
        case .incidents: return "Incidents, Accidents and Emergencies"
        case .vehicleLoading: return "Vehicle Loading"
        }
    }
    
    var icon: String {
        switch self {
        case .alertness: return "eye.fill"
        case .attitudeToOtherRoadUsers: return "person.2.fill"
        case .safetyAndYourVehicle: return "wrench.and.screwdriver.fill"
        case .safetyMargins: return "ruler.fill"
        case .hazardAwareness: return "exclamationmark.triangle.fill"
        case .vulnerableRoadUsers: return "figure.walk"
        case .otherTypesOfVehicle: return "bus.fill"
        case .vehicleHandling: return "steeringwheel"
        case .motorwayRules: return "road.lanes"
        case .rulesOfTheRoad: return "signpost.right.fill"
        case .roadAndTrafficSigns: return "triangle.fill"
        case .essentialDocuments: return "doc.text.fill"
        case .incidents: return "cross.case.fill"
        case .vehicleLoading: return "cube.box.fill"
        }
    }
}

// MARK: - Question Difficulty

enum QuestionDifficulty: String, Codable, CaseIterable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"
}

// MARK: - Question Data (JSON wrapper)

struct QuestionData: Codable {
    let version: String?
    let lastUpdated: String?
    let totalQuestions: Int?
    let questions: [Question]
}

// MARK: - User Answer

struct UserAnswer: Identifiable, Codable {
    let id: UUID
    let questionID: String
    let selectedAnswer: Int
    let isCorrect: Bool
    let timestamp: Date
    
    init(questionID: String, selectedAnswer: Int, isCorrect: Bool) {
        self.id = UUID()
        self.questionID = questionID
        self.selectedAnswer = selectedAnswer
        self.isCorrect = isCorrect
        self.timestamp = Date()
    }
}

// MARK: - Practice Session

struct PracticeSession: Identifiable, Codable {
    let id: UUID
    let category: QuestionCategory?
    let questionCount: Int
    let correctCount: Int
    let startDate: Date
    let endDate: Date
    
    var accuracy: Double {
        guard questionCount > 0 else { return 0 }
        return Double(correctCount) / Double(questionCount) * 100
    }
    
    init(category: QuestionCategory?, questionCount: Int, correctCount: Int, startDate: Date, endDate: Date) {
        self.id = UUID()
        self.category = category
        self.questionCount = questionCount
        self.correctCount = correctCount
        self.startDate = startDate
        self.endDate = endDate
    }
}

// MARK: - Sample Questions

extension Question {
    static let samples: [Question] = [
        Question(
            id: "sample001",
            text: "What does a red traffic light mean?",
            options: [
                "Stop if safe to do so",
                "Proceed with caution",
                "Stop and wait",
                "Go if the road is clear"
            ],
            correctAnswer: 2,
            explanation: "A red traffic light means you must stop and wait behind the stop line until the light changes to green.",
            category: .roadAndTrafficSigns,
            difficulty: .easy,
            imageURL: nil
        ),
        Question(
            id: "sample002",
            text: "What is the national speed limit on a motorway for cars?",
            options: [
                "60 mph",
                "70 mph",
                "80 mph",
                "50 mph"
            ],
            correctAnswer: 1,
            explanation: "The national speed limit on UK motorways for cars and motorcycles is 70 mph, unless signs show otherwise.",
            category: .motorwayRules,
            difficulty: .easy,
            imageURL: nil
        ),
        Question(
            id: "sample003",
            text: "You see a pedestrian with a white stick and red band. This shows the person is:",
            options: [
                "Physically disabled",
                "Deaf and blind",
                "Blind only",
                "Deaf only"
            ],
            correctAnswer: 1,
            explanation: "A white stick with a red band indicates that the person is deaf and blind. Extra care should be taken as they cannot see or hear approaching vehicles.",
            category: .vulnerableRoadUsers,
            difficulty: .medium,
            imageURL: nil
        ),
        Question(
            id: "sample004",
            text: "You are driving in heavy rain. Your steering suddenly becomes very light. What should you do?",
            options: [
                "Steer towards the side of the road",
                "Apply gentle acceleration",
                "Brake firmly to reduce speed",
                "Ease off the accelerator"
            ],
            correctAnswer: 3,
            explanation: "This is aquaplaning - when water builds up between your tyres and the road surface. Ease off the accelerator and slow down gradually. Do not brake or turn the steering wheel suddenly.",
            category: .vehicleHandling,
            difficulty: .hard,
            imageURL: nil
        ),
        Question(
            id: "sample005",
            text: "When may you sound the horn on your vehicle?",
            options: [
                "To give you right of way",
                "To attract a friend's attention",
                "To warn others of your presence",
                "To make slower drivers move over"
            ],
            correctAnswer: 2,
            explanation: "You may only sound your horn to warn other road users of your presence. It should not be used aggressively or between 11:30 pm and 7:00 am in built-up areas.",
            category: .rulesOfTheRoad,
            difficulty: .easy,
            imageURL: nil
        )
    ]
}
