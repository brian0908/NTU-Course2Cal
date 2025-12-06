//
//  Models.swift
//  NTU Course2Cal
//
//  Created by Brian Lee on 12/4/25.
//

import Foundation
import SwiftUI

// 定義課程資料結構
struct Course: Identifiable, Codable, Equatable {
	var id = UUID()
	var name: String
	var teacher: String
	var location: String
	var rawTime: String      // 原始時間字串，例如 "一 1,2 / 三 5,6"
	var weekday: Int         // 1 = 週日, 2 = 週一 ...
	var periods: [Int]       // 節次
	var isSelected: Bool = true
	var credits: Int? = nil  // 新增
	var notes: String = ""   // 新增
}

// 台大節次對照表 (節次 -> 開始時間)
// 依據使用者提供的最新時間表更新
func getStartTime(for period: Int) -> String {
	switch period {
	case 0: return "07:10"
	case 1: return "08:10"
	case 2: return "09:10"
	case 3: return "10:20"
	case 4: return "11:20"
	case 5: return "12:20"
	case 6: return "13:20"
	case 7: return "14:20"
	case 8: return "15:30"
	case 9: return "16:30"
	case 10: return "17:30"
	case 11: return "18:25" // A
	case 12: return "19:20" // B
	case 13: return "20:15" // C
	case 14: return "21:10" // D
	default: return "00:00"
	}
}

func getEndTime(for period: Int) -> String {
	switch period {
	case 0: return "08:00"
	case 1: return "09:00"
	case 2: return "10:00"
	case 3: return "11:10"
	case 4: return "12:10"
	case 5: return "13:10"
	case 6: return "14:10"
	case 7: return "15:10"
	case 8: return "16:20"
	case 9: return "17:20"
	case 10: return "18:20"
	case 11: return "19:15" // A
	case 12: return "20:10" // B
	case 13: return "21:05" // C
	case 14: return "22:00" // D
	default: return "00:00"
	}
}
