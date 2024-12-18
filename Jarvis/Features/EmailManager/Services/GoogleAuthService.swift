import GoogleSignIn
import GoogleAPIClientForRESTCore
import GoogleAPIClientForREST_Gmail
import UIKit

class GoogleAuthService {
    static let shared = GoogleAuthService()
    private let clientID = "688573041081-4bfjbsgdb27e4o5164ejgagc8c2k6in2.apps.googleusercontent.com"
    private let scopes = [
        "https://mail.google.com/",                    // Full access to Gmail account
        "https://www.googleapis.com/auth/gmail.modify", // All read/write operations except immediate and permanent deletion
        "https://www.googleapis.com/auth/gmail.readonly", // Read-only access
        "https://www.googleapis.com/auth/gmail.labels", // Create, read, update, and delete labels only
        "https://www.googleapis.com/auth/gmail.metadata" // Read metadata including headers but not email content
    ]
    
    func signIn() async throws -> GIDGoogleUser {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            throw NSError(domain: "GoogleAuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No root view controller found"])
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        
        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController, hint: nil, additionalScopes: scopes) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let user = result?.user else {
                    continuation.resume(throwing: NSError(domain: "GoogleAuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user found"]))
                    return
                }
                
                continuation.resume(returning: user)
            }
        }
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }
}
