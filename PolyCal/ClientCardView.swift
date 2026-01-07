//
//  ClientCardView.swift
//  PolyCal
//
//  Created by GitHub Copilot
//

import SwiftUI
import Combine

struct AggregatedPackage: Identifiable {
    let id = UUID()
    let packageType: String
    let totalRemaining: Int
    let totalLessons: Int
    let totalUsed: Int
    let hasExpired: Bool
    
    var packageDisplayName: String {
        switch packageType {
        case "single": return "Single Lesson"
        case "private": return "Private Lesson"
        case "two_athlete", "2_athlete": return "2 Athletes"
        case "three_athlete", "3_athlete": return "3 Athletes"
        case "class_pass": return "Class Pass"
        default: return packageType.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
    
    var statusText: String {
        if totalRemaining == 0 {
            return "All used"
        } else if hasExpired {
            return "\(totalRemaining) remaining (some expired)"
        } else {
            return "\(totalRemaining) of \(totalLessons) remaining"
        }
    }
}

enum ClientCardTab: String, CaseIterable, Identifiable {
    case profile = "Profile"
    case account = "Account"
    case schedule = "Schedule"
    case documents = "Documents"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .profile: return "person.fill"
        case .account: return "creditcard.fill"
        case .schedule: return "calendar"
        case .documents: return "doc.fill"
        }
    }
}

struct BubbleTab: View {
    let title: String
    let icon: String
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(isSelected ? .white : AppTheme.textSecondary)
            
            Text(title)
                .font(.labelSmall)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(
            isSelected ? AppTheme.primary : Color.clear
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.clear : AppTheme.border, lineWidth: 1)
        )
    }
}

struct ClientCardView: View {
    let client: Client
    let selectedBooking: ClientBooking? // If opened from a booked lesson
    
    @StateObject private var viewModel = ClientCardViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: ClientCardTab = .profile
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Client Header with Avatar
                        clientHeader
                            .padding(.top, Spacing.lg)
                        
                        // Contact Information (always visible)
                        contactSection
                        
                        // Bubble Tab Selector
                        bubbleTabs
                            .padding(.horizontal, Spacing.lg)
                        
                        // Tab Content
                        tabContent
                    }
                    .padding(.bottom, Spacing.xxxl)
                }
                .background(Color(UIColor.systemGroupedBackground))
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
        .navigationViewStyle(.stack)
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
    }
    
    // MARK: - Contact Section
    private var contactSection: some View {
        CardView {
            HStack(spacing: Spacing.md) {
                // Email
                Link(destination: URL(string: "mailto:\(client.emailAddress)")!) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.primary)
                }
                
                // Phone
                Link(destination: URL(string: "tel:\(client.phoneNumber)")!) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.primary)
                }
                
                // Text Message
                Link(destination: URL(string: "sms:\(client.phoneNumber)")!) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(client.emailAddress)
                        .font(.labelSmall)
                        .foregroundStyle(AppTheme.textSecondary)
                    Text(client.phoneNumber)
                        .font(.labelSmall)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(Spacing.md)
        }
        .padding(.horizontal, Spacing.lg)
    }
    
    // MARK: - Bubble Tabs
    private var bubbleTabs: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(ClientCardTab.allCases) { tab in
                BubbleTab(
                    title: tab.rawValue,
                    icon: tab.icon,
                    isSelected: selectedTab == tab
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = tab
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .profile:
            profileContent
        case .account:
            accountContent
        case .schedule:
            scheduleContent
        case .documents:
            documentsContent
        }
    }
    
    private var profileContent: some View {
        VStack(spacing: Spacing.md) {
            lessonSection
            athleteSection
            notesSection
        }
        .padding(.horizontal, Spacing.lg)
    }
    
    private var accountContent: some View {
        accountSection
            .padding(.horizontal, Spacing.lg)
    }
    
    private var scheduleContent: some View {
        scheduleSection
            .padding(.horizontal, Spacing.lg)
    }
    
    private var documentsContent: some View {
        documentsSection
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
                            
                            if nextBooking.isClassBooking != true {
                                HStack(spacing: Spacing.xs) {
                                    Image(systemName: "ticket.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(AppTheme.textSecondary)
                                    Text(nextBooking.packageTypeName)
                                        .font(.bodyMedium)
                                        .foregroundStyle(AppTheme.textPrimary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Athlete Section
    private var athleteSection: some View {
        Group {
            if client.athleteFullName != nil {
                CardView {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Athletes")
                            .font(.headingSmall)
                            .foregroundStyle(AppTheme.textPrimary)
                        
                        VStack(spacing: Spacing.sm) {
                            if let athleteName = client.athleteFullName {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: Spacing.xs) {
                                        Image(systemName: "figure.volleyball")
                                            .font(.system(size: 14))
                                            .foregroundStyle(AppTheme.textSecondary)
                                        Text(athleteName)
                                            .font(.bodyMedium)
                                            .foregroundStyle(AppTheme.textPrimary)
                                        if let position = client.athletePosition {
                                            Text("•")
                                                .foregroundStyle(AppTheme.textTertiary)
                                            Text(position)
                                                .font(.bodyMedium)
                                                .foregroundStyle(AppTheme.textSecondary)
                                        }
                                    }
                                    if let birthday = client.athleteBirthday {
                                        HStack(spacing: Spacing.xs) {
                                            Image(systemName: "calendar")
                                                .font(.system(size: 12))
                                                .foregroundStyle(AppTheme.textTertiary)
                                            Text(birthday)
                                                .font(.bodySmall)
                                                .foregroundStyle(AppTheme.textSecondary)
                                        }
                                        .padding(.leading, 20)
                                    }
                                }
                            }
                            
                            if let athlete2Name = client.athlete2FullName {
                                Divider()
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: Spacing.xs) {
                                        Image(systemName: "figure.volleyball")
                                            .font(.system(size: 14))
                                            .foregroundStyle(AppTheme.textSecondary)
                                        Text(athlete2Name)
                                            .font(.bodyMedium)
                                            .foregroundStyle(AppTheme.textPrimary)
                                        if let position = client.athlete2Position {
                                            Text("•")
                                                .foregroundStyle(AppTheme.textTertiary)
                                            Text(position)
                                                .font(.bodyMedium)
                                                .foregroundStyle(AppTheme.textSecondary)
                                        }
                                    }
                                    if let birthday = client.athlete2Birthday {
                                        HStack(spacing: Spacing.xs) {
                                            Image(systemName: "calendar")
                                                .font(.system(size: 12))
                                                .foregroundStyle(AppTheme.textTertiary)
                                            Text(birthday)
                                                .font(.bodySmall)
                                                .foregroundStyle(AppTheme.textSecondary)
                                        }
                                        .padding(.leading, 20)
                                    }
                                }
                            }
                            
                            if let athlete3Name = client.athlete3FullName {
                                Divider()
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: Spacing.xs) {
                                        Image(systemName: "figure.volleyball")
                                            .font(.system(size: 14))
                                            .foregroundStyle(AppTheme.textSecondary)
                                        Text(athlete3Name)
                                            .font(.bodyMedium)
                                            .foregroundStyle(AppTheme.textPrimary)
                                        if let position = client.athlete3Position {
                                            Text("•")
                                                .foregroundStyle(AppTheme.textTertiary)
                                            Text(position)
                                                .font(.bodyMedium)
                                                .foregroundStyle(AppTheme.textSecondary)
                                        }
                                    }
                                    if let birthday = client.athlete3Birthday {
                                        HStack(spacing: Spacing.xs) {
                                            Image(systemName: "calendar")
                                                .font(.system(size: 12))
                                                .foregroundStyle(AppTheme.textTertiary)
                                            Text(birthday)
                                                .font(.bodySmall)
                                                .foregroundStyle(AppTheme.textSecondary)
                                        }
                                        .padding(.leading, 20)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Notes Section
    private var notesSection: some View {
        Group {
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
            }
        }
    }
    
    // MARK: - Account Section
    private var accountSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("Lesson Packages")
                        .font(.headingSmall)
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Spacer()
                    
                    if viewModel.isLoadingPackages {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                if viewModel.aggregatedPackages.isEmpty && !viewModel.isLoadingPackages {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "creditcard")
                            .font(.system(size: 32))
                            .foregroundStyle(AppTheme.textTertiary)
                        Text("No lesson packages")
                            .font(.bodyMedium)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.lg)
                } else {
                    VStack(spacing: Spacing.sm) {
                        ForEach(viewModel.aggregatedPackages) { package in
                            aggregatedPackageRow(package)
                            if package.id != viewModel.aggregatedPackages.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func aggregatedPackageRow(_ package: AggregatedPackage) -> some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(package.packageDisplayName)
                    .font(.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.textPrimary)
                
                Text(package.statusText)
                    .font(.labelSmall)
                    .foregroundStyle(aggregatedPackageStatusColor(package))
            }
            
            Spacer()
            
            if package.totalRemaining > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(package.totalRemaining)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AppTheme.primary)
                    Text("left")
                        .font(.labelSmall)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .padding(.vertical, Spacing.xs)
    }
    
    private func aggregatedPackageStatusColor(_ package: AggregatedPackage) -> Color {
        if package.totalRemaining == 0 {
            return AppTheme.textTertiary
        } else if package.totalRemaining <= 1 {
            return Color.orange
        } else {
            return AppTheme.success
        }
    }
    
    // MARK: - Schedule Section
    private var scheduleSection: some View {
        VStack(spacing: Spacing.md) {
            // Upcoming Visits
            CardView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack {
                        Text("Upcoming Visits")
                            .font(.headingSmall)
                            .foregroundStyle(AppTheme.textPrimary)
                        
                        Spacer()
                        
                        if viewModel.isLoadingBookings {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    
                    if viewModel.upcomingBookings.isEmpty && !viewModel.isLoadingBookings {
                        VStack(spacing: Spacing.sm) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 32))
                                .foregroundStyle(AppTheme.textTertiary)
                            Text("No upcoming visits")
                                .font(.bodyMedium)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                    } else {
                        VStack(spacing: Spacing.xs) {
                            ForEach(viewModel.upcomingBookings) { booking in
                                bookingRow(booking)
                            }
                        }
                    }
                }
            }
            
            // Visit History
            CardView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Visit History")
                        .font(.headingSmall)
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    if viewModel.pastBookings.isEmpty && !viewModel.isLoadingBookings {
                        VStack(spacing: Spacing.sm) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 32))
                                .foregroundStyle(AppTheme.textTertiary)
                            Text("No past visits")
                                .font(.bodyMedium)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                    } else {
                        VStack(spacing: Spacing.xs) {
                            ForEach(viewModel.pastBookings.prefix(10)) { booking in
                                bookingRow(booking)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func bookingRow(_ booking: ClientBooking) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: booking.isClassBooking == true ? "person.3.fill" : "figure.volleyball")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(booking.trainerName)
                    .font(.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundStyle(AppTheme.textPrimary)
                
                Text(booking.formattedDate)
                    .font(.labelSmall)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            
            Spacer()
            
            Text(booking.duration)
                .font(.labelMedium)
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
                
                if viewModel.documents.isEmpty && !viewModel.isLoadingDocuments {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 32))
                            .foregroundStyle(AppTheme.textTertiary)
                        Text("No documents on file")
                            .font(.bodyMedium)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.lg)
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
                    .fontWeight(.medium)
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
    @Published var aggregatedPackages: [AggregatedPackage] = []
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
            aggregatePackages()
        } catch {
            print("Error loading packages: \(error)")
        }
    }
    
    private func aggregatePackages() {
        // Group packages by type
        let grouped = Dictionary(grouping: packages) { $0.packageType }
        
        // Create aggregated packages
        aggregatedPackages = grouped.map { (packageType, packagesOfType) in
            let totalRemaining = packagesOfType.reduce(0) { $0 + $1.lessonsRemaining }
            let hasExpired = packagesOfType.contains { $0.isExpired && $0.lessonsRemaining > 0 }
            let totalLessons = packagesOfType.reduce(0) { $0 + $1.totalLessons }
            let totalUsed = packagesOfType.reduce(0) { $0 + $1.lessonsUsed }
            
            return AggregatedPackage(
                packageType: packageType,
                totalRemaining: totalRemaining,
                totalLessons: totalLessons,
                totalUsed: totalUsed,
                hasExpired: hasExpired
            )
        }
        .sorted { $0.packageDisplayName < $1.packageDisplayName }
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
