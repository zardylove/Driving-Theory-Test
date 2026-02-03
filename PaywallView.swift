// ============================================================================
// CLEAN SINGLE VERSION - PaywallView, Privacy, Terms, About
// Replace duplicates with these clean versions
// ============================================================================

import SwiftUI
import StoreKit
import UIKit

// MARK: - Paywall View (SINGLE CLEAN VERSION)

struct PaywallView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    @State private var purchaseState: PurchaseState = .idle
    @State private var showMessage = false
    @State private var messageTitle = ""
    @State private var messageBody = ""
    
    enum PurchaseState {
        case idle
        case purchasing
        case restoring
        case pending
        case checking
    }
    
    var displayPrice: String {
        dataManager.fullAccessProduct?.displayPrice ?? "—"
    }
    
    var isProductLoaded: Bool {
        dataManager.fullAccessProduct != nil
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)
                    
                    Image(systemName: "star.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.yellow)
                        .accessibilityLabel("Premium feature")
                    
                    Text("Unlock Full Access")
                        .font(.largeTitle.bold())
                    
                    Text("Get everything you need to pass")
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        FeatureRow(icon: "text.book.closed", text: "Hundreds of practice questions")
                        FeatureRow(icon: "doc.text", text: "Unlimited mock tests")
                        FeatureRow(icon: "exclamationmark.triangle", text: "Full hazard practice scenarios")
                        FeatureRow(icon: "chart.bar", text: "Detailed progress tracking")
                        FeatureRow(icon: "arrow.down.circle", text: "Practice works offline")
                    }
                    .padding()
                    .background(Color.accentColor.opacity(0.12))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        if isProductLoaded {
                            Text(displayPrice)
                                .font(.system(size: 48, weight: .bold))
                                .accessibilityLabel("Price: \(displayPrice)")
                        } else {
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding()
                                .accessibilityLabel("Loading price")
                        }
                        Text("One-time purchase • No subscription")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Purchase button
                    Button(action: purchaseFullAccess) {
                        HStack {
                            if purchaseState == .purchasing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Processing...")
                            } else if purchaseState == .checking {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Checking...")
                            } else if purchaseState == .pending {
                                Image(systemName: "clock.fill")
                                Text("Purchase Pending")
                            } else if !isProductLoaded {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Loading...")
                            } else {
                                Text("Unlock Now")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .background(purchaseState == .idle && isProductLoaded ? Color.accentColor : Color.gray)
                    .cornerRadius(12)
                    .disabled(purchaseState != .idle || !isProductLoaded)
                    .padding(.horizontal)
                    .accessibilityLabel("Purchase button")
                    
                    // Pending state message with Check Status
                    if purchaseState == .pending || purchaseState == .checking {
                        VStack(spacing: 12) {
                            if purchaseState == .checking {
                                Text("Checking purchase status...")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .multilineTextAlignment(.center)
                            } else {
                                Text("Your purchase is pending. Check your Apple ID settings or try again later.")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .multilineTextAlignment(.center)
                            }
                            
                            Button(action: refreshPendingPurchase) {
                                HStack {
                                    if purchaseState == .checking {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                                            .scaleEffect(0.7)
                                    }
                                    Image(systemName: "arrow.clockwise")
                                    Text("Check Status")
                                }
                                .font(.caption)
                                .foregroundColor(.accentColor)
                            }
                            .disabled(purchaseState == .checking)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Restore button
                    Button(action: restorePurchases) {
                        HStack {
                            if purchaseState == .restoring {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                                    .scaleEffect(0.8)
                                Text("Restoring...")
                            } else {
                                Text("Restore Purchase")
                            }
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .disabled(purchaseState != .idle)
                    
                    // Footer links
                    VStack(spacing: 8) {
                        HStack(spacing: 16) {
                            NavigationLink(destination: PrivacyPolicyView()) {
                                Text("Privacy")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("•")
                                .foregroundColor(.secondary)
                            
                            NavigationLink(destination: TermsView()) {
                                Text("Terms")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("•")
                                .foregroundColor(.secondary)
                            
                            Button("Support") {
                                let email = dataManager.supportEmailValue
                                if let url = URL(string: "mailto:\(email)") {
                                    openURL(url) { accepted in
                                        if !accepted {
                                            UIPasteboard.general.string = email
                                            messageTitle = "Email Copied"
                                            messageBody = "Support email: \(email)"
                                            showMessage = true
                                        }
                                    }
                                }
                            }
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 8)
                    
                    Spacer().frame(height: 20)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .disabled(purchaseState == .purchasing || purchaseState == .restoring)
                }
            }
            .alert(messageTitle, isPresented: $showMessage) {
                Button("OK", role: .cancel) {
                    if dataManager.hasUnlockedFullAccess {
                        dismiss()
                    }
                }
            } message: {
                Text(messageBody)
            }
            .task {
                if !isProductLoaded {
                    await dataManager.loadProducts()
                }
            }
            .onChange(of: dataManager.hasUnlockedFullAccess) { _, unlocked in
                if unlocked, purchaseState != .restoring {
                    purchaseState = .idle
                    dismiss()
                }
            }
        }
    }
    
    private func purchaseFullAccess() {
        guard purchaseState == .idle, isProductLoaded else { return }
        purchaseState = .purchasing
        
        Task {
            do {
                let result = try await dataManager.purchaseFullAccess()
                
                await MainActor.run {
                    switch result {
                    case .success:
                        purchaseState = .idle
                    case .cancelled:
                        purchaseState = .idle
                    case .pending:
                        purchaseState = .pending
                    case .failed:
                        purchaseState = .idle
                        messageTitle = "Purchase Failed"
                        messageBody = "Please try again."
                        showMessage = true
                    }
                }
            } catch {
                await MainActor.run {
                    purchaseState = .idle
                    messageTitle = "Purchase Failed"
                    messageBody = error.localizedDescription
                    showMessage = true
                }
            }
        }
    }
    
    private func restorePurchases() {
        guard purchaseState != .restoring else { return }
        purchaseState = .restoring
        
        Task {
            do {
                try await dataManager.restorePurchases()
                
                await MainActor.run {
                    purchaseState = .idle
                    if dataManager.hasUnlockedFullAccess {
                        messageTitle = "Restored"
                        messageBody = "Successfully restored your purchase."
                    } else {
                        messageTitle = "Nothing to Restore"
                        messageBody = "No previous purchases were found for this Apple ID."
                    }
                    showMessage = true
                }
            } catch {
                await MainActor.run {
                    purchaseState = .idle
                    messageTitle = "Restore Failed"
                    messageBody = "Unable to restore purchases. Please try again."
                    showMessage = true
                }
            }
        }
    }
    
    private func refreshPendingPurchase() {
        guard purchaseState == .pending else { return }
        purchaseState = .checking
        
        Task {
            await dataManager.checkPurchaseStatus()
            
            await MainActor.run {
                purchaseState = .idle
                if !dataManager.hasUnlockedFullAccess {
                    messageTitle = "Still Pending"
                    messageBody = "Your purchase is still being processed. Please check back in a few minutes."
                    showMessage = true
                }
            }
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            Text(text)
            Spacer()
        }
    }
}

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.title.bold())
                
                Text("Last updated: January 2026")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Divider()
                
                Group {
                    Text("Data Collection")
                        .font(.headline)
                        .padding(.top)
                    Text("This app does not collect, transmit, or share any personal data. All progress is stored locally on your device.")
                    
                    Text("No Account Required")
                        .font(.headline)
                        .padding(.top)
                    Text("No registration, email, or personal information is requested.")
                    
                    Text("In-App Purchase")
                        .font(.headline)
                        .padding(.top)
                    Text("Purchase transactions are processed by Apple. We do not store payment information.")
                    
                    Text("Local Storage")
                        .font(.headline)
                        .padding(.top)
                    Text("Your practice progress, mock test results, and settings are stored locally on your device using iOS's secure storage. This data never leaves your device.")
                    
                    Text("Third-Party Services")
                        .font(.headline)
                        .padding(.top)
                    Text("This app uses Apple's StoreKit framework for in-app purchases. No other third-party services or analytics are used.")
                    
                    Text("Changes to Privacy Policy")
                        .font(.headline)
                        .padding(.top)
                    Text("We may update this privacy policy from time to time. Any changes will be reflected in the app.")
                }
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Terms View

struct TermsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Terms of Use")
                    .font(.title.bold())
                
                Text("Last updated: January 2026")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Divider()
                
                Group {
                    Text("Practice Tool Only")
                        .font(.headline)
                        .padding(.top)
                    Text("This app is a practice and revision tool. It is NOT affiliated with, endorsed by, or connected to the Driver and Vehicle Standards Agency (DVSA) or the UK Government.")
                    
                    Text("No Guarantees")
                        .font(.headline)
                        .padding(.top)
                    Text("We do not guarantee that using this app will result in passing your theory test. The official test must be booked through GOV.UK.")
                    
                    Text("Content")
                        .font(.headline)
                        .padding(.top)
                    Text("Questions and hazard scenarios are created for educational purposes and may not exactly match those in the official test.")
                    
                    Text("Accuracy")
                        .font(.headline)
                        .padding(.top)
                    Text("While we strive for accuracy, we cannot guarantee that all content is error-free. Please report any issues using the in-app report feature.")
                    
                    Text("In-App Purchase")
                        .font(.headline)
                        .padding(.top)
                    Text("The one-time purchase unlocks all features. Purchases are non-refundable except as required by law.")
                    
                    Text("Changes to Terms")
                        .font(.headline)
                        .padding(.top)
                    Text("We may update these terms from time to time. Continued use of the app constitutes acceptance of any changes.")
                }
            }
            .padding()
        }
        .navigationTitle("Terms of Use")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - About View

struct AboutView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.openURL) var openURL
    @State private var showCopiedAlert = false
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .center, spacing: 12) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.accentColor)
                    
                    Text("UK Driving Theory Test Practice")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    
                    Text("Version \(appVersion)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            
            Section(header: Text("Important Notice")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Practice Tool Only")
                                .font(.headline)
                            Text("This app is not affiliated with, endorsed by, or connected to the Driver and Vehicle Standards Agency (DVSA) or the UK Government.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    Text("Questions and hazard scenarios are created for educational purposes and may not exactly match those in the official test.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("We do not guarantee that using this app will result in passing your theory test.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Support")) {
                Button(action: contactSupport) {
                    HStack {
                        Label("Email Support", systemImage: "envelope")
                        Spacer()
                        Text(dataManager.supportEmailValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let url = URL(string: "https://www.gov.uk/book-theory-test") {
                    Link(destination: url) {
                        HStack {
                            Label("Book Official Test", systemImage: "link")
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Section(header: Text("Legal")) {
                NavigationLink(destination: PrivacyPolicyView()) {
                    Text("Privacy Policy")
                }
                
                NavigationLink(destination: TermsView()) {
                    Text("Terms of Use")
                }
            }
            
            Section {
                Text("Made with ❤️ for learner drivers")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
        .navigationTitle("About")
        .alert("Email Copied", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Support email copied to clipboard: \(dataManager.supportEmailValue)")
        }
    }
    
    private func contactSupport() {
        let email = dataManager.supportEmailValue
        if let url = URL(string: "mailto:\(email)") {
            openURL(url) { accepted in
                if !accepted {
                    UIPasteboard.general.string = email
                    showCopiedAlert = true
                }
            }
        }
    }
}

// ============================================================================
// INTEGRATION INSTRUCTIONS
// ============================================================================

/*
 
 1. Replace any existing PaywallView with this single clean version
 2. Replace any existing FeatureRow with this single version
 3. Add PrivacyPolicyView, TermsView, and AboutView to your project
 4. In MoreView, add navigation link to AboutView:
 
    NavigationLink(destination: AboutView()) {
        Label("About", systemImage: "info.circle")
    }
 
 5. Ensure DataManager has:
    - @MainActor decorator
    - func restorePurchases() async throws
    - Guards in recordAnswer and recordHazardAttempt
 
 6. App Store Connect setup:
    - Upload Privacy Policy URL (can be in-app view)
    - Fill App Privacy questionnaire
    - Add support email
    - Create IAP: full_access_299
 
 */
