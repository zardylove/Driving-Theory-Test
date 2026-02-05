import SwiftUI
import StoreKit
import UIKit

// MARK: - Paywall View

struct PaywallView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var purchaseState: PurchaseState = .idle
    @State private var showMessage = false
    @State private var messageTitle = ""
    @State private var messageBody = ""

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case restoring
        case pending
        case checking
    }

    private var displayPrice: String {
        dataManager.fullAccessProduct?.displayPrice ?? "—"
    }

    private var isProductLoaded: Bool {
        dataManager.fullAccessProduct != nil
    }

    private var isBusy: Bool {
        purchaseState == .purchasing || purchaseState == .restoring || purchaseState == .checking
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Spacer().frame(height: 8)

                    Image(systemName: "star.fill")
                        .font(.system(size: 76))
                        .foregroundColor(.yellow)
                        .accessibilityLabel("Premium")

                    Text("Unlock Full Access")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)

                    Text("Get everything you need to pass")
                        .foregroundColor(.secondary)

                    featureList

                    priceBlock

                    purchaseButton

                    if purchaseState == .pending || purchaseState == .checking {
                        pendingStateBlock
                    }

                    restoreButton

                    footerLinks

                    Spacer().frame(height: 10)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .disabled(isBusy)
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
                if unlocked {
                    purchaseState = .idle
                    dismiss()
                }
            }
        }
    }

    // MARK: - UI Pieces

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 12) {
            FeatureRow(icon: "text.book.closed", text: "Hundreds of practice questions")
            FeatureRow(icon: "doc.text", text: "Unlimited mock tests")
            FeatureRow(icon: "chart.bar", text: "Detailed progress tracking")
            FeatureRow(icon: "arrow.down.circle", text: "Works offline")
        }
        .padding()
        .background(Color.accentColor.opacity(0.12))
        .cornerRadius(12)
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Premium features list")
    }

    private var priceBlock: some View {
        VStack(spacing: 8) {
            if isProductLoaded {
                Text(displayPrice)
                    .font(.system(size: 46, weight: .bold))
                    .accessibilityLabel("Price \(displayPrice)")
            } else {
                ProgressView()
                    .scaleEffect(1.2)
                    .padding()
                    .accessibilityLabel("Loading price")
            }

            Text("One-time purchase • No subscription")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var purchaseButton: some View {
        Button(action: purchaseFullAccess) {
            HStack(spacing: 10) {
                switch purchaseState {
                case .purchasing:
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                    Text("Processing…")

                case .checking:
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                    Text("Checking…")

                case .pending:
                    Image(systemName: "clock.fill")
                    Text("Purchase Pending")

                default:
                    if !isProductLoaded {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                        Text("Loading…")
                    } else {
                        Text("Unlock Now")
                    }
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
        .accessibilityLabel("Unlock full access")
        .accessibilityHint("Purchases full access for this app")
    }

    private var pendingStateBlock: some View {
        VStack(spacing: 12) {
            if purchaseState == .checking {
                Text("Checking purchase status…")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.center)
            } else {
                Text("Your purchase is pending. Please check your Apple ID settings or try again later.")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            }

            Button(action: refreshPendingPurchase) {
                HStack {
                    if purchaseState == .checking {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.accentColor)
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

    private var restoreButton: some View {
        Button(action: restorePurchases) {
            HStack(spacing: 8) {
                if purchaseState == .restoring {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.accentColor)
                        .scaleEffect(0.8)
                    Text("Restoring…")
                } else {
                    Text("Restore Purchase")
                }
            }
        }
        .font(.caption)
        .foregroundColor(.accentColor)
        .disabled(purchaseState != .idle)
        .accessibilityLabel("Restore purchase")
        .accessibilityHint("Restores your previous purchase if you already bought full access")
    }

    private var footerLinks: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                NavigationLink(destination: PrivacyPolicyView()) {
                    Text("Privacy")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text("•").foregroundColor(.secondary)

                NavigationLink(destination: TermsView()) {
                    Text("Terms")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text("•").foregroundColor(.secondary)

                Button("Support") {
                    contactSupport()
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func purchaseFullAccess() {
        guard purchaseState == .idle, isProductLoaded else { return }
        purchaseState = .purchasing

        Task {
            do {
                let result = try await dataManager.purchaseFullAccess()

                switch result {
                case .success, .cancelled:
                    purchaseState = .idle

                case .pending:
                    purchaseState = .pending

                case .failed:
                    purchaseState = .idle
                    messageTitle = "Purchase Failed"
                    messageBody = "Please try again."
                    showMessage = true
                }
            } catch {
                purchaseState = .idle
                messageTitle = "Purchase Failed"
                messageBody = error.localizedDescription
                showMessage = true
            }
        }
    }

    private func restorePurchases() {
        guard purchaseState == .idle else { return }
        purchaseState = .restoring

        Task {
            do {
                try await dataManager.restorePurchases()

                purchaseState = .idle
                if dataManager.hasUnlockedFullAccess {
                    messageTitle = "Restored"
                    messageBody = "Successfully restored your purchase."
                } else {
                    messageTitle = "Nothing to Restore"
                    messageBody = "No previous purchases were found for this Apple ID."
                }
                showMessage = true
            } catch {
                purchaseState = .idle
                messageTitle = "Restore Failed"
                messageBody = "Unable to restore purchases. Please try again."
                showMessage = true
            }
        }
    }

    private func refreshPendingPurchase() {
        guard purchaseState == .pending else { return }
        purchaseState = .checking

        Task {
            await dataManager.checkPurchaseStatus()

            purchaseState = .idle
            if !dataManager.hasUnlockedFullAccess {
                messageTitle = "Still Pending"
                messageBody = "Your purchase is still being processed. Please check back later."
                showMessage = true
            }
        }
    }

    private func contactSupport() {
        let email = dataManager.supportEmailValue

        if let url = URL(string: "mailto:\(email)") {
            openURL(url)
        } else {
            UIPasteboard.general.string = email
            messageTitle = "Email Copied"
            messageBody = "Support email: \(email)"
            showMessage = true
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
