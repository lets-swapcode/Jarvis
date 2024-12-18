//
//  ContentView.swift
//  Jarvis
//
//  Created by Harsh Surati on 17/12/24.
//

import SwiftUI
import GoogleSignIn

struct ContentView: View {
    @StateObject private var authViewModel = GoogleAuthViewModel()
    @StateObject private var emailViewModel = EmailManagerViewModel()
    @State private var isSpinning = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Image(systemName: "sparkles")
                        .imageScale(.large)
                        .foregroundStyle(.yellow)
                        .rotationEffect(.degrees(isSpinning ? 360 : 0))
                        .animation(.spring(response: 0.5, dampingFraction: 0.5).repeatForever(autoreverses: false), value: isSpinning)
                    
                    Text("Jarvis")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.primary)
                }
                
                if authViewModel.isSignedIn {
                    // Dashboard
                    dashboardView
                } else {
                    // Sign in prompt
                    signInPromptView
                }
            }
            .padding()
            .onAppear {
                isSpinning = true
                Task {
                    await authViewModel.checkAuthStatus()
                    if authViewModel.isSignedIn {
                        await emailViewModel.fetchEmails()
                    }
                }
            }
            .onChange(of: authViewModel.isSignedIn) { newValue in
                if newValue {
                    Task {
                        await emailViewModel.fetchEmails()
                    }
                }
            }
        }
    }
    
    private var signInPromptView: some View {
        VStack(spacing: 20) {
            Text("Welcome to Email Assistant")
                .font(.title2)
                .multilineTextAlignment(.center)
            
            Text("Sign in with your Google account to manage your emails efficiently")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                Task {
                    await authViewModel.signIn()
                }
            }) {
                HStack {
                    Image(systemName: "envelope.badge.person.crop")
                    Text("Sign in with Google")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }
    
    private var dashboardView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Stats
                HStack(spacing: 16) {
                    // Unread Emails Card
                    NavigationLink(destination: EmailManagerView(emailViewModel: emailViewModel, filter: .unread)) {
                        StatCard(
                            title: "Unread",
                            value: "\(emailViewModel.unreadCount)",
                            icon: "envelope.badge.fill",
                            color: .blue
                        )
                    }
                    
                    // Storage Card
                    StatCard(
                        title: "Storage",
                        value: emailViewModel.totalStorageUsed,
                        icon: "externaldrive.fill",
                        color: .green
                    )
                }
                
                // Main Actions
                VStack(spacing: 16) {
                    // Clean Up Card
                    NavigationLink(destination: CleanupView(emailViewModel: emailViewModel)) {
                        ActionCard(
                            title: "Smart Cleanup",
                            subtitle: "Analyze and manage emails by sender",
                            icon: "sparkles.rectangle.stack.fill",
                            color: .purple
                        )
                    }
                    
                    // Categories Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(EmailCategory.allCases, id: \.self) { category in
                            NavigationLink(destination: EmailManagerView(emailViewModel: emailViewModel, filter: .category(category))) {
                                CategoryCard(
                                    category: category,
                                    count: emailViewModel.categorizedEmails[category]?.count ?? 0
                                )
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .refreshable {
            await emailViewModel.fetchEmails()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    Task {
                        await authViewModel.signOut()
                        emailViewModel.reset()
                    }
                }) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

// Modern stat card for quick metrics
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Spacer()
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(.title.bold())
                .foregroundStyle(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

// Modern action card for main features
struct ActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title3.bold())
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

// Modern category card
struct CategoryCard: View {
    let category: EmailCategory
    let count: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: category.icon)
                .font(.title2)
                .foregroundStyle(category.color)
            
            Text(category.rawValue.capitalized)
                .font(.headline)
            
            Text("\(count) emails")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

#Preview {
    ContentView()
}
