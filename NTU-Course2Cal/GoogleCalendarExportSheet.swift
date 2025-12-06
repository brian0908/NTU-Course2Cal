//
//  GoogleCalendarExportSheet.swift
//  NTU Course2Cal
//
//  Created by Brian Lee on 12/6/25.
//

import SwiftUI

struct GoogleCalendarExportSheet: View {
	@Environment(\.dismiss) private var dismiss          // 用來關閉 sheet
	@EnvironmentObject var viewModel: CourseViewModel
	@EnvironmentObject var signInManager: GoogleSignInManager
	
	@State private var calendars: [GoogleCalendarInfo] = []
	@State private var selectedCalendarID: String?
	@State private var isLoading = false
	@State private var isExporting = false
	@State private var alertMessage = ""
	@State private var showAlert = false
	
	// 新增行事曆用
	@State private var newCalendarName: String = ""
	@State private var isCreatingCalendar = false
	
	var body: some View {
		NavigationStack {
			Form {
				if isLoading {
					ProgressView("讀取 Google 行事曆中...")
				} else {
					// 建立新行事曆
					Section(header: Text("Step 1: 建立新行事曆 (Optional)")) {
						TextField("新行事曆名稱 (e.g. 114-2 課表)", text: $newCalendarName)
						
						Button {
							Task {
								await createNewCalendar()
							}
						} label: {
							if isCreatingCalendar {
								ProgressView()
							} else {
								Text("建立並選取這個行事曆")
							}
						}
						.disabled(newCalendarName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreatingCalendar)
					}
					
					// 選擇既有行事曆
					Section(header: Text("Step 2: 選擇匯入的行事曆")) {
						if calendars.isEmpty {
							Text("找不到任何 Google 行事曆")
								.foregroundColor(.secondary)
						} else {
							Picker("行事曆", selection: Binding(
								get: { selectedCalendarID ?? calendars.first?.id ?? "primary" },
								set: { selectedCalendarID = $0 }
							)) {
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
							if isExporting {
								ProgressView()
							} else {
								Text("匯出目前勾選的課程")
							}
						}
						.disabled(isExporting || calendars.isEmpty)
					}
				}
			}
			.navigationTitle("匯出到 Google 行事曆")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("關閉") {
						dismiss()       // 直接關閉 sheet
					}
				}
			}
			.task {
				await loadCalendars()
			}
			.alert("匯出結果", isPresented: $showAlert) {
				Button("OK", role: .cancel) { }
			} message: {
				Text(alertMessage)
			}
		}
	}
	
	// 讀取使用者的 Google 行事曆列表
	private func loadCalendars() async {
		isLoading = true
		
		let list = await viewModel.fetchGoogleCalendars(using: signInManager)
		
		await MainActor.run {
			self.calendars = list
			if let primary = list.first(where: { $0.primary == true }) {
				self.selectedCalendarID = primary.id
			} else {
				self.selectedCalendarID = list.first?.id
			}
			self.isLoading = false
		}
	}
	
	// 建立新行事曆
	private func createNewCalendar() async {
		let name = newCalendarName.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !name.isEmpty else { return }
		
		isCreatingCalendar = true
		
		if let newCal = await viewModel.createGoogleCalendar(named: name, using: signInManager) {
			await MainActor.run {
				// 加到列表並選取
				self.calendars.append(newCal)
				self.selectedCalendarID = newCal.id
				self.newCalendarName = ""
				self.isCreatingCalendar = false
				self.alertMessage = "已建立行事曆「\(newCal.summary)」"
				self.showAlert = true
			}
		} else {
			await MainActor.run {
				self.isCreatingCalendar = false
				self.alertMessage = "建立行事曆失敗，請稍後再試"
				self.showAlert = true
			}
		}
	}
	
	// 匯出課程到選定行事曆
	private func doExport() async {
		guard let calendarID = selectedCalendarID ?? calendars.first?.id else {
			await MainActor.run {
				alertMessage = "尚未選擇行事曆"
				showAlert = true
			}
			return
		}
		
		isExporting = true
		
		let (success, msg) = await viewModel.exportToGoogleCalendar(
			using: signInManager,
			calendarID: calendarID
		)
		
		await MainActor.run {
			self.alertMessage = msg
			self.showAlert = true
			self.isExporting = false
			
			// ★ 自動關閉 sheet
			if success {
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
					dismiss()
				}
			}
		}
	}
}
