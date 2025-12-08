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
import UserNotifications

struct SettingsView: View {
	@State private var showingResetAllConfirm = false
	@EnvironmentObject var viewModel: CourseViewModel
	@EnvironmentObject var signInManager: GoogleSignInManager
	@AppStorage("appLanguage") var appLanguage: String = "zh-Hant"
	@State private var showingClearConfirm = false
	@State private var showingArchiveConfirm = false
	@AppStorage("enableLocalNotifications") private var enableLocalNotifications: Bool = false
	private let calendarNotifyOptions: [Int] = [0, 5, 10, 15, 30, 60]
	private var calendarNotificationSection: some View {
		Section("行事曆通知") {
			Picker("行事曆提醒時間", selection: $viewModel.notifyMinutesBeforeCalendar) {
				ForEach(calendarNotifyOptions, id: \.self) { minutes in
					if minutes == 0 {
						Text("不提醒").tag(minutes)
					} else {
						Text("提前 \(minutes) 分鐘").tag(minutes)
					}
				}
			}
			.pickerStyle(.menu)   // 顯示成下拉式選單
			
			// 補充說明文字
			Text("會用在匯出到行事曆的事件提醒。")
				.font(.footnote)
				.foregroundColor(.secondary)
		}
	}
	private var appNotificationSection: some View {
		Section("App 通知提醒") {
			Toggle("啟用 App 通知", isOn: $enableLocalNotifications)
				.onChange(of: enableLocalNotifications) { _, newValue in
					if newValue {
						viewModel.requestNotificationAuthorization()
						viewModel.rescheduleAllClassNotifications()
					} else {
						UNUserNotificationCenter.current()
							.removeAllPendingNotificationRequests()
					}
				}
			
			Stepper("App 通知提前 \(viewModel.notifyMinutesBeforeLocal) 分鐘提醒",
					value: $viewModel.notifyMinutesBeforeLocal,
					in: 0...120,
					step: 5)
			
			Button("重新排程本學期所有 App 通知") {
				viewModel.rescheduleAllClassNotifications()
			}
			.disabled(!enableLocalNotifications)
		}
	}
	
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
						Text("目前尚未建立學期")
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
						.fontWeight(.semibold)
					}
					
					// 建立新學期
					NavigationLink {
						NewSemesterView()
							.environmentObject(viewModel)
					} label: {
						HStack {
							Image(systemName: "plus.circle.fill")
							Text("建立新學期")
								.fontWeight(.semibold)
						}
						.frame(maxWidth: .infinity, alignment: .center)
					}
					.foregroundColor(.white)
					.listRowBackground(
						Color(red: 0/255, green: 75/255, blue: 151/255)
						
					)
					
					if viewModel.currentSemesterId != nil {
						Button {
							showingArchiveConfirm = true
						} label: {
							HStack {
								Image(systemName: "archivebox.fill")
								Text("將目前學期移至歷史課程")
									.fontWeight(.semibold)
									.font(.caption)
							}
						}
						.foregroundColor(.white)
						.listRowBackground(Color(red: 191/255, green: 10/255, blue: 30/255))
						.fontWeight(.semibold)
						.frame(maxWidth: .infinity, alignment: .center)
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
							Button {
								Task {
									_ = await viewModel.loadGoogleCalendars(using: signInManager)
								}
							} label: {
								HStack {
									Image(systemName: "calendar.badge.plus")
									Text("載入我的日曆")
										.fontWeight(.semibold)
								}
							}.fontWeight(.semibold)
								.foregroundColor(.white)
								.listRowBackground(
									Color(red: 0/255, green: 75/255, blue: 151/255))
								.frame(maxWidth: .infinity, alignment: .center)
							
						} else {
							// 選擇要匯入的日曆
							Picker("預設匯入日曆", selection: $viewModel.selectedCalendarId) {
								ForEach(viewModel.googleCalendars) { cal in
									Text(cal.summary)
										.tag(cal.id)
								}
							}
						}
						
						Button {
							signInManager.signOut()
							viewModel.googleCalendars = []
							viewModel.selectedCalendarId = "primary"
						} label: {
							HStack {
								Image(systemName: "rectangle.portrait.and.arrow.right")
								Text("登出 Google")
									.fontWeight(.semibold)
							}
						}
						.foregroundColor(.white)
						.listRowBackground(Color(red: 191/255, green: 10/255, blue: 30/255))
						.fontWeight(.semibold)
						.frame(maxWidth: .infinity, alignment: .center)
					} else {
						GoogleSignInButton {
							let vc = rootViewController()
							signInManager.signIn(presenting: vc)
						}
						.frame(height: 44)
					}
				}
				
				// 行事曆通知：改成下拉選單
				Section("行事曆通知") {
					Picker("行事曆提醒時間", selection: $viewModel.notifyMinutesBeforeCalendar) {
						ForEach(calendarNotifyOptions, id: \.self) { minutes in
							if minutes == 0 {
								Text("不提醒").tag(minutes)
							} else {
								Text("提前 \(minutes) 分鐘通知").tag(minutes)
							}
						}
					}.fontWeight(.semibold)
					.pickerStyle(.menu)
					
					Text("這裡只影響匯出到 Apple 行事曆事件的提醒時間。")
						.font(.footnote)
						.foregroundColor(.secondary)
				}

				// App 通知提醒：保留 Stepper，獨立設定
				Section("App 通知提醒") {
					Toggle("啟用 App 通知", isOn: $enableLocalNotifications)
						.onChange(of: enableLocalNotifications) { _, newValue in
							if newValue {
								viewModel.requestNotificationAuthorization()
								viewModel.rescheduleAllClassNotifications()
							} else {
								UNUserNotificationCenter.current()
									.removeAllPendingNotificationRequests()
							}
						}.fontWeight(.semibold)
									
					// 顯示目前設定值，顏色用 ntuBlue
					VStack(alignment: .leading, spacing: 4) {
						Text("上課前提醒時間")
							.font(.subheadline)
							.foregroundColor(.secondary)
						
						Text("\(viewModel.notifyMinutesBeforeLocal) 分鐘前")
							.font(.title3.bold())
							.foregroundColor(.ntuBlue)
					}
					.padding(.vertical, 4)
					
					// Stepper 控制數值
					Stepper(
						"調整提醒時間",
						value: $viewModel.notifyMinutesBeforeLocal,
						in: 0...120,
						step: 5
					).fontWeight(.semibold)
					
					
					Button("重新排程本學期所有 App 通知") {
						viewModel.rescheduleAllClassNotifications()
					}
					.disabled(!enableLocalNotifications)
					.fontWeight(.semibold)
					.frame(maxWidth: .infinity, alignment: .center)
					.foregroundColor(.ntuBlue)
				}
				
				Section(header: Text("語言 | Language")) {
					Picker("App Language", selection: $appLanguage) {
						Text("中文").tag("zh-Hant")
						Text("English").tag("en")
					}
					.pickerStyle(.segmented)
					.onChange(of: appLanguage) { _, _ in
						AppLanguageManager.reloadApp(
							viewModel: viewModel,
							signInManager: signInManager
						)
					}
				}
				
				Section {
					Button {
						showingResetAllConfirm = true
					} label: {
						HStack {
							Image(systemName: "trash.fill")
							Text("清除全部資料")
								.fontWeight(.semibold)
						}
					}
					.foregroundColor(.white)
					.listRowBackground(Color(red: 191/255, green: 10/255, blue: 30/255))
					.frame(maxWidth: .infinity, alignment: .center)
				}
				.alert("確定要清除全部資料嗎？", isPresented: $showingResetAllConfirm) {
					Button("清除", role: .destructive) {
						viewModel.resetAllData()
					}
					Button("取消", role: .cancel) { }
				} message: {
					Text("包含目前學期與歷史課程的所有資料都會被刪除，此動作無法復原。")
				}
				
				
			}
			
			.navigationTitle("nav_settings_title")
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

