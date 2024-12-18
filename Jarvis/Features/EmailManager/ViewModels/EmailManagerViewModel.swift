import Foundation
import Combine
import GoogleSignIn

@MainActor
class EmailManagerViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var emails: [Email] = []
    @Published var selectedCategory: EmailCategory?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var errorMessage: String?
    @Published var senderStats: [String: Int] = [:]
    @Published var unreadCount: Int = 0
    @Published var totalStorageUsed: String = "0 KB"
    
    // MARK: - Pagination Properties
    @Published var hasMorePages = true
    @Published var isLoadingNextPage = false
    private var currentPageToken: String?
    
    // MARK: - Services
    private let emailService = EmailService.shared
    
    // MARK: - Computed Properties
    var categorizedEmails: [EmailCategory: [Email]] {
        Dictionary(grouping: emails) { $0.category }
    }
    
    // MARK: - Email Fetching
    /// Fetches the first page of emails, clearing existing data
    func fetchEmails() async {
        isLoading = true
        errorMessage = nil
        // Reset pagination state
        currentPageToken = nil
        emails = []
        
        do {
            let result = try await emailService.fetchEmailPage()
            emails = result.emails
            currentPageToken = result.nextPageToken
            hasMorePages = result.nextPageToken != nil
            updateStats()
        } catch {
            self.error = error
            self.errorMessage = "Failed to fetch emails: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    /// Fetches the next page of emails if available
    func fetchNextPage() async {
        guard hasMorePages && !isLoadingNextPage else { return }
        
        isLoadingNextPage = true
        errorMessage = nil
        
        do {
            let result = try await emailService.fetchEmailPage(pageToken: currentPageToken)
            emails.append(contentsOf: result.emails)
            currentPageToken = result.nextPageToken
            hasMorePages = result.nextPageToken != nil
            updateStats()
        } catch {
            self.error = error
            self.errorMessage = "Failed to fetch more emails: \(error.localizedDescription)"
        }
        isLoadingNextPage = false
    }
    
    // MARK: - Email Management
    /// Attempts to unsubscribe from a sender's emails
    func unsubscribe(from sender: String) async {
        isLoading = true
        errorMessage = nil
        
        if let firstEmail = emails.first(where: { $0.sender == sender }) {
            do {
                if let unsubscribeLink = try await emailService.unsubscribe(email: firstEmail) {
                    // Return the unsubscribe link that can be opened in a browser or mail app
                    // You can handle this in the UI layer
                    print("Unsubscribe link found: \(unsubscribeLink)")
                } else {
                    self.errorMessage = "No unsubscribe link found for this sender"
                }
            } catch {
                self.error = error
                self.errorMessage = "Failed to unsubscribe: \(error.localizedDescription)"
            }
        } else {
            self.errorMessage = "No emails found from this sender"
        }
        
        isLoading = false
    }
    
    /// Marks all emails from a specific sender as read
    func markAsRead(from sender: String) async {
        isLoading = true
        errorMessage = nil
        
        let emailsToMark = emails.filter { $0.sender == sender && !$0.isRead }
        let ids = emailsToMark.map { $0.id }
        
        if !ids.isEmpty {
            do {
                try await emailService.markEmailsAsRead(ids: ids)
                // Update local state
                for id in ids {
                    if let index = emails.firstIndex(where: { $0.id == id }) {
                        emails[index] = Email(
                            id: emails[index].id,
                            sender: emails[index].sender,
                            subject: emails[index].subject,
                            timestamp: emails[index].timestamp,
                            size: emails[index].size,
                            isRead: true,
                            category: emails[index].category
                        )
                    }
                }
                updateStats()
            } catch {
                self.error = error
                self.errorMessage = "Failed to mark emails as read: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    func deleteEmails(from sender: String) async {
        isLoading = true
        errorMessage = nil
        let emailsToDelete = emails.filter { $0.sender == sender }
        let ids = emailsToDelete.map { $0.id }
        
        do {
            try await emailService.deleteEmails(ids: ids)
            // Remove deleted emails from local array using email IDs
            let idsToDelete = Set(ids) // Create a Set for faster lookup
            emails.removeAll { email in
                idsToDelete.contains(email.id)
            }
            updateStats()
        } catch {
            self.error = error
            self.errorMessage = "Failed to delete emails: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    // MARK: - Helper Methods
    private func updateStats() {
        // Update sender statistics
        senderStats = Dictionary(grouping: emails, by: { $0.sender })
            .mapValues { $0.count }
        
        // Update unread count
        unreadCount = emails.filter { !$0.isRead }.count
        
        // Update storage used
        let totalBytes = emails.reduce(0) { $0 + $1.size }
        totalStorageUsed = ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)
    }
    
    // MARK: - State Management
    func reset() {
        emails = []
        selectedCategory = nil
        error = nil
        errorMessage = nil
        senderStats = [:]
        unreadCount = 0
        totalStorageUsed = "0 KB"
        currentPageToken = nil
        hasMorePages = true
        isLoadingNextPage = false
    }
    
    // MARK: - Filtering
    func emailsForCategory(_ category: EmailCategory) -> [Email] {
        emails.filter { $0.category == category }
    }
    
    func unreadEmails() -> [Email] {
        emails.filter { !$0.isRead }
    }
}
