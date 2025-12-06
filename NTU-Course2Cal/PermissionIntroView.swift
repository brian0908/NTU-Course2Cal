//
//  PermissionIntroView.swift
//  NTU Course2Cal
//
//  Created by Brian Lee on 12/6/25.
//

import SwiftUI
import EventKit

struct PermissionIntroView: View {
	@EnvironmentObject var viewModel: CourseViewModel
	@AppStorage("hasCompletedPermissionFlow") private var hasCompletedPermissionFlow = false

	@State private var isRequesting = false
	@State private var errorMessage: String?

	var body: some View {
		VStack(spacing: 24) {
			Spacer()

			Image(systemName: "calendar.badge.plus")
				.font(.system(size: 60))
				.foregroundColor(Color(red: 0/255, green: 75/255, blue: 151/255))

			Text("歡迎使用 NTU Course2Cal")
				.font(.title2)
				.fontWeight(.bold)

			Text("本 App 需要您的同意，才能將選課結果自動匯入 iOS 行事曆。")
				.multilineTextAlignment(.center)
				.foregroundColor(.secondary)
				.padding(.horizontal)

			Button(action: requestPermission) {
				HStack {
					if isRequesting {
						ProgressView().tint(.white)
					} else {
						Text("允許匯入到行事曆")
							.fontWeight(.bold)
					}
				}
				.frame(maxWidth: .infinity)
				.padding()
				.background(Color(red: 0/255, green: 75/255, blue: 151/255))
				.foregroundColor(.white)
				.cornerRadius(10)
			}
			.padding(.horizontal)

			if let error = errorMessage {
				Text(error)
					.font(.footnote)
					.foregroundColor(.red)
					.multilineTextAlignment(.center)
			}

			Button("先跳過，下次再設定") {
				hasCompletedPermissionFlow = true
			}
			.font(.footnote)
			.foregroundColor(.gray)

			Spacer()
		}
		.padding()
	}

	// MARK: - Request Permission
	private func requestPermission() {
		isRequesting = true
		errorMessage = nil

		Task {
			if #available(iOS 17.0, *) {
				do {
					let granted = try await viewModel.eventStore.requestWriteOnlyAccessToEvents()
					await MainActor.run {
						isRequesting = false
						if granted {
							hasCompletedPermissionFlow = true
						} else {
							errorMessage = "您尚未開啟權限，可至「設定 > 隱私權 > 行事曆」手動開啟。"
						}
					}
				} catch {
					await MainActor.run {
						isRequesting = false
						errorMessage = "發生錯誤：\(error.localizedDescription)"
					}
				}
			} else {
				// iOS 16 fallback
				viewModel.eventStore.requestAccess(to: .event) { granted, _ in
					DispatchQueue.main.async {
						isRequesting = false
						if granted {
							hasCompletedPermissionFlow = true
						} else {
							errorMessage = "請至「設定 > 隱私權 > 行事曆」手動開啟授權。"
						}
					}
				}
			}
		}
	}
}
