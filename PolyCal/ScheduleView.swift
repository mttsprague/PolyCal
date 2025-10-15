//
//  ScheduleView.swift
//  PolyCal
//
//  Created by Matthew Sprague on 10/12/25.
//

import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var viewModel = ScheduleViewModel()

    // Editor presentation state
    @State private var editorShown = false
    @State private var editorDay: Date = Date()
    @State private var editorHour: Int = 9

    // Options menu
    @State private var showOptions = false

    // Navigation to other schedule modes
    @State private var navigateToMyDay = false
    @State private var navigateToAllTrainersDay = false

    // Client detail sheet
    @State private var selectedClient: Client?
    @State private var clientSheetShown = false

    // Layout constants
    private let rowHeight: CGFloat = 32               // skinny rows
    private let rowVerticalPadding: CGFloat = 6       // tighter spacing between rows
    private let timeColWidth: CGFloat = 56            // fixed left column width
    private let dayColumnWidth: CGFloat = 160         // width per day column (scrollable horizontally)
    private let columnSpacing: CGFloat = 0            // spacing between day columns
    private let gridHeaderVPad: CGFloat = 6           // compact vertical padding for day header

    // Shared horizontal scroll position for header + grid
    @State private var hScrollOffset: CGFloat = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header avatar + name (tappable)
                header

                // Week strip with chevrons and evenly spaced day bubbles
                WeekStrip(
                    title: viewModel.weekTitle,
                    weekDays: viewModel.weekDays,
                    selectedDate: $viewModel.selectedDate,
                    onPrevWeek: { shiftWeek(by: -1) },
                    onNextWeek: { shiftWeek(by: 1) }
                )
                .padding(.top, 2)
                .padding(.bottom, 4) // tighter

                // MARK: Grid (fixed time column + horizontally scrolling days, single vertical scroll)
                let headerRowHeight = 28.0 // height of the day header stack (approx)

                ZStack(alignment: .topLeading) {
                    // Vertical content: time column + grid (no day header inside; we overlay it frozen)
                    ScrollView(.vertical, showsIndicators: true) {
                        HStack(spacing: 0) {
                            // Fixed left time column (does not scroll horizontally)
                            VStack(spacing: 0) {
                                // Spacer to align under the frozen day header height
                                Color.clear
                                    .frame(height: headerRowHeight + gridHeaderVPad * 2)

                                ForEach(viewModel.visibleHours, id: \.self) { hour in
                                    Text(hourLabel(hour))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .padding(.trailing, 6)
                                        .frame(height: rowHeight)
                                        .background(Color(UIColor.systemGray6))
                                        .padding(.vertical, rowVerticalPadding)
                                }
                            }
                            .frame(width: timeColWidth)
                            .background(Color(UIColor.systemGray6))

                            // Right side: horizontally scrolling GRID only (header is overlaid above)
                            SynchronizedHScrollView(contentOffsetX: $hScrollOffset) {
                                VStack(spacing: 0) {
                                    // Grid rows (scroll horizontally)
                                    VStack(spacing: 0) {
                                        ForEach(viewModel.visibleHours, id: \.self) { hour in
                                            HStack(spacing: columnSpacing) {
                                                ForEach(viewModel.weekDays, id: \.self) { day in
                                                    ZStack(alignment: .topLeading) {
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .fill(Color(UIColor.systemGray5))
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .stroke(Color(UIColor.systemGray3), lineWidth: 0.5)

                                                        let key = DateOnly(day)
                                                        let matchingSlots: [TrainerScheduleSlot] = {
                                                            if let slots = viewModel.slotsByDay[key] {
                                                                return slots.filter {
                                                                    Calendar.current.isDate(
                                                                        $0.startTime,
                                                                        equalTo: dateBySetting(hour: hour, on: day),
                                                                        toGranularity: .hour
                                                                    )
                                                                }
                                                            }
                                                            return []
                                                        }()

                                                        // Render events (if any)
                                                        ForEach(matchingSlots) { slot in
                                                            EventCell(slot: slot)
                                                                .padding(8)
                                                                .contentShape(Rectangle())
                                                                .onTapGesture {
                                                                    handleSlotTap(slot, defaultDay: day, defaultHour: hour)
                                                                }
                                                        }
                                                    }
                                                    .frame(width: dayColumnWidth, height: rowHeight)
                                                    .padding(.horizontal, 6)
                                                    .contentShape(Rectangle())
                                                    .onTapGesture {
                                                        // Only open editor if there is no event occupying this cell
                                                        let key = DateOnly(day)
                                                        let hasEvent = (viewModel.slotsByDay[key] ?? []).contains {
                                                            Calendar.current.isDate(
                                                                $0.startTime,
                                                                equalTo: dateBySetting(hour: hour, on: day),
                                                                toGranularity: .hour
                                                            )
                                                        }
                                                        guard !hasEvent else { return }
                                                        editorDay = day
                                                        editorHour = hour
                                                        editorShown = true
                                                    }
                                                    .contextMenu {
                                                        Button {
                                                            Task { await viewModel.setSlotStatus(on: day, hour: hour, status: .open) }
                                                        } label: {
                                                            Label("Set Available", systemImage: "checkmark.circle")
                                                        }
                                                        Button(role: .destructive) {
                                                            Task { await viewModel.setSlotStatus(on: day, hour: hour, status: .unavailable) }
                                                        } label: {
                                                            Label("Set Unavailable", systemImage: "xmark.circle")
                                                        }
                                                        Divider()
                                                        Button(role: .destructive) {
                                                            Task { await viewModel.clearSlot(on: day, hour: hour) }
                                                        } label: {
                                                            Label("Clear", systemImage: "trash")
                                                        }
                                                    }
                                                }
                                            }
                                            .padding(.vertical, rowVerticalPadding)
                                        }
                                    }
                                    .padding(.bottom, 8)
                                }
                                .padding(.leading, 6)    // match header’s leading padding
                                .padding(.trailing, 8)   // match header’s trailing padding
                            }
                        }
                        .background(Color(UIColor.systemGray6))
                    }

                    // Frozen day header row: horizontally scrolls in sync with grid, stays visible on vertical scroll
                    VStack(spacing: 0) {
                        SynchronizedHScrollView(contentOffsetX: $hScrollOffset) {
                            HStack(spacing: columnSpacing) {
                                ForEach(viewModel.weekDays, id: \.self) { day in
                                    VStack(spacing: 2) {
                                        Text(day.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                        Text(day, format: .dateTime.month(.abbreviated).day())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(width: dayColumnWidth)
                                }
                            }
                            .padding(.leading, 6)
                            .padding(.trailing, 8)
                            .padding(.vertical, gridHeaderVPad)
                        }
                        .background(Color(UIColor.systemGray6))
                        .overlay(
                            Rectangle()
                                .fill(Color(UIColor.systemGray3))
                                .frame(height: 0.5)
                                .frame(maxWidth: .infinity)
                                .alignmentGuide(.top) { d in d[.top] }
                            , alignment: .bottom
                        )

                        // Thin divider between header and grid
                        Color.clear.frame(height: 0) // placeholder if needed
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .offset(x: timeColWidth) // position over the grid area (to the right of time column)
                }

            }
            .navigationBarHidden(true)
            .task {
                viewModel.setTrainerId(auth.userId ?? "trainer_demo")
                await viewModel.loadWeek()
            }
            .onChange(of: auth.userId) { _, newValue in
                viewModel.setTrainerId(newValue ?? "trainer_demo")
            }
            .onChange(of: auth.isTrainer) { _, _ in
                Task {
                    await auth.refreshTrainerProfileIfNeeded()
                    await viewModel.loadWeek()
                }
            }
            .onChange(of: viewModel.selectedDate) { _, _ in
                Task { await viewModel.loadWeek() }
            }
            .sheet(isPresented: $editorShown) {
                AvailabilityEditorSheet(
                    defaultDay: editorDay,
                    defaultHour: editorHour,
                    onSaveSingle: { day, start, end, status in
                        Task {
                            await viewModel.setCustomSlot(on: day, startTime: start, endTime: end, status: status)
                            editorShown = false
                        }
                    },
                    onSaveOngoing: { startDate, endDate, dailyStartHour, dailyEndHour, durationMinutes in
                        Task {
                            await viewModel.openAvailability(
                                start: startDate,
                                end: endDate,
                                dailyStartHour: dailyStartHour,
                                dailyEndHour: dailyEndHour,
                                slotDurationMinutes: durationMinutes
                            )
                            editorShown = false
                        }
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showOptions) {
                ScheduleOptionsView(
                    onMyWeek: {
                        viewModel.setMode(.myWeek)
                    },
                    onMyDay: {
                        viewModel.setMode(.myDay)
                        navigateToMyDay = true
                    },
                    onAllTrainersDay: {
                        viewModel.setMode(.allTrainersDay)
                        navigateToAllTrainersDay = true
                    },
                    onSelectTrainer: { id in
                        viewModel.setMode(.trainerDay(id))
                    }
                )
                .environmentObject(auth)
                .presentationDetents([.medium, .large])
            }
            .navigationDestination(isPresented: $navigateToMyDay) {
                DayScheduleView(viewModel: viewModel)
                    .environmentObject(auth)
            }
            .navigationDestination(isPresented: $navigateToAllTrainersDay) {
                AllTrainersDayView(scheduleViewModel: viewModel)
                    .environmentObject(auth)
            }
            .sheet(isPresented: $clientSheetShown, onDismiss: {
                selectedClient = nil
            }, content: {
                if let client = selectedClient {
                    ClientDetailSheet(client: client)
                        .presentationDetents([.medium, .large])
                } else {
                    // This should rarely show now; we present after data arrives.
                    ProgressView("Loading…")
                        .padding()
                }
            })
        }
    }

    private func shiftWeek(by delta: Int) {
        let cal = Calendar.current
        if let newDate = cal.date(byAdding: .day, value: 7 * delta, to: viewModel.selectedDate) {
            withAnimation(.easeInOut) {
                viewModel.selectedDate = newDate
            }
        }
    }

    private var header: some View {
        Button {
            showOptions = true
        } label: {
            HStack(spacing: 12) {
                avatarView
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(auth.trainerDisplayName ?? "My Schedule")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if auth.isAuthenticated {
                        Text("You")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var avatarView: some View {
        if let urlString = auth.trainerPhotoURLString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Circle().fill(Color.gray.opacity(0.2))
                        .overlay(ProgressView())
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                case .failure:
                    Circle().fill(Color.gray.opacity(0.2))
                        .overlay(Image(systemName: "person.crop.circle.fill").font(.system(size: 20)).foregroundStyle(.secondary))
                @unknown default:
                    Circle().fill(Color.gray.opacity(0.2))
                }
            }
        } else {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .overlay(
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                )
        }
    }

    // MARK: - Helpers

    private func hourLabel(_ hour: Int) -> String {
        let comps = DateComponents(calendar: Calendar.current, hour: hour)
        let date = comps.date ?? Date()
        return date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
    }

    private func dateBySetting(hour: Int, on day: Date) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    private func currentTimeYOffset(for date: Date, firstHour: Int?, rowHeight: CGFloat, rowVerticalPadding: CGFloat) -> CGFloat? {
        guard let firstHour, let lastHour = viewModel.visibleHours.last else { return nil }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        guard let hour = comps.hour, let minute = comps.minute else { return nil }
        if hour < firstHour || hour > lastHour + 1 { return nil }

        let perHourHeight = rowHeight + (rowVerticalPadding * 2)
        let initialTopPadding: CGFloat = rowVerticalPadding
        let wholeHours = CGFloat(max(0, hour - firstHour))
        let fraction = CGFloat(min(max(minute, 0), 59)) / 60.0
        return initialTopPadding + (wholeHours + fraction) * perHourHeight
    }

    private func handleSlotTap(_ slot: TrainerScheduleSlot, defaultDay: Date, defaultHour: Int) {
        // If booked, show client info; else fall back to opening editor
        if slot.isBooked, let clientId = slot.clientId {
            Task {
                let fetched = try? await FirestoreService.shared.fetchClient(by: clientId)
                await MainActor.run {
                    // Always set a non-nil model before presenting
                    if let client = fetched {
                        self.selectedClient = client
                    } else {
                        self.selectedClient = Client(id: clientId, firstName: slot.clientName ?? "Booked", lastName: "", emailAddress: "", phoneNumber: "", photoURL: nil)
                    }
                    self.clientSheetShown = true
                }
            }
        } else {
            editorDay = defaultDay
            editorHour = defaultHour
            editorShown = true
        }
    }
}

private struct EventCell: View {
    let slot: TrainerScheduleSlot

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(slot.visualColor)
                .frame(width: 8, height: 8)
            Text(slot.displayTitle)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(slot.visualColor.opacity(0.08))
        )
    }
}

private struct ClientDetailSheet: View {
    let client: Client

    var body: some View {
        VStack(spacing: 16) {
            if let urlString = client.photoURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Circle().fill(Color.gray.opacity(0.2))
                            .frame(width: 72, height: 72)
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(Circle())
                    case .failure:
                        Circle().fill(Color.gray.opacity(0.2))
                            .frame(width: 72, height: 72)
                            .overlay(Image(systemName: "person.crop.circle.fill").font(.system(size: 36)).foregroundStyle(.secondary))
                    @unknown default:
                        Circle().fill(Color.gray.opacity(0.2))
                            .frame(width: 72, height: 72)
                    }
                }
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 72, height: 72)
                    .overlay(Image(systemName: "person.crop.circle.fill").font(.system(size: 36)).foregroundStyle(.secondary))
            }

            VStack(spacing: 4) {
                Text(client.fullName)
                    .font(.title3.weight(.semibold))
                if !client.emailAddress.isEmpty {
                    Text(client.emailAddress)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !client.phoneNumber.isEmpty {
                    Text(client.phoneNumber)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Helper: Synchronized horizontal scroll view using UIScrollView

private struct SynchronizedHScrollView<Content: View>: UIViewRepresentable {
    @Binding var contentOffsetX: CGFloat
    var showsIndicators: Bool = true
    let content: Content

    init(contentOffsetX: Binding<CGFloat>, showsIndicators: Bool = true, @ViewBuilder content: () -> Content) {
        self._contentOffsetX = contentOffsetX
        self.showsIndicators = showsIndicators
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = showsIndicators
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.alwaysBounceVertical = false
        scrollView.isPagingEnabled = false
        scrollView.delegate = context.coordinator

        // Host SwiftUI content
        let hosting = UIHostingController(rootView: content)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        hosting.view.backgroundColor = .clear

        scrollView.addSubview(hosting.view)

        // Constrain hosting view to scroll view's content layout
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),

            // Height matches scroll view (no vertical scrolling)
            hosting.view.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        context.coordinator.hostingController = hosting
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        // Update hosted content
        context.coordinator.hostingController?.rootView = content

        // If binding changed externally, update scroll position (without feedback loop)
        if abs(scrollView.contentOffset.x - contentOffsetX) > 0.5 {
            scrollView.setContentOffset(CGPoint(x: contentOffsetX, y: 0), animated: false)
        }
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: SynchronizedHScrollView
        weak var hostingController: UIHostingController<Content>?

        init(_ parent: SynchronizedHScrollView) {
            self.parent = parent
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // Propagate horizontal offset back to SwiftUI
            let newX = scrollView.contentOffset.x
            if abs(parent.contentOffsetX - newX) > 0.5 {
                parent.contentOffsetX = newX
            }
        }
    }
}

