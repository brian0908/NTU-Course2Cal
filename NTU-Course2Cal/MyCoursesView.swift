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
	let indices: [Int]
}

struct MyCoursesView: View {
	@EnvironmentObject var viewModel: CourseViewModel
	@State private var showInputSheet = false
	@State private var expandedGroupId: String? = nil

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
						Label("快匯入本學期的課程吧！", systemImage: "hand.point.down")
							.font(.title3)
							.foregroundColor(.secondary)
						Button("匯入課表") {
							showInputSheet = true
						}
						.buttonStyle(.glassProminent)
						.fontWeight(.semibold)
						.frame(maxWidth: .infinity) 
					}
				} else {
					List {
						ForEach(groupedCourses) { group in
							CourseGroupRow(
								group: group,
								expandedGroupId: $expandedGroupId
							)
						}
					}
					.scrollContentBackground(.hidden)
					.listStyle(.plain)
					.animation(.easeInOut(duration: 0.2), value: expandedGroupId)
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
	var showsToggle: Bool = true

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
					
					HStack(spacing: 3) {
						Image(systemName: "location")
						Text(group.location)
					}
					.font(.caption)
					.foregroundColor(.gray)
					
					if let credits = group.credits {
						HStack(spacing: 3) {
							Image(systemName: "book.closed")
							Text(" \(credits) 學分")
						}
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
					
					if showsToggle {
						VStack(spacing: 3) {

							Toggle("", isOn: $isSelected)
								.labelsHidden()
								.scaleEffect(0.8)
								.onTapGesture { }
							Text("匯出")
								.font(.caption)
								.foregroundColor(.ntuBlue)
								.fontWeight(.semibold)
						}
					}
				}
			}
			
			Image(systemName: "chevron.up")
				.font(.caption)
				.rotationEffect(.degrees(isExpanded ? 0 : 180))
				.foregroundColor(Color(red: 0/255, green: 75/255, blue: 151/255))
				.padding(.top, 4)
			
			if isExpanded {
				VStack(alignment: .leading, spacing: 6) {
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
						}
					}
					
					if !group.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
						Divider().padding(.vertical, 4)
						Text("備註")
							.font(.caption)
							.fontWeight(.bold)
						Text(group.notes)
							.font(.caption)
							.foregroundColor(.secondary)
					}
				}
				.transition(
					.asymmetric(
						insertion: .push(from: .top).combined(with: .opacity),
						removal:   .push(from: .bottom).combined(with: .opacity)
					)
				)
			}
		}
		.padding()
		.background(Color.white)
		.cornerRadius(12)
		.shadow(radius: 2)
		.contentShape(Rectangle())
		.onTapGesture {
			withAnimation(.easeInOut(duration: 0.2)) {
				isExpanded.toggle()
			}
		}
	}
}

struct CourseGroupRow: View {
	@EnvironmentObject var viewModel: CourseViewModel
	let group: CourseGroup
	@Binding var expandedGroupId: String?
	
	// group 的「全部勾選」狀態 binding
	private var isSelectedBinding: Binding<Bool> {
		Binding(
			get: {
				for idx in group.indices {
					if !viewModel.courses.indices.contains(idx) { return false }
					if !viewModel.courses[idx].isSelected { return false }
				}
				return !group.indices.isEmpty
			},
			set: { newValue in
				for idx in group.indices {
					if viewModel.courses.indices.contains(idx) {
						viewModel.courses[idx].isSelected = newValue
					}
				}
				viewModel.saveCurrentSemesterCourses()
			}
		)
	}
	
	// 展開狀態 binding
	private var isExpandedBinding: Binding<Bool> {
		Binding(
			get: { expandedGroupId == group.id },
			set: { newVal in
				expandedGroupId = newVal ? group.id : nil
			}
		)
	}
	
	var body: some View {
		CourseGroupCard(
			group: group,
			isSelected: isSelectedBinding,
			isExpanded: isExpandedBinding,
			showsToggle: true
		)
		.listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
		.listRowBackground(Color.clear)
		.listRowSeparator(.hidden)
		.swipeActions(edge: .trailing, allowsFullSwipe: true) {
			
			// Delete: 整組刪掉
			Button(role: .destructive) {
				let targets = group.indices.compactMap { idx -> Course? in
					guard viewModel.courses.indices.contains(idx) else { return nil }
					return viewModel.courses[idx]
				}
				viewModel.courses.removeAll { course in
					targets.contains(course)
				}
				viewModel.saveCurrentSemesterCourses()
			} label: {
				Label("刪除", systemImage: "trash")
			}
			.tint(.red)
		}
	}
}

// 將 rawTime 轉成多行時間說明
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
	
	let dayToken = parts[0]
	let periodToken = parts.last!
	
	let periods = parsePeriods(from: periodToken)
	guard !periods.isEmpty else { return nil }
	
	let sorted = periods.sorted()
	let firstPeriod = sorted.first!
	let lastPeriod = sorted.last!
	
	let startTimeStr = getStartTime(for: firstPeriod)
	let endTimeStr = getEndTime(for: lastPeriod)
	
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
