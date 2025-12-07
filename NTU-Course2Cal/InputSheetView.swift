//
//  InputSheetView.swift
//  NTU Course2Cal
//
//  Created by Brian Lee on 12/4/25.
//


import SwiftUI
import UIKit
import DotLottie

struct InputSheetView: View {
	@Environment(\.dismiss) var dismiss
	@EnvironmentObject var viewModel: CourseViewModel
	@Environment(\.openURL) private var openURL
	
	@State private var inputText: String = ""
	@State private var showConfetti = false
	@State private var isParsing = false
	@State private var showParseError = false
	@State private var showNeedSemesterAlert = false   // 如果還沒有的話要加這個

	var body: some View {
		ZStack {
			NavigationStack {
				Form {
					// 必要設定
					Section(header: Text("必要設定")) {
						DatePicker(
							"開學第一天",
							selection: $viewModel.startDate,
							displayedComponents: .date
						)
						.tint(Color(red: 0/255, green: 75/255, blue: 151/255))
					}

					// 貼上選課結果
					Section(header: Text("貼上選課結果")) {
						VStack(alignment: .leading, spacing: 12) {
							Button {
								// 先檢查有沒有選學期
								guard viewModel.currentSemesterId != nil else {
									showNeedSemesterAlert = true
									return
								}

								if let pasted = UIPasteboard.general.string {
									inputText = pasted
								} else {
									inputText = ""
								}
							} label: {
								HStack {
									Image(systemName: "doc.on.clipboard")
									Text("從剪貼簿貼上")
										.fontWeight(.semibold)
								}
							}
							.buttonStyle(.glassProminent)
							.disabled(viewModel.currentSemesterId == nil)

							if viewModel.currentSemesterId == nil {
								Text("請先選擇或建立一個學期，再貼上課程列表。")
									.font(.footnote)
									.foregroundColor(.red)
							} else if inputText.isEmpty {
								Text("目前沒有內容，請先到臺大課程網複製課程列表，再按上方按鈕貼上。")
									.font(.footnote)
									.foregroundColor(.gray)
							} else {
								ScrollView {
									Text(inputText)
										.font(.system(size: 13, design: .monospaced))
										.frame(maxWidth: .infinity, alignment: .topLeading)
								}
								.frame(height: 200)
								.background(Color(.secondarySystemBackground))
								.cornerRadius(8)
							}
						}

						// 這兩個放在「框框外面」，但同一個 Section 裡

						// 前往臺大課程網
						Button {
							if let url = URL(string: "https://course.ntu.edu.tw/result/final/list") {
								openURL(url)
							}
						} label: {
							HStack {
								Image(systemName: "safari")
								Text("前往臺大課程網")
								Spacer()
							}
						}

						// 複製課表教學
						NavigationLink {
							CopyTutorialView()
						} label: {
							HStack {
								Image(systemName: "questionmark.circle")
								Text("查看複製課表教學")
								Spacer()
							}
						}
					}

					// 解析按鈕照舊
					Section {
						Button {
							startParse()
						} label: {
							HStack {
								Spacer()
								if isParsing {
									ProgressView()
										.progressViewStyle(.circular)
								} else {
									Image(systemName: "sparkles")
								}
								Text(isParsing ? "AI 解析中..." : "AI 解析並匯入課程")
									.fontWeight(.bold)
								Spacer()
							}
						}
						.disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isParsing)
						.foregroundColor(.white)
						.listRowBackground(
							Color(red: 0/255, green: 75/255, blue: 151/255)
								.glassEffect(.regular)
						)
					}
				}
				.navigationTitle("匯入課程")
				.navigationBarTitleDisplayMode(.inline)
				.toolbar {
					ToolbarItem(placement: .cancellationAction) {
						Button("取消") {
							dismiss()
						}
					}
				}
				.alert("解析失敗", isPresented: $showParseError) {
					Button("OK", role: .cancel) { }
				} message: {
					Text("無法從貼上的文字中解析出任何課程，請確認內容是否為臺大課程網的課程列表。")
				}
				.alert("請先選擇學期", isPresented: $showNeedSemesterAlert) {
					Button("OK", role: .cancel) { }
				} message: {
					Text("請先在「學期與通知」頁建立或選擇一個學期，再貼上課表內容。")
				}
			}

			// confetti 覆蓋照舊
			if showConfetti {
				DotLottieAnimation(
					fileName: "confetti",
					config: AnimationConfig(autoplay: true, speed: 1.5)
				)
				.view()
				.ignoresSafeArea()
				.allowsHitTesting(false)
				.transition(.opacity)
				.zIndex(10)
			}
		}
	}

	// startParse() 與其它函式保持不變
	
	// MARK: - 解析流程
	private func startParse() {
		let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return }
		
		isParsing = true
		
		viewModel.parseText(trimmed) { success in
			DispatchQueue.main.async {
				isParsing = false
				
				if success {
					showConfetti = true
					
					// 動畫播一小段時間後關閉畫面
					DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
						showConfetti = false
						dismiss()
					}
				} else {
					showParseError = true
				}
			}
		}
	}
}

