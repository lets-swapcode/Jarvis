# Jarvis - Email Cleanup Assistant

A SwiftUI-based iOS application that helps users manage and clean up their Gmail inbox efficiently. The app focuses on identifying and managing large emails to free up space.

## Features

- 📧 Smart email categorization (Social, Promotions, Newsletters, Personal)
- 📊 Storage usage visualization
- 🗑️ Batch email deletion
- 📱 Modern SwiftUI interface
- 🔄 Efficient pagination for email loading
- 📦 Optimized for large inboxes

## Requirements

- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+
- Google Cloud Platform account
- Gmail API enabled
- Valid OAuth 2.0 Client ID

## Setup

1. **Google Cloud Platform Setup**
   - Create a new project in Google Cloud Console
   - Enable Gmail API
   - Configure OAuth consent screen
   - Create OAuth 2.0 Client ID
   - Add required scopes:
     - `https://mail.google.com/`
     - `https://www.googleapis.com/auth/gmail.modify`
     - `https://www.googleapis.com/auth/gmail.readonly`
     - `https://www.googleapis.com/auth/gmail.labels`
     - `https://www.googleapis.com/auth/gmail.metadata`

2. **Project Configuration**
   - Clone the repository
   - Open `Info.plist`
   - Update `GIDClientID` with your OAuth Client ID
   - Update URL schemes with your reversed client ID

3. **Dependencies**
   ```swift
   dependencies: [
       .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "7.0.0"),
       .package(url: "https://github.com/google/google-api-objectivec-client-for-rest", from: "3.0.0")
   ]
   ```

## Architecture

The project follows the MVVM (Model-View-ViewModel) architecture pattern:

### Models
- `Email`: Core data model representing email information
- `EmailCategory`: Email classification enum

### Views
- `ContentView`: Main app view with authentication and dashboard
- `EmailManagerView`: Email list and management interface
- `CleanupView`: Bulk email cleanup interface

### ViewModels
- `GoogleAuthViewModel`: Handles authentication state
- `EmailManagerViewModel`: Manages email data and operations

### Services
- `GoogleAuthService`: Manages Google Sign-In
- `EmailService`: Handles Gmail API interactions

## Key Components

### EmailService
The core service handling Gmail API interactions with optimized features:
- Paginated email fetching
- Minimal data retrieval for better performance
- Batch processing for API calls
- Efficient memory management

### Authentication
Uses Google Sign-In for iOS with:
- Secure OAuth 2.0 flow
- Token management
- Automatic token refresh

## Performance Optimizations

1. **Pagination**
   - Small page size (50 emails per page)
   - On-demand loading
   - Memory-efficient processing

2. **Minimal Data Fetching**
   - Only essential metadata retrieval
   - Batch processing in groups of 10
   - Optimized network calls

3. **Memory Management**
   - Capacity reservation for collections
   - Efficient batch processing
   - Resource cleanup

## Usage Examples

```swift
// Initialize email manager
let emailManager = EmailManagerViewModel()

// Fetch first page of emails
await emailManager.fetchNextPage()

// Delete emails
await emailManager.deleteEmails(from: "sender@example.com")
```

## Best Practices

1. **Error Handling**
   - Comprehensive error messages
   - User-friendly error displays
   - Graceful fallbacks

2. **UI/UX**
   - Loading indicators
   - Pull-to-refresh
   - Smooth animations
   - Clear feedback

3. **Security**
   - Secure token storage
   - OAuth best practices
   - Data privacy

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Google Gmail API
- GoogleSignIn-iOS
- SwiftUI framework 