//
//  AppleCalendarExportSheet.swift
//  NTU-Course2Cal
//
//  Created by Brian Lee on 12/7/25.
//


import SwiftUI
import EventKit

struct AppleCalendarExportSheet: View {
	@Environment(\.dismiss) var dismiss
	@EnvironmentObject var viewModel: CourseViewModel
	
	@State private var calendars: [EKCalendar] = []
	@State private var selectedCalendarId: String = ""
	
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
					ProgressView("讀取 Apple 行事曆中...")
				} else {
					// Step 1: 建立新行事曆 (Optional)
					Section(header: Text("Step 1: 建立新行事曆 (Optional)")) {
						TextField("例如：114-1 課表", text: $newCalendarName)
						
						Button {
							createCalendar()
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
							Text("找不到可寫入的 Apple 行事曆")
								.foregroundColor(.secondary)
						} else {
							Picker("行事曆", selection: $selectedCalendarId) {
								ForEach(calendars, id: \.calendarIdentifier) { cal in
									Text(cal.title)
										.tag(cal.calendarIdentifier)
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
			.navigationTitle("匯出到 Apple 行事曆")
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
				Button("OK") {
					// 匯出成功時順便關掉 sheet
					if alertMessage.contains("成功") {
						dismiss()
					}
				}
			} message: {
				Text(alertMessage)
			}
		}
	}
	
	// MARK: - 載入行事曆
	private func loadCalendars() async {
		isLoading = true
		await withCheckedContinuation { continuation in
			viewModel.loadAppleCalendars { success, msg in
				self.calendars = viewModel.appleCalendars
				self.selectedCalendarId = viewModel.appleTargetCalendarId
				self.isLoading = false
				
				if !success {
					self.alertMessage = msg
					self.showAlert = true
				}
				continuation.resume()
			}
		}
	}
	
	// MARK: - 建立新行事曆
	private func createCalendar() {
		let trimmed = newCalendarName.trimmingCharacters(in: .whitespaces)
		guard !trimmed.isEmpty else { return }
		
		isCreating = true
		viewModel.createAppleCalendar(named: trimmed) { success, msg in
			Task { @MainActor in
				self.isCreating = false
				self.alertMessage = msg
				self.showAlert = true
				
				// 重新載入列表
				self.calendars = viewModel.appleCalendars
				self.selectedCalendarId = viewModel.appleTargetCalendarId
				self.newCalendarName = ""
			}
		}
	}
	
	// MARK: - 匯出
	private func doExport() async {
		guard !selectedCalendarId.isEmpty else {
			alertMessage = "尚未選擇行事曆"
			showAlert = true
			return
		}
		
		// 設定目標行事曆
		viewModel.setAppleTargetCalendar(id: selectedCalendarId)
		isExporting = true
		await withCheckedContinuation { continuation in
			viewModel.exportToCalendar { success, msg in
				Task { @MainActor in
					self.isExporting = false
					self.alertMessage = msg
					self.showAlert = true
					continuation.resume()
				}
			}
		}
	}
}
