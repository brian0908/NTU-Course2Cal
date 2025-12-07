//
//  NewSemesterView.swift
//  NTU-Course2Cal
//
//  Created by Brian Lee on 12/7/25.
//
import SwiftUI

struct NewSemesterView: View {
    @EnvironmentObject var viewModel: CourseViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var startDate: Date = Date()
    
	var body: some View {
		Form {
			Section("學期名稱") {
				TextField("例如：114-1", text: $name)
			}
			Section("開學第一天") {
				DatePicker("日期", selection: $startDate, displayedComponents: .date)
			}
			Section {
				Button {
					guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
					viewModel.createSemester(name: name, startDate: startDate)
					dismiss()
				} label: {
					HStack {
						Spacer()
						Image(systemName: "plus.circle.fill")
						Text("建立學期並切換")
							.fontWeight(.bold)
						Spacer()
					}
				}
				.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
				.foregroundColor(.white)
				.listRowBackground(
					Color(red: 0/255, green: 75/255, blue: 151/255)
						.glassEffect(.regular)
				)
			}
		}
		.navigationTitle("新學期")
		.navigationBarTitleDisplayMode(.inline)
	}
}
