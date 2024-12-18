import SwiftUI

struct EmailListView: View {
    @ObservedObject var emailViewModel: EmailManagerViewModel
    
    var body: some View {
        List {
            ForEach(emailViewModel.categorizedEmails[emailViewModel.selectedCategory ?? .other] ?? [], id: \.id) { email in
                EmailRowView(email: email)
                    .swipeActions(allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task {
                                await emailViewModel.deleteEmails(from: email.sender)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
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
        .refreshable {
            await emailViewModel.fetchEmails()
        }
    }
}

struct EmailRowView: View {
    let email: Email
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(email.sender)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Text(email.formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(email.subject)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            
            HStack {
                Image(systemName: email.category.icon)
                    .foregroundStyle(.blue)
                Text(email.category.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(email.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .opacity(email.isRead ? 0.8 : 1)
    }
} 