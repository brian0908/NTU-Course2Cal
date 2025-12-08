//
//  NTU_Course2CalApp.swift
//  NTU Course2Cal
//
//  Created by Brian Lee on 12/4/25.
//

import SwiftUI

@main
struct NTU_Course2CalApp: App {

	@AppStorage("hasCompletedPermissionFlow") private var hasCompletedPermissionFlow = false
	@StateObject var viewModel = CourseViewModel()
	@StateObject var signInManager = GoogleSignInManager()
	@AppStorage("appLanguage") var appLanguage: String = "zh-Hant"

	var body: some Scene {
		WindowGroup {
			Group {
				if hasCompletedPermissionFlow {
					MainTabView()
				} else {
					PermissionIntroView()
				}
			}
			.environmentObject(viewModel)
			.environmentObject(signInManager)
			.environment(\.locale, Locale(identifier: appLanguage))
		}
	}
}
struct MainTabView: View {
	var body: some View {
		TabView {
			MyCoursesView()
				.tabItem {
					Label("tab_my_courses", systemImage: "books.vertical")
				}
			
			WeeklyScheduleView()
				.tabItem {
					Label("tab_weekly_schedule", systemImage: "calendar")
				}
			
			HistoryCoursesView()
				.tabItem {
					Label("tab_history_courses", systemImage: "clock.arrow.circlepath")
				}
			
			SettingsView()
				.tabItem {
					Label("tab_settings", systemImage: "gearshape")
				}
		}
		.tint(.ntuBlue)
	}
}

#Preview{
	MainTabView()
		.environmentObject(CourseViewModel())
		.environmentObject(GoogleSignInManager())
}



