import Foundation
import SwiftUI

struct Email: Identifiable {
    let id: String
    let sender: String
    let subject: String
    let timestamp: Date
    let size: Int // in bytes
    let isRead: Bool
    let category: EmailCategory
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

enum EmailCategory: String, CaseIterable {
    case newsletters
    case social
    case promotions
    case personal
    case other
    
    var icon: String {
        switch self {
        case .newsletters: return "newspaper"
        case .social: return "person.2"
        case .promotions: return "tag"
        case .personal: return "envelope"
        case .other: return "tray"
        }
    }
    
    var color: Color {
        switch self {
        case .newsletters: return .blue
        case .social: return .green
        case .promotions: return .orange
        case .personal: return .purple
        case .other: return .gray
        }
    }
} 