// ClientDetailView.swift
import SwiftUI
import FirebaseFirestore

struct ClientDetailView: View {
    let client: Client
    
    @StateObject private var loader = ClientScheduleLoader()
    
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Client Avatar with curved background
                header
                
                // Tab selector
                tabBar
                
                // Tab content
                content
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
            }
            .padding(.horizontal, Spacing.lg)
        }
        .padding(.horizontal, Spacing.lg)
    }
    
    // MARK: - Schedule Tab
    
    private var scheduleTab: some View {
        VStack(spacing: Spacing.lg) {
            // Next Event card
            card {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Next Event")
                        .font(.headingMedium)
                        .foregroundStyle(AppTheme.primary)
                    
                    if let nextEvent = loader.nextUpcomingEvent {
                        switch nextEvent {
                        case .lesson(let booking):
                            lessonEventView(booking: booking, showDivider: false)
                        case .classItem(let classItem):
                            classEventView(classItem: classItem, showDivider: false)
                        }
                    } else {
                        Text("No upcoming events scheduled.")
                            .font(.bodyMedium)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            
            // All Upcoming Events
            if !loader.upcomingEvents.isEmpty {
                card {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Upcoming")
                            .font(.headingMedium)
                            .foregroundStyle(AppTheme.primary)
                        
                        ForEach(Array(loader.upcomingEvents.enumerated()), id: \.offset) { index, event in
                            switch event {
                            case .lesson(let booking):
                                lessonEventView(booking: booking, showDivider: index < loader.upcomingEvents.count - 1)
                            case .classItem(let classItem):
                                classEventView(classItem: classItem, showDivider: index < loader.upcomingEvents.count - 1)
                            }
                        }
                    }
                }
            }
            
            // Past Events
            if !loader.pastEvents.isEmpty {
                card {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Past Visits")
                            .font(.headingMedium)
                            .foregroundStyle(AppTheme.primary)
                        
                        ForEach(Array(loader.pastEvents.enumerated()), id: \.offset) { index, event in
                            switch event {
                            case .lesson(let booking):
                                lessonEventView(booking: booking, showDivider: index < loader.pastEvents.count - 1)
                            case .classItem(let classItem):
                                classEventView(classItem: classItem, showDivider: index < loader.pastEvents.count - 1)
                            }
                        }
                    }
                }
            }
            
            if loader.isLoading {
                ProgressView()
                    .tint(AppTheme.primary)
                    .padding()
            }
        }
        .padding(.horizontal, Spacing.lg)
    }
    
    // MARK: - Event Views
    
    private func lessonEventView(booking: ClientBooking, showDivider: Bool) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "person.fill")
                    .font(.labelSmall)
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Lesson")
                    .font(.labelMedium)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.textPrimary)
                if !booking.status.isEmpty {
                    Text("• \(booking.status.capitalized)")
                        .font(.labelSmall)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            
            Text("\(formatDate(booking.startTime)) • \(formatTime(booking.startTime))–\(formatTime(booking.endTime))")
                .font(.bodyMedium)
                .foregroundStyle(AppTheme.textSecondary)
            
            if !booking.trainerName.isEmpty {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "person.fill")
                        .font(.labelSmall)
                        .foregroundStyle(AppTheme.textSecondary)
                    Text(booking.trainerName)
                        .font(.bodyMedium)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            
            if showDivider {
                Divider()
                    .opacity(0.2)
                    .padding(.top, Spacing.xs)
            }
        }
        .padding(.vertical, Spacing.xs)
    }
    
    private func classEventView(classItem: ClientClass, showDivider: Bool) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "sportscourt.fill")
                    .font(.labelSmall)
                    .foregroundStyle(AppTheme.primary)
                Text("Class")
                    .font(.labelMedium)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.textPrimary)
                if !classItem.title.isEmpty {
                    Text("• \(classItem.title)")
                        .font(.labelSmall)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            
            Text("\(formatDate(classItem.startTime)) • \(formatTime(classItem.startTime))–\(formatTime(classItem.endTime))")
                .font(.bodyMedium)
                .foregroundStyle(AppTheme.textSecondary)
            
            if !classItem.trainerName.isEmpty {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "person.fill")
                        .font(.labelSmall)
                        .foregroundStyle(AppTheme.textSecondary)
                    Text(classItem.trainerName)
                        .font(.bodyMedium)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            
            if !classItem.location.isEmpty {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.labelSmall)
                        .foregroundStyle(AppTheme.textSecondary)
                    Text(classItem.location)
                        .font(.bodyMedium)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            
            if showDivider {
                Divider()
                    .opacity(0.2)
                    .padding(.top, Spacing.xs)
            }
        }
        .padding(.vertical, Spacing.xs)
    }
    
    // MARK: - Helper Views
    
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
            )
    }
    
    // MARK: - Formatters
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Data Models

struct ClientBooking: Identifiable {
    let id: String
    let startTime: Date
    let endTime: Date
    let status: String
    let trainerName: String
}

struct ClientClass: Identifiable {
    let id: String
    let startTime: Date
    let endTime: Date
    let title: String
    let trainerName: String
    let location: String
}

enum ClientEvent: Identifiable {
    case lesson(ClientBooking)
    case classItem(ClientClass)
    
    var id: String {
        switch self {
        case .lesson(let booking): return "lesson-\(booking.id)"
        case .classItem(let classItem): return "class-\(classItem.id)"
        }
    }
    
    var date: Date {
        switch self {
        case .lesson(let booking): return booking.startTime
        case .classItem(let classItem): return classItem.startTime
        }
    }
}

// MARK: - Schedule Loader

@MainActor
class ClientScheduleLoader: ObservableObject {
    @Published var upcomingEvents: [ClientEvent] = []
    @Published var pastEvents: [ClientEvent] = []
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    
    var nextUpcomingEvent: ClientEvent? {
        upcomingEvents.first
    }
    
    func loadClientSchedule(clientId: String) async {
        isLoading = true
        
        let now = Date()
        var upcoming: [ClientEvent] = []
        var past: [ClientEvent] = []
        
        do {
            // Load bookings for this client
            let bookingsSnapshot = try await db.collection("bookings")
                .whereField("clientUID", isEqualTo: clientId)
                .order(by: "startTime", descending: false)
                .getDocuments()
            
            for doc in bookingsSnapshot.documents {
                let data = doc.data()
                guard let startTs = data["startTime"] as? Timestamp,
                      let endTs = data["endTime"] as? Timestamp else { continue }
                
                let startTime = startTs.dateValue()
                let endTime = endTs.dateValue()
                let status = data["status"] as? String ?? "confirmed"
                
                // Get trainer name
                var trainerName = "Trainer"
                if let trainerId = data["trainerUID"] as? String {
                    if let trainerDoc = try? await db.collection("trainers").document(trainerId).getDocument(),
                       let trainerData = trainerDoc.data(),
                       let name = trainerData["name"] as? String {
                        trainerName = name
                    }
                }
                
                let booking = ClientBooking(
                    id: doc.documentID,
                    startTime: startTime,
                    endTime: endTime,
                    status: status,
                    trainerName: trainerName
                )
                
                if startTime >= now {
                    upcoming.append(.lesson(booking))
                } else {
                    past.append(.lesson(booking))
                }
            }
            
            // Load classes where this client is registered
            let classesSnapshot = try await db.collectionGroup("participants")
                .whereField("userId", isEqualTo: clientId)
                .getDocuments()
            
            // Get class IDs
            let classIds = Set(classesSnapshot.documents.compactMap { $0.reference.parent.parent?.documentID })
            
            // Load class details
            for classId in classIds {
                if let classDoc = try? await db.collection("classes").document(classId).getDocument(),
                   let classData = classDoc.data(),
                   let startTs = classData["startTime"] as? Timestamp,
                   let endTs = classData["endTime"] as? Timestamp {
                    
                    let startTime = startTs.dateValue()
                    let endTime = endTs.dateValue()
                    let title = classData["title"] as? String ?? "Group Class"
                    let location = classData["location"] as? String ?? ""
                    
                    // Get trainer name
                    var trainerName = "Trainer"
                    if let trainerId = classData["trainerId"] as? String {
                        if let trainerDoc = try? await db.collection("trainers").document(trainerId).getDocument(),
                           let trainerData = trainerDoc.data(),
                           let name = trainerData["name"] as? String {
                            trainerName = name
                        }
                    }
                    
                    let classItem = ClientClass(
                        id: classDoc.documentID,
                        startTime: startTime,
                        endTime: endTime,
                        title: title,
                        trainerName: trainerName,
                        location: location
                    )
                    
                    if startTime >= now {
                        upcoming.append(.classItem(classItem))
                    } else {
                        past.append(.classItem(classItem))
                    }
                }
            }
            
            // Sort events
            self.upcomingEvents = upcoming.sorted { $0.date < $1.date }
            self.pastEvents = past.sorted { $0.date > $1.date }
            
        } catch {
            print("Error loading client schedule: \(error)")
        }
        
        isLoading = false
    }
            
            // Athlete Information
            if client.athleteFullName != nil || client.athlete2
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
    .task {
            await loader.loadClientSchedule(clientId: client.id)
        }
        .refreshable {
            await loader.loadClientSchedule(clientId: client.id)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        ZStack(alignment: .bottom) {
            // Curved background
            GeometryReader { proxy in
                let circleSize = proxy.size.width * 2.2
                Circle()
                    .fill(AppTheme.primary)
                    .frame(width: circleSize, height: circleSize)
                    .position(x: proxy.size.width / 2, y: -circleSize * 0.32)
            }
            .frame(height: 180)
            
            // Avatar + name + email
            VStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(Color(UIColor.systemBackground))
                        .frame(width: 98, height: 98)
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.primary.opacity(0.8), AppTheme.primaryLight.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 90)
                    Text(client.initials)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                Text(client.fullName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                
                if !client.emailAddress.isEmpty {
                    Text(client.emailAddress)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 12)
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Tab Bar
    
    @State private var selectedTab: ClientTab = .info
    
    enum ClientTab: String {
        case info = "INFO"
        case schedule = "SCHEDULE"
    }
    
    private var tabBar: some View {
        HStack(spacing: 24) {
            tabItem(.info)
            tabItem(.schedule)
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }
    
    private func tabItem(_ tab: ClientTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
        } label: {
            VStack(spacing: 6) {
                Text(tab.rawValue)
                    .font(.system(size: 14, weight: selectedTab == tab ? .bold : .regular))
                    .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                Rectangle()
                    .fill(selectedTab == tab ? AppTheme.primary : .clear)
                    .frame(height: 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cornerRadius(1.5)
                    .opacity(selectedTab == tab ? 1 : 0)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Tab Content
    
    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .info:
            infoTab
        case .schedule:
            scheduleTab
        }
    }
    
    // MARK: - Info Tab
    
    private var infoTab: some View {
        VStack(spacing: Spacing.lg) {