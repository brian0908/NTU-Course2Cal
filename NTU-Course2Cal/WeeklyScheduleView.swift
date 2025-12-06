//
//  WeeklyScheduleView.swift
//  NTU Course2Cal
//
//  Created by Brian Lee on 12/4/25.
//

import SwiftUI
import GoogleSignInSwift
import GoogleSignIn

struct WeeklyScheduleView: View {
	@EnvironmentObject var viewModel: CourseViewModel
	@EnvironmentObject var signInManager: GoogleSignInManager
	
	@State private var showAlert = false
	@State private var alertMessage = ""
	@State private var showGoogleSheet = false
	
	// 匯入課程與設定頁的 sheet 控制
	@State private var showImportSheet = false
	@State private var showSettingsSheet = false
	
	// 點課表 cell 彈出 CourseGroupCard 用
	@State private var activeGroup: CourseGroup?
	@State private var sheetExpanded: Bool = true
	
	let days = ["一", "二", "三", "四", "五", "六"]
	let periods = Array(1...14) // 1~10, 11~14 對應 A~D
	
	var body: some View {
		NavigationStack {
			ZStack {
				Color(uiColor: .systemGray6).ignoresSafeArea()
				
				VStack {
					// 課表區
					ScrollView {
						ZStack {
							// 整個課表白底 + 圓角
							RoundedRectangle(cornerRadius: 12)
								.fill(Color(red: 229/255, green: 236/255, blue: 248/255))
								.shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
							
							Grid(horizontalSpacing: 1, verticalSpacing: 1) {
								// 表頭：星期
								GridRow {
									Color.clear.frame(width: 30, height: 30)
									ForEach(days, id: \.self) { day in
										Text(day)
											.font(.caption)
											.fontWeight(.bold)
											.frame(maxWidth: .infinity)
									}
								}
								
								// 表身：節次 + 課程
								ForEach(periods, id: \.self) { period in
									GridRow {
										// 左側節次欄
										Text(labelForPeriod(period))
											.font(.caption)
											.fontWeight(.bold)
											.frame(width: 30)
										
										// 每天該節次是否有課
										ForEach(2...7, id: \.self) { weekday in
											cellFor(weekday: weekday, period: period)
										}
									}
								}
							}
							.padding(8)
						}
						.padding()
					}
					
					// 底部匯出按鈕們
					VStack(spacing: 8) {
						// 匯出到 Apple 行事曆
						Button(action: {
							if viewModel.courses.isEmpty {
								alertMessage = "目前沒有任何課程可以匯出"
								showAlert = true
								return
							}
							
							viewModel.exportToCalendar { _, msg in
								alertMessage = msg
								showAlert = true
							}
						}) {
							HStack {
								Image(systemName: "apple.logo")
								Text("匯出至 Apple 行事曆")
									.fontWeight(.semibold)
							}
							.frame(maxWidth: .infinity)
							.padding()
							.background(Color.black)
							.foregroundColor(.white)
							.cornerRadius(10)
						}
						
						// 匯出到 Google 行事曆
						Button(action: {
							// 先檢查有沒有課
							if viewModel.courses.isEmpty {
								alertMessage = "目前沒有任何課程可以匯出"
								showAlert = true
								return
							}
							
							// 再檢查有沒有登入 Google
							if signInManager.user == nil {
								alertMessage = "請先在設定頁登入 Google 帳號"
								showAlert = true
							} else {
								showGoogleSheet = true
							}
						}) {
							HStack {
								Image("google.logo")
									.resizable()
									.scaledToFit()
									.frame(width: 18, height: 18)
								Text("匯出至 Google 行事曆")
							}
							.frame(maxWidth: .infinity)
							.fontWeight(.semibold)
							.padding()
							.background(Color.white)
							.foregroundColor(.black)
							.cornerRadius(10)
						}
					}
					.padding()
				}
			}
			.navigationTitle("我的課表")
			
			// Alert：依情境顯示不同主按鈕
			.alert("匯出結果", isPresented: $showAlert) {
				if alertMessage.contains("沒有任何課程可以匯出") {
					Button("前往匯入課程") {
						showImportSheet = true
					}
					Button("取消", role: .cancel) { }
				} else if alertMessage.contains("登入 Google 帳號") {
					Button("前往設定") {
						showSettingsSheet = true
					}
					Button("取消", role: .cancel) { }
				} else {
					Button("OK", role: .cancel) { }
				}
			} message: {
				Text(alertMessage)
			}
			
			// 匯出 Google 行事曆用的 sheet
			.sheet(isPresented: $showGoogleSheet) {
				GoogleCalendarExportSheet()
					.environmentObject(viewModel)
					.environmentObject(signInManager)
			}
			
			// 匯入課程用的 sheet
			.sheet(isPresented: $showImportSheet) {
				InputSheetView()
					.environmentObject(viewModel)
			}
			
			// 設定頁（Google 登入）用的 sheet
			.sheet(isPresented: $showSettingsSheet) {
				SettingsView()
					.environmentObject(viewModel)
					.environmentObject(signInManager)
			}
			
			// 點 cell 彈出的 CourseGroupCard sheet
			.sheet(item: $activeGroup) { group in
				NavigationStack {
					ScrollView {
						CourseGroupCard(
							group: group,
							isSelected: Binding(
								get: {
									group.indices.allSatisfy { idx in
										viewModel.courses.indices.contains(idx)
										&& viewModel.courses[idx].isSelected
									}
								},
								set: { newValue in
									for idx in group.indices where viewModel.courses.indices.contains(idx) {
										viewModel.courses[idx].isSelected = newValue
									}
								}
							),
							isExpanded: $sheetExpanded
						)
						.padding()
					}
					.navigationTitle("課程資訊")
					.toolbar {
						ToolbarItem(placement: .cancellationAction) {
							Button("關閉") {
								activeGroup = nil
							}
						}
					}
				}
			}
			
			// 設定頁登入完成後自動回到匯出畫面
			.onChange(of: signInManager.user) { oldUser, newUser in
				if newUser != nil && showSettingsSheet {
					showSettingsSheet = false
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
						if !viewModel.courses.isEmpty {
							showGoogleSheet = true
						} else {
							alertMessage = "目前沒有任何課程可以匯出"
							showAlert = true
						}
					}
				}
			}
		}
	}
	
	// 節次顯示轉換：11~14 顯示 A~D
	private func labelForPeriod(_ period: Int) -> String {
		switch period {
		case 11: return "A"
		case 12: return "B"
		case 13: return "C"
		case 14: return "D"
		default: return "\(period)"
		}
	}
	
	// 判斷該格子顯示什麼（有課就可以點，跳出 CourseGroupCard）
	@ViewBuilder
	private func cellFor(weekday: Int, period: Int) -> some View {
		if let match = viewModel.courses.first(where: { $0.weekday == weekday && $0.periods.contains(period) }) {
			Rectangle()
				.fill(Color(red: 0/255, green: 75/255, blue: 151/255).opacity(0.8))
				.overlay(
					Text(match.name.prefix(15))
						.font(.caption2)
						.foregroundColor(.white)
						.multilineTextAlignment(.center)
						.padding(2)
				)
				.frame(height: 50)
				.cornerRadius(5)
				.contentShape(Rectangle())
				.onTapGesture {
					if let group = groupForCell(weekday: weekday, period: period) {
						sheetExpanded = true
						activeGroup = group
					}
				}
		} else {
			Rectangle()
				.fill(Color.white)
				.overlay(
					Rectangle()
						.stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
				)
				.frame(height: 50)
				.cornerRadius(5)
		}
	}
	
	// 找出該 cell 對應的 CourseGroup（邏輯跟 MyCoursesView 一致）
	private func groupForCell(weekday: Int, period: Int) -> CourseGroup? {
		guard let base = viewModel.courses.first(where: {
			$0.weekday == weekday && $0.periods.contains(period)
		}) else {
			return nil
		}
		
		let key = base.name + "|" + base.teacher + "|" + base.location + "|" + base.rawTime
		
		let indices: [Int] = viewModel.courses.enumerated().compactMap { (idx, c) in
			let k = c.name + "|" + c.teacher + "|" + c.location + "|" + c.rawTime
			return (k == key) ? idx : nil
		}
		
		return CourseGroup(
			id: key,
			name: base.name,
			teacher: base.teacher,
			location: base.location,
			rawTime: base.rawTime,
			credits: base.credits,
			notes: base.notes,
			indices: indices
		)
	}
}
