import SwiftUI

// MARK: - Premium Required View

struct PremiumRequiredView: View {
    
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var showPaywall = false
    @State private var isRestoring = false
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""
    
    let feature: String
    let icon: String
    let description: String
    
    init(
        feature: String = "This Feature",
        icon: String = "star.fill",
        description: String = "This feature requires premium access"
    ) {
        self.feature = feature
        self.icon = icon
        self.description = description
    }
    
    var body: some View {
        VStack(spacing: 24) {
            
            Spacer()
            
            // Icon
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundColor(.yellow)
            
            // Title
            Text("Premium Feature")
                .font(.largeTitle.bold())
            
            // Description
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Feature list
            VStack(alignment: .leading, spacing: 12) {
                FeatureCheckItem(text: "Unlimited practice questions")
                FeatureCheckItem(text: "Unlimited mock tests")
                FeatureCheckItem(text: "Full progress analytics")
                FeatureCheckItem(text: "Category breakdown")
            }
            .padding()
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
            
            // Buttons
            VStack(spacing: 12) {
                
                // Unlock Button
                Button(action: { showPaywall = true }) {
                    HStack {
                        Image(systemName: "star.fill")
                        Text("Unlock Full Access")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(12)
                }
                
                // Restore Button
                Button(action: restorePurchases) {
                    HStack {
                        if isRestoring {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.accentColor)
                            Text("Restoring...")
                        } else {
                            Image(systemName: "arrow.clockwise")
                            Text("Restore Purchase")
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                }
                .disabled(isRestoring)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .navigationTitle(feature)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .alert("Restore Purchases", isPresented: $showRestoreAlert) {
            Button("OK", role: .cancel) {
                if dataManager.hasUnlockedFullAccess {
                    dismiss()
                }
            }
        } message: {
            Text(restoreMessage)
        }
    }
    
    // MARK: - Restore Purchases
    
    private func restorePurchases() {
        isRestoring = true
        
        Task {
            do {
                try await dataManager.restorePurchases()
                
                await MainActor.run {
                    isRestoring = false
                    if dataManager.hasUnlockedFullAccess {
                        restoreMessage = "Successfully restored your purchase!"
                    } else {
                        restoreMessage = "No previous purchases found for this Apple ID."
                    }
                    showRestoreAlert = true
                }
            } catch {
                await MainActor.run {
                    isRestoring = false
                    restoreMessage = "Unable to restore purchases. Please try again."
                    showRestoreAlert = true
                }
            }
        }
    }
}

// MARK: - Feature Check Item

struct FeatureCheckItem: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PremiumRequiredView(
            feature: "Unlimited Mock Tests",
            icon: "doc.text.fill",
            description: "Take unlimited practice tests to fully prepare for your theory exam"
        )
        .environmentObject(DataManager())
    }
}
