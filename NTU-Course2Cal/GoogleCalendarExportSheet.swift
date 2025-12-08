//
//  GoogleCalendarExportSheet.swift
//  NTU-Course2Cal
//
//  Created by Brian Lee on 12/6/25.
//  Updated for 2 step UI
//

import SwiftUI

struct GoogleCalendarExportSheet: View {
	@Environment(\.dismiss) var dismiss
	@EnvironmentObject var viewModel: CourseViewModel
	@EnvironmentObject var signInManager: GoogleSignInManager
	
	@State private var calendars: [GoogleCalendarInfo] = []
	@State private var selectedCalendarId: String = "primary"
	
	@State private var newCalendarName: String = ""
	@State private var isLoading = false
	@State private var isCreating = false
	@State private var isExporting = false
	
	@State private var alertMessage = ""
	@State private var showAlert = false
	
	var body: some View {
		NavigationStack {
			Form {
				if isLoading {
					ProgressView("讀取 Google 行事曆中...")
				} else {
					// Step 1: 建立新行事曆 (Optional)
					Section(header: Text("Step 1: 建立新行事曆 (Optional)")) {
						TextField("例如 114-1 課表", text: $newCalendarName)
						
						Button {
							Task {
								await createCalendar()
							}
						} label: {
							HStack {
								Spacer()
								if isCreating {
									ProgressView()
								} else {
									Image(systemName: "plus.circle.fill")
								}
								Text(isCreating ? "建立中..." : "建立新行事曆")
									.fontWeight(.bold)
								Spacer()
							}
						}
						.disabled(newCalendarName.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
						.foregroundColor(.white)
						.listRowBackground(
							Color(red: 0/255, green: 75/255, blue: 151/255)
						)
					}
					
					// Step 2: 選擇匯入的行事曆
					Section(header: Text("Step 2: 選擇匯入的行事曆")) {
						if calendars.isEmpty {
							Text("找不到任何 Google 行事曆")
								.foregroundColor(.secondary)
						} else {
							Picker("行事曆", selection: $selectedCalendarId) {
								ForEach(calendars) { cal in
									Text(cal.summary)
										.tag(cal.id)
								}
							}
						}
					}
					
					// 匯出按鈕
					Section {
						Button {
							Task {
								await doExport()
							}
						} label: {
							HStack {
								Spacer()
								if isExporting {
									ProgressView()
								} else {
									Image(systemName: "sparkles")
								}
								Text(isExporting ? "匯出中..." : "匯出目前勾選的課程")
									.fontWeight(.bold)
								Spacer()
							}
						}
						.disabled(isExporting || calendars.isEmpty)
						.foregroundColor(.white)
						.listRowBackground(
							Color.ntuBlue
						)
					}
				}
			}
			.navigationTitle("匯出到 Google 行事曆")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("關閉") {
						dismiss()
					}
				}
			}
			.task {
				await loadCalendars()
			}
			.alert("匯出結果", isPresented: $showAlert) {
				if alertMessage.contains("登入") || alertMessage.contains("行事曆失敗") {
					// 登入相關錯誤, 要求重新登入
					Button("重新登入") {
						signInManager.signOut()
						dismiss()
					}
					Button("取消", role: .cancel) {
						dismiss()
					}
				} else {
					Button("OK") {
						// 匯出成功的情況直接關閉
						if alertMessage.contains("已匯出") {
							dismiss()
						}
					}
				}
			} message: {
				Text(alertMessage)
			}
		}
	}
	
	// MARK: - 載入 Google 行事曆列表
	private func loadCalendars() async {
		await MainActor.run { isLoading = true }
		
		// 如果一開始就沒有 user，直接噴錯並請他重登
		guard signInManager.user != nil else {
			await MainActor.run {
				isLoading = false
				alertMessage = "建立行事曆失敗，請確認已登入，再重新登入一次 Google 帳號。"
				showAlert = true
			}
			return
		}
		
		let list = await viewModel.fetchGoogleCalendars(using: signInManager)
		
		await MainActor.run {
			if list.isEmpty {
				alertMessage = "建立行事曆失敗，請確認已登入，再重新登入一次 Google 帳號。"
				showAlert = true
			} else {
				self.calendars = list
				if let primary = list.first(where: { $0.primary == true }) {
					self.selectedCalendarId = primary.id
				} else {
					self.selectedCalendarId = list.first?.id ?? "primary"
				}
			}
			isLoading = false
		}
	}
	
	// MARK: - 建立新 Google 行事曆
	private func createCalendar() async {
		let trimmed = newCalendarName.trimmingCharacters(in: .whitespaces)
		guard !trimmed.isEmpty else { return }
		
		isCreating = true
		let result = await viewModel.createGoogleCalendar(named: trimmed, using: signInManager)
		
		await MainActor.run {
			self.isCreating = false
			if let newCal = result {
				// 加入本地列表並選取
				self.calendars.append(newCal)
				self.selectedCalendarId = newCal.id
				self.newCalendarName = ""
				self.alertMessage = "已建立行事曆「\(trimmed)」"
				self.showAlert = true
			} else {
				self.alertMessage = "建立行事曆失敗，請確認已登入 Google 並允許行事曆權限"
				self.showAlert = true
			}
		}
	}
	
	// MARK: - 匯出課程到選定的 Google Calendar
	private func doExport() async {
		guard !selectedCalendarId.isEmpty else {
			await MainActor.run {
				alertMessage = "尚未選擇行事曆"
				showAlert = true
			}
			return
		}
		
		isExporting = true
		let (_, msg) = await viewModel.exportToGoogleCalendar(
			using: signInManager,
			calendarID: selectedCalendarId
		)
		
		await MainActor.run {
			self.isExporting = false
			self.alertMessage = msg
			self.showAlert = true
		}
	}
}
