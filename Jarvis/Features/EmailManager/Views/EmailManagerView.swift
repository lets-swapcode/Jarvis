import SwiftUI

enum EmailFilter {
    case all
    case unread
    case category(EmailCategory)
}

struct EmailManagerView: View {
    @ObservedObject var emailViewModel: EmailManagerViewModel
    @Environment(\.dismiss) private var dismiss
    let filter: EmailFilter
    
    var filteredEmails: [Email] {
        switch filter {
        case .all:
            return emailViewModel.emails
        case .unread:
            return emailViewModel.emails.filter { !$0.isRead }
        case .category(let category):
            return emailViewModel.categorizedEmails[category] ?? []
        }
    }
    
    var navigationTitle: String {
        switch filter {
        case .all:
            return "All Emails"
        case .unread:
            return "Unread"
        case .category(let category):
            return category.rawValue.capitalized
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Storage usage indicator
            storageIndicator
            
            // Email list
            List {
                ForEach(filteredEmails) { email in
                    EmailRowView(email: email)
                        .swipeActions(allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    await emailViewModel.deleteEmails(from: email.sender)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            
                            if !email.isRead {
                                Button {
                                    Task {
                                        await emailViewModel.markAsRead(from: email.sender)
                                    }
                                } label: {
                                    Label("Mark Read", systemImage: "envelope.open")
                                }
                                .tint(.blue)
                            }
                            
                            Button {
                                Task {
                                    await emailViewModel.unsubscribe(from: email.sender)
                                }
                            } label: {
                                Label("Unsubscribe", systemImage: "envelope.badge.slash")
                            }
                            .tint(.orange)
                        }
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if emailViewModel.isLoading {
                LoadingView()
            } else if filteredEmails.isEmpty {
                emptyStateView
            }
        }
        .refreshable {
            await emailViewModel.fetchEmails()
        }
        .alert("Error", isPresented: .constant(emailViewModel.errorMessage != nil)) {
            Button("OK") { emailViewModel.errorMessage = nil }
        } message: {
            if let errorMessage = emailViewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    private var storageIndicator: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Storage Used")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(emailViewModel.totalStorageUsed)
                    .font(.subheadline.bold())
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(.gray.opacity(0.2))
                    
                    Rectangle()
                        .fill(.blue)
                        .frame(width: geometry.size.width * 0.7)
                }
            }
            .frame(height: 4)
            .clipShape(Capsule())
        }
        .padding()
        .background(.background)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No Emails Found")
                .font(.title3.bold())
            
            Text("Pull to refresh or try a different filter")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
