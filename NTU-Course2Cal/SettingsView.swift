//
//  SettingsView.swift
//  NTU Course2Cal
//
//  Created by Brian Lee on 12/4/25.
//

import SwiftUI
import GoogleSignIn
import GoogleSignInSwift
import UIKit

struct SettingsView: View {
	@EnvironmentObject var viewModel: CourseViewModel
	@EnvironmentObject var signInManager: GoogleSignInManager
	@State private var showingClearConfirm = false
	@State private var showingArchiveConfirm = false
	
	var body: some View {
		NavigationStack {
			Form {
				Section("學期管理") {
					// 顯示目前學期
					if let currentId = viewModel.currentSemesterId,
					   let sem = viewModel.semesters.first(where: { $0.id == currentId }) {
						Text("目前學期：\(sem.name)")
							.font(.headline)
							.fontWeight(.semibold)
							.foregroundColor(.ntuBlue)
					} else {
						Text("目前尚未選擇學期")
							.font(.subheadline)
							.foregroundColor(.secondary)
					}
					
					// 列出所有 active 學期讓使用者切換
					if !viewModel.activeSemesters.isEmpty {
						Picker("切換學期", selection: Binding(
							get: { viewModel.currentSemesterId },
							set: { newId in
								if let id = newId {
									viewModel.switchSemester(to: id)
								}
							}
						)) {
							ForEach(viewModel.activeSemesters) { sem in
								Text(sem.name).tag(Optional(sem.id))
							}
						}
					}
					
					// 建立新學期
					NavigationLink("建立新學期") {
						NewSemesterView()
							.environmentObject(viewModel)
					}.fontWeight(.semibold)
						.foregroundColor(.ntuBlue)
					
					if viewModel.currentSemesterId != nil {
						Button("將目前學期移至歷史課程") {
							showingArchiveConfirm = true
						}
						.foregroundColor(.red)
						.fontWeight(.semibold)
						.alert("確定要將本學期移至歷史課程嗎？", isPresented: $showingArchiveConfirm) {
							Button("移至歷史課程", role: .destructive) {
								viewModel.archiveCurrentSemester()
							}
							Button("取消", role: .cancel) { }
						} message: {
							Text("此動作無法復原，且課程將不可再編輯。")
					}
					}
				}
				// 原本的學期設定
				Section(header: Text("日期設定")) {
					DatePicker("本學期開學第一天",
							   selection: $viewModel.startDate,
							   displayedComponents: .date)
					.tint(Color(red: 0/255, green: 75/255, blue: 151/255))
					.fontWeight(.semibold)
					
					Text("請設定本學期第一週的「星期一」日期。\nApp 會根據此日期自動推算所有課程的實際上課日。")
						.font(.caption)
						.foregroundColor(.gray)
				}
				
				// Google Calendar 區
				Section(header: Text("Google 行事曆設定")) {
					if let user = signInManager.user {
						HStack {
							Text("已登入")
								.fontWeight(.semibold)
							Spacer()
							Text(user.profile?.email ?? "")
								.foregroundColor(.secondary)
						}
						
						// 載入日曆列表按鈕
						if viewModel.googleCalendars.isEmpty {
							Button("載入我的日曆") {
								Task {
									_ = await viewModel.loadGoogleCalendars(using: signInManager)
								}
							}.fontWeight(.semibold)
						} else {
							// 選擇要匯入的日曆
							Picker("預設匯入日曆", selection: $viewModel.selectedCalendarId) {
								ForEach(viewModel.googleCalendars) { cal in
									Text(cal.summary)
										.tag(cal.id)
								}
							}
						}
						
						Button("登出 Google") {
							signInManager.signOut()
							viewModel.googleCalendars = []
							viewModel.selectedCalendarId = "primary"
						}
						.foregroundColor(.red)
						.fontWeight(.semibold)
					} else {
						GoogleSignInButton {
							let vc = rootViewController()
							signInManager.signIn(presenting: vc)
						}
						.frame(height: 44)
					}
				}
				
				// 通知設定與清除資料照舊
				Section(header: Text("通知設定")) {
					Picker("上課前提醒", selection: $viewModel.notifyMinutesBefore) {
						Text("不提醒").tag(0)
						Text("10 分鐘前").tag(10)
						Text("30 分鐘前").tag(30)
						Text("1 小時前").tag(60)
					}.fontWeight(.semibold)
				}
				
				Section {
					Button("清除 App 內儲存所有課程資料", role: .destructive) {
						showingClearConfirm = true
					}
					.fontWeight(.bold)
					.frame(maxWidth: .infinity, alignment: .center)
					
				}
				.alert("確定要清除所有課程嗎？", isPresented: $showingClearConfirm) {
					Button("清除", role: .destructive) {
						viewModel.clearCourses()
					}
					Button("取消", role: .cancel) { }
				} message: {
					Text("此動作無法復原。")
				}
			}
			.navigationTitle("設定")
		}
	}
}

// 取得 rootViewController，給 GoogleSignIn 用
func rootViewController() -> UIViewController {
	guard
		let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
		let window = scene.windows.first,
		let root = window.rootViewController
	else {
		fatalError("Cannot find root view controller")
	}
	return root
}
