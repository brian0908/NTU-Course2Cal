//
//  CopyTutorialView.swift
//  NTU-Course2Cal
//
//  Created by Brian Lee on 12/6/25.
//

import SwiftUI
import SwiftyGif

/// 用來顯示本機 gif 檔的 UIViewRepresentable
struct LocalGifView: UIViewRepresentable {
	let gifName: String
	let loopCount: Int   // -1 代表無限循環
	
	func makeUIView(context: Context) -> UIImageView {
		let imageView: UIImageView
		
		if let gif = try? UIImage(gifName: gifName) {
			imageView = UIImageView(gifImage: gif, loopCount: loopCount)
		} else {
			imageView = UIImageView()
		}
		
		// 關鍵修正 1: 設定內容模式為「等比例縮放」，這樣圖片才會配合 Frame 改變大小
		imageView.contentMode = .scaleAspectFit
		
		// 關鍵修正 2: 告訴 AutoLayout 系統，這張圖片可以被壓縮 (允許縮小)
		// 如果不設定這兩行，圖片可能會因為「抗壓縮優先級」太高而撐開 Frame
		imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
		
		// 確保圖片不會超出邊界
		imageView.clipsToBounds = true
		
		return imageView
	}
	
	func updateUIView(_ uiView: UIImageView, context: Context) {
		// 不需要做事
	}
}

struct CopyTutorialView: View {
	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				
				// 標題
				Text("如何從臺大新課程網複製課表")
					.font(.title2)
					.fontWeight(.bold)
					.padding(.top, 8)
				
				Text("請依照下面的示範 GIF 以及步驟，將課表複製貼上到 NTU Course2Cal。")
					.font(.subheadline)
					.foregroundColor(.secondary)
				
				// GIF 區域
				LocalGifView(gifName: "tutorial.gif", loopCount: -1)
					// 設定 Frame 高度或寬度。
					// 建議設定 height 或讓它自適應，width: 50 可能會太小看不清楚，
					// 這裡先設為 height: 300 讓它有足夠空間展示，你可以依需求調整。
					.frame(height: 400)
					.frame(maxWidth: .infinity, alignment: .center)   // 置中
					.padding(.vertical, 15)

				// 步驟說明
				VStack(alignment: .leading, spacing: 10) {
					Text("步驟 1：打開新課程網")
						.font(.headline)
					Text("登入後，進入右上角「選課結果」，並且確定出現「列表」畫面。")
						.font(.subheadline)
						.foregroundColor(.secondary)
					
					Divider()
					
					Text("步驟 2：選取文字並複製")
						.font(.headline)
					Text("""
長按「選課結果」標題字樣往下複製，一路拖曳至頁面底部「沒有未選上的課程」結束，點選「複製」。
""")
					.font(.subheadline)
					.foregroundColor(.secondary)
					
					Divider()
					
					Text("步驟 3：貼到 NTU Course2Cal")
						.font(.headline)
					Text("""
回到 NTU Course2Cal app，在「我的課程」頁面點選「貼上課表」。
""")
					.font(.subheadline)
					.foregroundColor(.secondary)
					
					Divider()
					
					Text("小提示")
						.font(.headline)
					Text("""
- 若解析失敗，先檢查是否有從正確的「列表」頁面選取正確範圍。
- 如果選課結果有更新，請再貼上一次最新的資料，重新解析。
""")
					.font(.subheadline)
					.foregroundColor(.secondary)
				}
				
				Spacer(minLength: 16)
			}
			.padding()
		}
		.navigationTitle("複製課程資訊教學")
	}
}
