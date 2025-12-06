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
			.environmentObject(signInManager)   // 這一行很關鍵
		}
	}
}
struct MainTabView: View {
	var body: some View {
		TabView {
			MyCoursesView()
				.tabItem {
					Label("我的課程", systemImage: "books.vertical")
				}
			
			WeeklyScheduleView()
				.tabItem {
					Label("課表檢視", systemImage: "calendar")
				}
			
			SettingsView()
				.tabItem {
					Label("設定", systemImage: "gearshape")
				}
		}
		.tint(.ntuBlue)
	}
}




#Preview {
	MainTabView()
		.environmentObject(CourseViewModel())
		.environmentObject(GoogleSignInManager())
}
