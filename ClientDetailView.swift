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
            }
            .padding(.bottom, Spacing.xxxl)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(client.firstName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
