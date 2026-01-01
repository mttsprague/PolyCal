// ClientDetailView.swift
import SwiftUI

struct ClientDetailView: View {
    let client: Client

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Client Avatar
                VStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.primary.opacity(0.8), AppTheme.primaryLight.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                        
                        Text(client.initials)
                            .font(.displaySmall)
                            .foregroundStyle(.white)
                    }
                    
                    Text(client.fullName)
                        .font(.headingLarge)
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .padding(.top, Spacing.xl)
                
                // Contact Card
                CardView {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Contact Information")
                            .font(.headingSmall)
                            .foregroundStyle(AppTheme.textPrimary)
                        
                        VStack(spacing: Spacing.sm) {
                            // Email
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text("Email")
                                    .font(.labelMedium)
                                    .foregroundStyle(AppTheme.textSecondary)
                                
                                Link(destination: URL(string: "mailto:\(client.emailAddress)")!) {
                                    HStack(spacing: Spacing.xs) {
                                        Image(systemName: "envelope.fill")
                                            .font(.system(size: 14))
                                        Text(client.emailAddress)
                                            .font(.bodyMedium)
                                    }
                                    .foregroundStyle(AppTheme.primary)
                                }
                            }
                            
                            Divider()
                            
                            // Phone with Call/Text actions
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("Phone")
                                    .font(.labelMedium)
                                    .foregroundStyle(AppTheme.textSecondary)
                                
                                HStack {
                                    HStack(spacing: Spacing.xs) {
                                        Image(systemName: "phone.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Text(client.phoneNumber)
                                            .font(.bodyMedium)
                                            .foregroundStyle(AppTheme.textPrimary)
                                    }
                                    
                                    Spacer()
                                    
                                    InlinePhoneActions(phoneNumber: client.phoneNumber)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                
                // Athlete Information
                if client.athleteFullName != nil {
                    CardView {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("Athlete Information")
                                .font(.headingSmall)
                                .foregroundStyle(AppTheme.textPrimary)
                            
                            VStack(spacing: Spacing.sm) {
                                if let athleteName = client.athleteFullName {
                                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                                        Text("Primary Athlete")
                                            .font(.labelMedium)
                                            .foregroundStyle(AppTheme.textSecondary)
                                        
                                        HStack(spacing: Spacing.xs) {
                                            Image(systemName: "figure.volleyball")
                                                .font(.system(size: 14))
                                            Text(athleteName)
                                                .font(.bodyMedium)
                                            if let position = client.athletePosition {
                                                Text("•")
                                                    .foregroundStyle(AppTheme.textTertiary)
                                                Text(position)
                                                    .font(.bodyMedium)
                                                    .foregroundStyle(AppTheme.textSecondary)
                                            }
                                        }
                                        .foregroundStyle(AppTheme.textPrimary)
                                    }
                                }
                                
                                if let athlete2Name = client.athlete2FullName {
                                    Divider()
                                    
                                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                                        Text("Second Athlete")
                                            .font(.labelMedium)
                                            .foregroundStyle(AppTheme.textSecondary)
                                        
                                        HStack(spacing: Spacing.xs) {
                                            Image(systemName: "figure.volleyball")
                                                .font(.system(size: 14))
                                            Text(athlete2Name)
                                                .font(.bodyMedium)
                                            if let position = client.athlete2Position {
                                                Text("•")
                                                    .foregroundStyle(AppTheme.textTertiary)
                                                Text(position)
                                                    .font(.bodyMedium)
                                                    .foregroundStyle(AppTheme.textSecondary)
                                            }
                                        }
                                        .foregroundStyle(AppTheme.textPrimary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                }
                
                // Notes for Coach
                if let notes = client.notesForCoach, !notes.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("Notes")
                                .font(.headingSmall)
                                .foregroundStyle(AppTheme.textPrimary)
                            
                            Text(notes)
                                .font(.bodyMedium)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                }
            }
            .padding(.bottom, Spacing.xxxl)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(client.firstName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
