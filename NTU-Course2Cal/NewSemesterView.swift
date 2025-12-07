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
                TextField("例如 114-1", text: $name)
            }
            Section("開學第一天") {
                DatePicker("日期", selection: $startDate, displayedComponents: .date)
            }
            Section {
                Button("建立學期並切換") {
                    guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    viewModel.createSemester(name: name, startDate: startDate)
                    dismiss()
				}
				.buttonStyle(.glassProminent)
				.fontWeight(.semibold)
            }
        }
        .navigationTitle("新學期")
        .navigationBarTitleDisplayMode(.inline)
    }
}
