//
//  MyCoursesView.swift
//  NTU Course2Cal
//
//  Created by Brian Lee on 12/4/25.
//

import SwiftUI

struct CourseGroup: Identifiable {
	let id: String
	let name: String
	let teacher: String
	let location: String
	let rawTime: String
	let credits: Int?
	let notes: String
	let indices: [Int]      // 這個 group 底下有哪些 Course 的 index
}

struct MyCoursesView: View {
	@EnvironmentObject var viewModel: CourseViewModel
	@State private var showInputSheet = false
	@State private var expandedGroupId: String? = nil   // 控制哪一張卡片展開

	// 依課名 + 老師 + 地點 + rawTime 合併成一個 group
	private var groupedCourses: [CourseGroup] {
		let dict = Dictionary(grouping: viewModel.courses) { course in
			course.name + "|" + course.teacher + "|" + course.location + "|" + course.rawTime
		}
		
		return dict.map { key, list in
			guard let first = list.first else {
				return CourseGroup(
					id: key,
					name: "",
					teacher: "",
					location: "",
					rawTime: "",
					credits: nil,
					notes: "",
					indices: []
				)
			}
			
			// 把這個 group 裡每個 course 在 viewModel.courses 的 index 抓出來
			let indices = list.compactMap { course in
				viewModel.courses.firstIndex(of: course)
			}
			
			return CourseGroup(
				id: key,
				name: first.name,
				teacher: first.teacher,
				location: first.location,
				rawTime: first.rawTime,
				credits: first.credits,
				notes: first.notes,
				indices: indices
			)
		}
		.sorted { $0.name < $1.name }
	}
	
	var body: some View {
		NavigationStack {
			ZStack {
				Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
				
				if viewModel.courses.isEmpty {
					VStack(spacing: 20) {
						Image(systemName: "doc.on.clipboard")
							.font(.system(size: 60))
							.foregroundColor(.gray)
						Text("尚未匯入課程")
							.font(.title3)
							.foregroundColor(.secondary)
						Button("貼上課表") { showInputSheet = true }
							.buttonStyle(.glassProminent)
							.fontWeight(.semibold)
					}
				} else {
					ScrollView {
						LazyVStack(spacing: 16) {
							ForEach(groupedCourses) { group in
								// 這裡用 Binding 控制這個 group 底下所有課程的 isSelected
								CourseGroupCard(
									group: group,
									isSelected: Binding(
										get: {
											// 防呆：確保 index 在合法範圍內
											let validIndices = group.indices.filter { $0 < viewModel.courses.count }
											guard !validIndices.isEmpty else { return false }
											return validIndices.allSatisfy { idx in
												viewModel.courses[idx].isSelected
											}
										},
										set: { newValue in
											let validIndices = group.indices.filter { $0 < viewModel.courses.count }
											for idx in validIndices {
												viewModel.courses[idx].isSelected = newValue
											}
										}
									),
									isExpanded: Binding(
										get: { expandedGroupId == group.id },
										set: { newVal in
											expandedGroupId = newVal ? group.id : nil
										}
									)
								)
							}
						}
						.padding()
					}
				}
			}
			.navigationTitle("我的課程")
			.toolbar {
				Button(action: { showInputSheet = true }) {
					Image(systemName: "plus")
				}
			}
			.sheet(isPresented: $showInputSheet) {
				InputSheetView()
					.environmentObject(viewModel)
			}
		}
	}
}

struct CourseGroupCard: View {
	let group: CourseGroup
	@Binding var isSelected: Bool
	@Binding var isExpanded: Bool
	
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack {
				VStack(alignment: .leading, spacing: 5) {
					Text(group.name)
						.font(.headline)
						.foregroundColor(Color(red: 0/255, green: 75/255, blue: 151/255))
					
					Text(group.teacher)
						.font(.subheadline)
						.foregroundColor(.secondary)
					
					Label(group.location, systemImage: "location")
						.font(.caption)
						.foregroundColor(.gray)
					
					if let credits = group.credits {
						Label(" \(credits) 學分", systemImage: "book.closed")
							.font(.caption)
							.foregroundColor(.secondary)
					}
				}
				
				Spacer()
				
				VStack(alignment: .trailing, spacing: 6) {
					Text(group.rawTime)
						.fontWeight(.bold)
						.padding(5)
						.foregroundColor(Color(red: 0/255, green: 75/255, blue: 151/255))
						.background(Color(red: 229/255, green: 236/255, blue: 248/255))
						.cornerRadius(5)
					
					Toggle("匯入", isOn: $isSelected)
						.labelsHidden()
						.scaleEffect(0.8)
				}
			}
			
			// 展開按鈕
			Button {
				withAnimation(.easeInOut) {
					isExpanded.toggle()
				}
			} label: {
				Image(systemName: "chevron.up")
					.font(.caption)
					.rotationEffect(.degrees(isExpanded ? 0 : 180))
					.foregroundColor(Color(red: 0/255, green: 75/255, blue: 151/255))
			}
			.buttonStyle(.plain)
			
			if isExpanded {
				VStack(alignment: .leading, spacing: 6) {
					
					// 上課時間
					let lines = timeLines(for: group.rawTime)
					if !lines.isEmpty {
						Divider().padding(.vertical, 4)
						Text("上課時間")
							.font(.caption)
							.fontWeight(.bold)
						ForEach(lines, id: \.self) { line in
							Text(line)
								.font(.caption)
								.foregroundColor(.secondary)
								.fixedSize(horizontal: false, vertical: true)
						}
					}
					
					// 備註
					if !group.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
						Divider().padding(.vertical, 4)
						Text("備註")
							.font(.caption)
							.fontWeight(.bold)
						Text(group.notes)
							.font(.caption)
							.foregroundColor(.secondary)
							.fixedSize(horizontal: false, vertical: true)
					}
				}
				.transition(.opacity.combined(with: .slide))
			}
		}
		.padding()
		.background(Color.white)
		.cornerRadius(12)
		.shadow(radius: 2)
	}
}

// 將 rawTime 轉成多行時間說明
// 例如 "一 1,2 / 三 5,6"
// -> ["一 1 ~ 2 節（08:10 ~ 10:00）", "三 5 ~ 6 節（12:20 ~ 13:50）"]
private func timeLines(for rawTime: String) -> [String] {
	let segments = rawTime
		.components(separatedBy: "/")
		.map { $0.trimmingCharacters(in: .whitespaces) }
		.filter { !$0.isEmpty }
	
	return segments.compactMap { formatTimeSegment($0) }
}

// 處理單一片段，例如 "一 1,2" 或 "五 A,B,C,D"
private func formatTimeSegment(_ segment: String) -> String? {
	let parts = segment.components(separatedBy: .whitespaces)
	guard parts.count >= 2 else { return nil }
	
	let dayToken = parts[0]               // 一、二、三...
	let periodToken = parts.last!         // "1,2" 或 "A,B,C,D"
	
	let periods = parsePeriods(from: periodToken)
	guard !periods.isEmpty else { return nil }
	
	let sorted = periods.sorted()
	let firstPeriod = sorted.first!
	let lastPeriod = sorted.last!
	
	let startTimeStr = getStartTime(for: firstPeriod)
	let endTimeStr = getEndTime(for: lastPeriod)   // 用你剛定義的查表函數
	
	let periodRangeText: String
	if firstPeriod == lastPeriod {
		periodRangeText = "\(displayPeriod(firstPeriod)) 節"
	} else {
		periodRangeText = "\(displayPeriod(firstPeriod)) ~ \(displayPeriod(lastPeriod)) 節"
	}
	
	return "週\(dayToken) \(periodRangeText)（\(startTimeStr) ~ \(endTimeStr)）"
}

// 把 "1,2" 或 "A,B,C,D" 轉成 [Int]
private func parsePeriods(from token: String) -> [Int] {
	let rawPeriods = token.components(separatedBy: ",")
	var result: [Int] = []
	
	for p in rawPeriods {
		let v = p.trimmingCharacters(in: .whitespaces)
		if let intVal = Int(v) {
			result.append(intVal)
		} else {
			switch v {
			case "A": result.append(11)
			case "B": result.append(12)
			case "C": result.append(13)
			case "D": result.append(14)
			default:
				break
			}
		}
	}
	return result
}

// 將節次數字轉回畫面顯示文字
// 例如 11 -> "A"  12 -> "B"
private func displayPeriod(_ period: Int) -> String {
	switch period {
	case 11: return "A"
	case 12: return "B"
	case 13: return "C"
	case 14: return "D"
	default: return "\(period)"
	}
}
