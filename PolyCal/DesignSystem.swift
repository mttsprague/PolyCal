//
//  DesignSystem.swift
//  PolyCal
//
//  Created by Assistant on 12/29/25.
//

import SwiftUI

// MARK: - Brand Colors
enum AppTheme {
    // Primary: Teal/Turquoise from logo
    static let primary = Color(red: 0.20, green: 0.70, blue: 0.68)
    static let primaryDark = Color(red: 0.15, green: 0.55, blue: 0.53)
    static let primaryLight = Color(red: 0.25, green: 0.80, blue: 0.78)
    
    // Secondary: Complementary orange/coral
    static let secondary = Color(red: 0.98, green: 0.45, blue: 0.25)
    static let secondaryLight = Color(red: 0.99, green: 0.65, blue: 0.45)
    
    // Accent: Deep blue
    static let accent = Color(red: 0.15, green: 0.35, blue: 0.65)
    
    // Neutrals
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(white: 0.6)
    static let border = Color(UIColor.separator)
    
    // Status colors
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    static let info = Color.blue
    
    // Schedule specific
    static let booked = Color(red: 0.15, green: 0.35, blue: 0.65)
    static let available = Color(red: 0.20, green: 0.70, blue: 0.68)
    static let unavailable = Color.gray
}

// MARK: - Typography
extension Font {
    static let displayLarge = Font.system(size: 40, weight: .bold, design: .rounded)
    static let displayMedium = Font.system(size: 32, weight: .bold, design: .rounded)
    static let displaySmall = Font.system(size: 28, weight: .bold, design: .rounded)
    
    static let headingLarge = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let headingMedium = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let headingSmall = Font.system(size: 18, weight: .semibold, design: .rounded)
    
    static let bodyLarge = Font.system(size: 17, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 15, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 13, weight: .regular, design: .default)
    
    static let labelLarge = Font.system(size: 15, weight: .medium, design: .default)
    static let labelMedium = Font.system(size: 13, weight: .medium, design: .default)
    static let labelSmall = Font.system(size: 11, weight: .medium, design: .default)
}

// MARK: - Spacing
enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40
}

// MARK: - Corner Radius
enum CornerRadius {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let round: CGFloat = 999
}

// MARK: - Shadows
extension View {
    func cardShadow() -> some View {
        self.shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
    
    func lightShadow() -> some View {
        self.shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    func heavyShadow() -> some View {
        self.shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
    }
}

// MARK: - Custom Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    var isCompact: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isCompact ? .labelLarge : .headingSmall)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, isCompact ? Spacing.sm : Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .fill(AppTheme.primary)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
            .heavyShadow()
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var isCompact: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isCompact ? .labelLarge : .headingSmall)
            .foregroundStyle(AppTheme.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, isCompact ? Spacing.sm : Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .fill(AppTheme.primary.opacity(0.12))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Card View
struct CardView<Content: View>: View {
    let content: Content
    var padding: CGFloat = Spacing.md
    
    init(padding: CGFloat = Spacing.md, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .fill(Color(UIColor.systemBackground))
            )
            .cardShadow()
    }
}

// MARK: - Section Header
struct SectionHeaderView: View {
    let title: String
    var action: (() -> Void)? = nil
    var actionTitle: String = "See All"
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headingMedium)
                .foregroundStyle(AppTheme.textPrimary)
            
            Spacer()
            
            if let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.labelMedium)
                        .foregroundStyle(AppTheme.primary)
                }
            }
        }
    }
}

// MARK: - Badge View
struct BadgeView: View {
    let text: String
    var color: Color = AppTheme.primary
    
    var body: some View {
        Text(text)
            .font(.labelSmall)
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .background(
                Capsule()
                    .fill(color)
            )
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)? = nil
    var actionTitle: String = "Get Started"
    
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(AppTheme.primary.opacity(0.6))
            
            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(.headingMedium)
                    .foregroundStyle(AppTheme.textPrimary)
                
                Text(message)
                    .font(.bodyMedium)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            if let action = action {
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(PrimaryButtonStyle(isCompact: true))
                .padding(.horizontal, Spacing.xxxl)
            }
        }
        .padding(Spacing.xxxl)
    }
}
