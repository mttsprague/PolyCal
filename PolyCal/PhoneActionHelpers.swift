//
//  PhoneActionHelpers.swift
//  PolyCal
//
//  Created by Assistant on 12/29/25.
//

import SwiftUI

// MARK: - Phone Action Menu Button
struct PhoneActionButton: View {
    let phoneNumber: String
    
    var body: some View {
        Menu {
            Button {
                callPhoneNumber(phoneNumber)
            } label: {
                Label("Call", systemImage: "phone.fill")
            }
            
            Button {
                textPhoneNumber(phoneNumber)
            } label: {
                Label("Message", systemImage: "message.fill")
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(phoneNumber)
                    .font(.bodyMedium)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(AppTheme.primary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.xs, style: .continuous)
                    .fill(AppTheme.primary.opacity(0.12))
            )
        }
    }
    
    private func callPhoneNumber(_ phoneNumber: String) {
        let cleaned = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let url = URL(string: "tel://\(cleaned)") {
            #if canImport(UIKit)
            UIApplication.shared.open(url)
            #endif
        }
    }
    
    private func textPhoneNumber(_ phoneNumber: String) {
        let cleaned = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let url = URL(string: "sms://\(cleaned)") {
            #if canImport(UIKit)
            UIApplication.shared.open(url)
            #endif
        }
    }
}

// MARK: - Inline Phone Actions (for lists)
struct InlinePhoneActions: View {
    let phoneNumber: String
    
    var body: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                callPhoneNumber(phoneNumber)
            } label: {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Call")
                        .font(.labelMedium)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.xs, style: .continuous)
                        .fill(AppTheme.success)
                )
            }
            .buttonStyle(.plain)
            
            Button {
                textPhoneNumber(phoneNumber)
            } label: {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Text")
                        .font(.labelMedium)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.xs, style: .continuous)
                        .fill(AppTheme.primary)
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private func callPhoneNumber(_ phoneNumber: String) {
        let cleaned = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let url = URL(string: "tel://\(cleaned)") {
            #if canImport(UIKit)
            UIApplication.shared.open(url)
            #endif
        }
    }
    
    private func textPhoneNumber(_ phoneNumber: String) {
        let cleaned = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let url = URL(string: "sms://\(cleaned)") {
            #if canImport(UIKit)
            UIApplication.shared.open(url)
            #endif
        }
    }
}
