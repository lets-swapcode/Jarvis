import Foundation
import GoogleSignIn
import GoogleAPIClientForREST_Gmail

@MainActor
class GoogleAuthViewModel: ObservableObject {
    @Published var isSignedIn = false
    @Published var error: Error?
    
    private let authService = GoogleAuthService.shared
    private let emailService = EmailService.shared
    
    func checkAuthStatus() async {
        if let currentUser = GIDSignIn.sharedInstance.currentUser {
            // Refresh token if needed
            do {
                let user = try await currentUser.refreshTokensIfNeeded()
                emailService.configureService(with: user)
                isSignedIn = true
            } catch {
                self.error = error
                isSignedIn = false
            }
        } else {
            isSignedIn = false
        }
    }
    
    func signIn() async {
        do {
            let user = try await authService.signIn()
            emailService.configureService(with: user)
            isSignedIn = true
        } catch {
            self.error = error
            isSignedIn = false
        }
    }
    
    func signOut() async {
        authService.signOut()
        isSignedIn = false
    }
    
    // Handle token refresh
    private func refreshTokenIfNeeded() async throws -> GIDGoogleUser {
        guard let currentUser = GIDSignIn.sharedInstance.currentUser else {
            throw NSError(domain: "GoogleAuthViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user found"])
        }
        
        return try await currentUser.refreshTokensIfNeeded()
    }
} 