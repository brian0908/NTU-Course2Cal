//
//  HistoryCoursesView.swift
//  NTU-Course2Cal
//
//  Created by Brian Lee on 12/7/25.
//

import SwiftUI

struct HistoryCoursesView: View {
	@EnvironmentObject var viewModel: CourseViewModel
	
	@State private var selectedSemesterId: UUID?
	@State private var expandedGroupId: String? = nil
	
	// 只取已封存的學期
	private var archivedSemesters: [Semester] {
		viewModel.semesters.filter { $0.isArchived }
	}
	
	// 目前選到的學期
	private var currentSemester: Semester? {
		guard let id = selectedSemesterId else { return archivedSemesters.first }
		return archivedSemesters.first(where: { $0.id == id }) ?? archivedSemesters.first
	}
	
	// 該學期的課程
	private var historyCourses: [Course] {
		currentSemester?.courses ?? []
	}
	
	// 和 MyCoursesView 同樣的 group 邏輯，只是改用 historyCourses
	private var groupedCourses: [CourseGroup] {
		let dict = Dictionary(grouping: historyCourses) { course in
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
				historyCourses.firstIndex(of: course)
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
				
				if archivedSemesters.isEmpty {
					VStack(spacing: 16) {
						Image(systemName: "archivebox")
							.font(.system(size: 60))
							.foregroundColor(.gray)
						Text("目前沒有歷史課程")
							.font(.title3)
							.foregroundColor(.secondary)
					}
				} else {
					VStack {
						// 學期選擇器
						if archivedSemesters.count > 1 {
							Picker("學期", selection: Binding(
								get: { selectedSemesterId ?? archivedSemesters.first!.id },
								set: { selectedSemesterId = $0 }
							)) {
								ForEach(archivedSemesters) { sem in
									Text(sem.name).tag(sem.id)
								}
							}
							.pickerStyle(.segmented)
							.padding([.horizontal, .top])
						}
						
						if historyCourses.isEmpty {
							Spacer()
							Text("此學期沒有課程資料")
								.foregroundColor(.secondary)
							Spacer()
						} else {
							List {
								ForEach(groupedCourses, id: \.id) { group in
									let isExpandedBinding = Binding<Bool>(
										get: { expandedGroupId == group.id },
										set: { newVal in
											expandedGroupId = newVal ? group.id : nil
										}
									)
									
									// 這裡不需要 toggle，所以 isSelected 傳 constant
									CourseGroupCard(
										group: group,
										isSelected: .constant(false),
										isExpanded: isExpandedBinding,
										showsToggle: false
									)
									.listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
									.listRowBackground(Color.clear)
									.listRowSeparator(.hidden)
									.swipeActions(edge: .trailing, allowsFullSwipe: true) {
										// 刪除整組課
										Button(role: .destructive) {
											guard let sem = currentSemester else { return }
											let targets = group.indices.compactMap { idx -> Course? in
												guard historyCourses.indices.contains(idx) else { return nil }
												return historyCourses[idx]
											}
											viewModel.deleteCourses(targets, inSemesterId: sem.id)
										} label: {
											Label("刪除", systemImage: "trash")
										}
										.tint(.red)
									}
								}
							}
							.scrollContentBackground(.hidden)
							.listStyle(.plain)
							.animation(.easeInOut(duration: 0.2), value: expandedGroupId)
						}
					}
				}
			}
			.navigationTitle("歷史課程")
		}
	}
}
