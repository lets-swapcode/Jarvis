import SwiftUI

struct CleanupView: View {
    @ObservedObject var emailViewModel: EmailManagerViewModel
    @State private var showingConfirmation = false
    @State private var selectedAction: EmailAction?
    @State private var selectedSender: String?
    @State private var showingSenderEmails = false
    
    enum EmailAction {
        case delete, unsubscribe, markRead
    }
    
    var body: some View {
        List {
            ForEach(emailViewModel.senderStats.sorted(by: { $0.value > $1.value }), id: \.key) { sender, count in
                SenderRowView(
                    sender: sender,
                    count: count,
                    isSelected: selectedSender == sender
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedSender = sender
                    showingSenderEmails = true
                }
            }
        }
        .navigationTitle("Clean Up")
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            if emailViewModel.isLoading {
                LoadingView()
            } else if emailViewModel.senderStats.isEmpty {
                emptyStateView
            }
        }
        .sheet(isPresented: $showingSenderEmails) {
            if let sender = selectedSender {
                NavigationStack {
                    SenderEmailsView(
                        emailViewModel: emailViewModel,
                        sender: sender,
                        showingSheet: $showingSenderEmails
                    )
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "envelope.badge.person.crop")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No Emails Found")
                .font(.title3.bold())
            
            Text("Pull to refresh to load your emails")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct SenderRowView: View {
    let sender: String
    let count: Int
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 48, height: 48)
                .overlay {
                    Text(sender.prefix(1).uppercased())
                        .font(.title3.bold())
                        .foregroundStyle(.blue)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(sender)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("\(count) emails")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct SenderEmailsView: View {
    @ObservedObject var emailViewModel: EmailManagerViewModel
    let sender: String
    @Binding var showingSheet: Bool
    @State private var showingConfirmation = false
    @State private var selectedAction: CleanupView.EmailAction?
    
    var senderEmails: [Email] {
        emailViewModel.emails.filter { $0.sender == sender }
    }
    
    var body: some View {
        List(senderEmails) { email in
            EmailRowView(email: email)
        }
        .listStyle(.plain)
        .navigationTitle(sender)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    showingSheet = false
                }
            }
            
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    selectedAction = .markRead
                    showingConfirmation = true
                } label: {
                    Label("Mark All Read", systemImage: "envelope.open")
                }
                
                Spacer()
                
                Button {
                    selectedAction = .unsubscribe
                    showingConfirmation = true
                } label: {
                    Label("Unsubscribe", systemImage: "envelope.badge.slash")
                }
                .tint(.orange)
                
                Spacer()
                
                Button(role: .destructive) {
                    selectedAction = .delete
                    showingConfirmation = true
                } label: {
                    Label("Delete All", systemImage: "trash")
                }
            }
        }
        .alert("Confirm Action", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button(role: .destructive) {
                Task {
                    await performAction()
                    showingSheet = false
                }
            } label: {
                Text(confirmationButtonText)
            }
        } message: {
            Text(confirmationMessage)
        }
    }
    
    private func performAction() async {
        switch selectedAction {
        case .delete:
            await emailViewModel.deleteEmails(from: sender)
        case .unsubscribe:
            await emailViewModel.unsubscribe(from: sender)
        case .markRead:
            await emailViewModel.markAsRead(from: sender)
        case .none:
            break
        }
    }
    
    private var confirmationButtonText: String {
        switch selectedAction {
        case .delete:
            return "Delete"
        case .unsubscribe:
            return "Unsubscribe"
        case .markRead:
            return "Mark Read"
        case .none:
            return ""
        }
    }
    
    private var confirmationMessage: String {
        let count = senderEmails.count
        switch selectedAction {
        case .delete:
            return "Are you sure you want to delete all \(count) emails from \(sender)?"
        case .unsubscribe:
            return "Are you sure you want to unsubscribe from \(sender)?"
        case .markRead:
            return "Mark all \(count) emails from \(sender) as read?"
        case .none:
            return ""
        }
    }
} 