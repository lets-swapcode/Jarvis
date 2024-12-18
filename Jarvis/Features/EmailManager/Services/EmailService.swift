import Foundation
import GoogleSignIn
import GoogleAPIClientForREST_Gmail

// MARK: - EmailService
/// A service class that handles all Gmail API interactions with optimized performance and minimal data fetching
class EmailService {
    // MARK: - Properties
    static let shared = EmailService()
    private let gmailService = GTLRGmailService()
    private let pageSize = 50 // Smaller page size for quick loading
    
    // MARK: - Initialization
    private init() {
        gmailService.shouldFetchNextPages = false // We'll handle pagination manually
        gmailService.isRetryEnabled = true
    }
    
    // MARK: - Service Configuration
    func configureService(with user: GIDGoogleUser) {
        gmailService.authorizer = user.fetcherAuthorizer
    }
    
    // MARK: - Email Fetching
    /// Fetches a single page of emails with size information
    /// - Parameter pageToken: Optional token for the next page
    /// - Returns: Tuple containing array of emails and next page token
    func fetchEmailPage(pageToken: String? = nil) async throws -> (emails: [Email], nextPageToken: String?) {
        let query = GTLRGmailQuery_UsersMessagesList.query(withUserId: "me")
        query.maxResults = UInt(pageSize)
        query.pageToken = pageToken
        query.labelIds = ["INBOX"]
        query.includeSpamTrash = false
        
        // Get list of message IDs and metadata in one call
        let (messages, nextToken) = try await fetchMessagesList(query)
        let emails = try await fetchEmailMetadata(messages)
        
        return (emails.sorted { $0.size > $1.size }, nextToken)
    }
    
    // MARK: - Private Helper Methods
    /// Fetches a list of message IDs and basic metadata
    private func fetchMessagesList(_ query: GTLRGmailQuery_UsersMessagesList) async throws -> ([GTLRGmail_Message], String?) {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<([GTLRGmail_Message], String?), Error>) in
            gmailService.executeQuery(query) { (ticket, response, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let messageList = response as? GTLRGmail_ListMessagesResponse else {
                    continuation.resume(throwing: NSError(domain: "EmailService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"]))
                    return
                }
                
                continuation.resume(returning: (messageList.messages ?? [], messageList.nextPageToken))
            }
        }
    }
    
    /// Fetches email metadata in optimized batches
    private func fetchEmailMetadata(_ messages: [GTLRGmail_Message]) async throws -> [Email] {
        try await withThrowingTaskGroup(of: Email?.self) { group in
            var emails: [Email] = []
            emails.reserveCapacity(messages.count)
            
            // Process in smaller batches to avoid overwhelming the API
            let batchSize = 10
            for batch in stride(from: 0, to: messages.count, by: batchSize) {
                let end = min(batch + batchSize, messages.count)
                let messageBatch = Array(messages[batch..<end])
                
                for message in messageBatch {
                    group.addTask {
                        guard let messageId = message.identifier else { return nil }
                        return try await self.fetchMinimalEmailDetails(messageId: messageId)
                    }
                }
                
                // Wait for each batch to complete before starting the next
                for try await email in group {
                    if let email = email {
                        emails.append(email)
                    }
                }
            }
            
            return emails
        }
    }
    
    /// Fetches minimal details for a single email
    private func fetchMinimalEmailDetails(messageId: String) async throws -> Email? {
        let query = GTLRGmailQuery_UsersMessagesGet.query(withUserId: "me", identifier: messageId)
        query.format = "metadata"
        // Only fetch essential headers
        query.metadataHeaders = ["From", "Subject"]
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Email?, Error>) in
            gmailService.executeQuery(query) { (ticket, response, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let message = response as? GTLRGmail_Message else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let email = self.parseMinimalEmail(message)
                continuation.resume(returning: email)
            }
        }
    }
    
    /// Parses raw message data into Email model
    private func parseMinimalEmail(_ message: GTLRGmail_Message) -> Email {
        let headers = message.payload?.headers ?? []
        
        let subject = headers.first(where: { $0.name == "Subject" })?.value ?? "No Subject"
        let sender = headers.first(where: { $0.name == "From" })?.value ?? "Unknown Sender"
        let size = Int(message.sizeEstimate?.intValue ?? 0)
        
        return Email(
            id: message.identifier ?? UUID().uuidString,
            sender: sender,
            subject: subject,
            timestamp: Date(timeIntervalSince1970: TimeInterval(message.internalDate?.int64Value ?? 0) / 1000),
            size: size,
            isRead: !(message.labelIds?.contains("UNREAD") ?? false),
            category: determineEmailCategory(message)
        )
    }
    
    /// Determines email category based on Gmail labels
    private func determineEmailCategory(_ message: GTLRGmail_Message) -> EmailCategory {
        let labels = message.labelIds ?? []
        
        if labels.contains("CATEGORY_SOCIAL") {
            return .social
        } else if labels.contains("CATEGORY_PROMOTIONS") {
            return .promotions
        } else if labels.contains("CATEGORY_UPDATES") || labels.contains("CATEGORY_FORUMS") {
            return .newsletters
        } else if labels.contains("CATEGORY_PERSONAL") {
            return .personal
        }
        
        return .other
    }
    
    // MARK: - Email Management
    /// Deletes multiple emails in batch or single email
    func deleteEmails(ids: [String]) async throws {
        if ids.isEmpty { return }
        
        if ids.count > 1 {
            let batchDeleteRequest = GTLRGmail_BatchDeleteMessagesRequest()
            batchDeleteRequest.ids = ids
            
            let query = GTLRGmailQuery_UsersMessagesBatchDelete.query(withObject: batchDeleteRequest, userId: "me")
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                gmailService.executeQuery(query) { (ticket, response, error) in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
        } else if let id = ids.first {
            let query = GTLRGmailQuery_UsersMessagesDelete.query(withUserId: "me", identifier: id)
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                gmailService.executeQuery(query) { (ticket, response, error) in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
        }
    }
    
    /// Attempts to unsubscribe from an email sender using List-Unsubscribe header
    func unsubscribe(email: Email) async throws -> String? {
        let query = GTLRGmailQuery_UsersMessagesGet.query(withUserId: "me", identifier: email.id)
        query.format = "metadata"
        query.metadataHeaders = ["List-Unsubscribe"]
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String?, Error>) in
            gmailService.executeQuery(query) { (ticket, response, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let message = response as? GTLRGmail_Message,
                      let headers = message.payload?.headers,
                      let unsubscribeHeader = headers.first(where: { $0.name == "List-Unsubscribe" })?.value,
                      let unsubscribeLink = self.extractUnsubscribeLink(from: unsubscribeHeader) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                continuation.resume(returning: unsubscribeLink)
            }
        }
    }
    
    /// Marks multiple emails as read
    func markEmailsAsRead(ids: [String]) async throws {
        if ids.isEmpty { return }
        
        // Create modify request
        let modifyRequest = GTLRGmail_ModifyMessageRequest()
        modifyRequest.removeLabelIds = ["UNREAD"]
        
        // Process in batches to avoid overwhelming the API
        let batchSize = 50
        for batch in stride(from: 0, to: ids.count, by: batchSize) {
            let end = min(batch + batchSize, ids.count)
            let batchIds = Array(ids[batch..<end])
            
            try await withThrowingTaskGroup(of: Void.self) { group in
                for id in batchIds {
                    group.addTask {
                        try await self.modifyEmail(id: id, request: modifyRequest)
                    }
                }
                
                // Wait for all modifications to complete
                try await group.waitForAll()
            }
        }
    }
    
    // MARK: - Private Helper Methods
    private func modifyEmail(id: String, request: GTLRGmail_ModifyMessageRequest) async throws {
        let query = GTLRGmailQuery_UsersMessagesModify.query(withObject: request, userId: "me", identifier: id)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            gmailService.executeQuery(query) { (ticket, response, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    private func extractUnsubscribeLink(from header: String) -> String? {
        // First try to find a URL
        let urlPattern = "https?://[^\\s,<>]+"
        if let url = header.range(of: urlPattern, options: .regularExpression).map({ String(header[$0]) }) {
            return url
        }
        
        // Then try to find a mailto link
        let mailtoPattern = "mailto:[^\\s,<>]+"
        if let mailto = header.range(of: mailtoPattern, options: .regularExpression).map({ String(header[$0]) }) {
            return mailto
        }
        
        return nil
    }
} 
