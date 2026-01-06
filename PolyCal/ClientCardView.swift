//
//  ClientCardView.swift
//  PolyCal
//
//  Created by GitHub Copilot
//

import SwiftUI

struct ClientCardView: View {
    let client: Client
    let selectedBooking: ClientBooking? // If opened from a booked lesson
    
    @StateObject private var viewModel = ClientCardViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Client Header with Avatar
                    clientHeader
                    
                    // Contact Information
                    contactSection
                    
                    // Next/Current Lesson
                    lessonSection
                    
                    // Account - Lesson Packages
                    accountSection
                    
                    // Schedule - Upcoming & History
                    scheduleSection
                    
                    // Documents
                    documentsSection
                }
                .padding(.bottom, Spacing.xxxl)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(client.firstName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await viewModel.loadClientData(clientId: client.id, selectedBooking: selectedBooking)
        }
    }
    
    // MARK: - Client Header
    private var clientHeader: some View {
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
    }
    
    // MARK: - Contact Section
    private var contactSection: some View {
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
    
    // MARK: - Lesson Section
    private var lessonSection: some View {
        Group {
            if let nextBooking = viewModel.displayedLesson {
                CardView {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        HStack {
                            Text(selectedBooking != nil ? "Selected Lesson" : "Next Lesson")
                                .font(.headingSmall)
                                .foregroundStyle(AppTheme.textPrimary)
                            
                            Spacer()
                            
                            if nextBooking.isClassBooking == true {
                                Label("Class", systemImage: "person.3.fill")
                                    .font(.labelSmall)
                                    .foregroundStyle(AppTheme.primary)
                                    .padding(.horizontal, Spacing.sm)
                                    .padding(.vertical, Spacing.xxs)
                                    .background(AppTheme.primary.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text(nextBooking.formattedDate)
                                    .font(.bodyMedium)
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                            
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text(nextBooking.trainerName)
                                    .font(.bodyMedium)
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                            
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "clock")
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text(nextBooking.duration)
                                    .font(.bodyMedium)
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
    }
    
    // MARK: - Account Section
    private var accountSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("Account")
                        .font(.headingSmall)
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Spacer()
                    
                    if viewModel.isLoadingPackages {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                if viewModel.packages.isEmpty {
                    Text("No lesson packages")
                        .font(.bodyMedium)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, Spacing.md)
                } else {
                    VStack(spacing: Spacing.sm) {
                        ForEach(viewModel.packages) { package in
                            packageRow(package)
                            if package.id != viewModel.packages.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
    }
    
    private func packageRow(_ package: LessonPackage) -> some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(package.packageDisplayName)
                    .font(.bodyMedium)
                    .foregroundStyle(AppTheme.textPrimary)
                
                Text(package.statusText)
                    .font(.labelSmall)
                    .foregroundStyle(packageStatusColor(package))
            }
            
            Spacer()
            
            if package.lessonsRemaining > 0 && !package.isExpired {
                Text("\(package.lessonsRemaining)")
                    .font(.headingMedium)
                    .foregroundStyle(AppTheme.primary)
            } else {
                Image(systemName: package.isExpired ? "clock.badge.xmark" : "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .padding(.vertical, Spacing.xxs)
    }
    
    private func packageStatusColor(_ package: LessonPackage) -> Color {
        if package.isExpired || package.lessonsRemaining == 0 {
            return AppTheme.textTertiary
        } else if package.lessonsRemaining <= 1 {
            return Color.orange
        } else {
            return AppTheme.success
        }
    }
    
    // MARK: - Schedule Section
    private var scheduleSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("Schedule")
                        .font(.headingSmall)
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Spacer()
                    
                    if viewModel.isLoadingBookings {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                // Upcoming Visits
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Upcoming Visits")
                        .font(.labelMedium)
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    if viewModel.upcomingBookings.isEmpty {
                        Text("No upcoming visits")
                            .font(.bodyMedium)
                            .foregroundStyle(AppTheme.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, Spacing.sm)
                    } else {
                        VStack(spacing: Spacing.xs) {
                            ForEach(viewModel.upcomingBookings) { booking in
                                bookingRow(booking)
                            }
                        }
                    }
                }
                
                Divider()
                    .padding(.vertical, Spacing.xs)
                
                // Visit History
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Visit History")
                        .font(.labelMedium)
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    if viewModel.pastBookings.isEmpty {
                        Text("No past visits")
                            .font(.bodyMedium)
                            .foregroundStyle(AppTheme.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, Spacing.sm)
                    } else {
                        VStack(spacing: Spacing.xs) {
                            ForEach(viewModel.pastBookings) { booking in
                                bookingRow(booking)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
    }
    
    private func bookingRow(_ booking: ClientBooking) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: booking.isClassBooking == true ? "person.3.fill" : "figure.volleyball")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(booking.trainerName)
                    .font(.bodyMedium)
                    .foregroundStyle(AppTheme.textPrimary)
                
                Text(booking.formattedDate)
                    .font(.labelSmall)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            
            Spacer()
            
            Text(booking.duration)
                .font(.labelSmall)
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(.vertical, Spacing.xxs)
    }
    
    // MARK: - Documents Section
    private var documentsSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("Documents")
                        .font(.headingSmall)
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Spacer()
                    
                    if viewModel.isLoadingDocuments {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                if viewModel.documents.isEmpty {
                    Text("No documents on file")
                        .font(.bodyMedium)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, Spacing.md)
                } else {
                    VStack(spacing: Spacing.sm) {
                        ForEach(viewModel.documents) { document in
                            documentRow(document)
                            if document.id != viewModel.documents.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
    }
    
    private func documentRow(_ document: ClientDocument) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: document.icon)
                .font(.system(size: 20))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(document.displayName)
                    .font(.bodyMedium)
                    .foregroundStyle(AppTheme.textPrimary)
                
                Text(document.uploadedAt.formatted(.relative(presentation: .named)))
                    .font(.labelSmall)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            
            Spacer()
            
            if document.url != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .padding(.vertical, Spacing.xs)
        .contentShape(Rectangle())
        .onTapGesture {
            if let urlString = document.url, let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        }
    }
}

// MARK: - View Model
@MainActor
class ClientCardViewModel: ObservableObject {
    @Published var packages: [LessonPackage] = []
    @Published var upcomingBookings: [ClientBooking] = []
    @Published var pastBookings: [ClientBooking] = []
    @Published var documents: [ClientDocument] = []
    @Published var displayedLesson: ClientBooking?
    
    @Published var isLoadingPackages = false
    @Published var isLoadingBookings = false
    @Published var isLoadingDocuments = false
    
    func loadClientData(clientId: String, selectedBooking: ClientBooking?) async {
        // Load all data in parallel
        async let packagesTask: () = loadPackages(clientId: clientId)
        async let bookingsTask: () = loadBookings(clientId: clientId)
        async let documentsTask: () = loadDocuments(clientId: clientId)
        
        await packagesTask
        await bookingsTask
        await documentsTask
        
        // Set displayed lesson
        if let selectedBooking = selectedBooking {
            displayedLesson = selectedBooking
        } else {
            displayedLesson = upcomingBookings.first
        }
    }
    
    private func loadPackages(clientId: String) async {
        isLoadingPackages = true
        defer { isLoadingPackages = false }
        
        do {
            packages = try await FirestoreService.shared.fetchClientPackages(clientId: clientId)
        } catch {
            print("Error loading packages: \(error)")
        }
    }
    
    private func loadBookings(clientId: String) async {
        isLoadingBookings = true
        defer { isLoadingBookings = false }
        
        do {
            async let upcomingTask = FirestoreService.shared.fetchClientBookings(clientId: clientId, upcoming: true)
            async let pastTask = FirestoreService.shared.fetchClientBookings(clientId: clientId, upcoming: false)
            
            upcomingBookings = try await upcomingTask
            pastBookings = try await pastTask
        } catch {
            print("Error loading bookings: \(error)")
        }
    }
    
    private func loadDocuments(clientId: String) async {
        isLoadingDocuments = true
        defer { isLoadingDocuments = false }
        
        do {
            documents = try await FirestoreService.shared.fetchClientDocuments(clientId: clientId)
        } catch {
            print("Error loading documents: \(error)")
        }
    }
}
