//
//  ContentView.swift
//  PolyCal
//
//  Created by Matthew Sprague on 10/12/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ScheduleView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Schedule")
                }

            ClientsView()
                .tabItem {
                    Image(systemName: "person.2")
                    Text("Clients")
                }

            MoreView()
                .tabItem {
                    Image(systemName: "ellipsis.circle")
                    Text("More")
                }
        }
    }
}

struct MoreView: View {
    var body: some View {
        NavigationStack {
            Text("More")
                .navigationTitle("More")
        }
    }
}

#Preview {
    ContentView()
}
