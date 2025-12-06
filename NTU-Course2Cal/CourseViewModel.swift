//
//  CourseViewModel.swift
//  NTU Course2Cal
//
//  Created by Brian Lee on 12/4/25.
//

import Foundation
import SwiftUI
import Combine
import EventKit
import GoogleSignIn
import GoogleSignInSwift

@MainActor
class CourseViewModel: ObservableObject {
	@Published var courses: [Course] = []
	// 使用 AppStorage 記錄開學日與提醒設定
	@AppStorage("semesterStartDate") var semesterStartDate: Double = Date().timeIntervalSince1970
	@AppStorage("notifyMinutesBefore") var notifyMinutesBefore: Int = 10
	@Published var googleCalendars: [GoogleCalendarInfo] = []
	@Published var selectedCalendarId: String = "primary"
	
	let eventStore = EKEventStore()
	
	var startDate: Date {
		get { Date(timeIntervalSince1970: semesterStartDate) }
		set { semesterStartDate = newValue.timeIntervalSince1970 }
	}

	// MARK: - 雙重 Regex 解析邏輯
	func parseText(_ text: String, completion: @escaping (Bool) -> Void) {
		DispatchQueue.global(qos: .userInitiated).async { [weak self] in
			guard let self = self else { return }
			var newCourses: [Course] = []

			// 手機 & 電腦通用格式:
			// name
			// teacher
			// time (一 1,2 或 一 A,B,C,D / 三 5,6)
			// location
			// 後面一整塊 details, 一直到 "已選上" 前
			let pattern =
			"(.+)\\n" +                    // 1: 課名
			"(.+)\\n" +                    // 2: 老師
			"([一二三四五六日][^\\n]+)\\n" +  // 3: 時間
			"(.+)\\n" +                    // 4: 地點
			"([\\s\\S]*?)(?=\\n已選上|$)"     // 5: 詳細區塊 (代碼 + 學分 + 類別 + 人數 + 備註)

			do {
				let regex = try NSRegularExpression(pattern: pattern, options: [])
				let nsString = text as NSString
				let matches = regex.matches(
					in: text,
					options: [],
					range: NSRange(location: 0, length: nsString.length)
				)

				if matches.isEmpty {
					print("⚠️ 未能解析出任何課程")
				} else {
					print("🔍 Pattern 成功匹配到 \(matches.count) 筆資料")
				}

				for result in matches {
					// 1: 課名
					let rawName = nsString.substring(with: result.range(at: 1))
					let name = rawName
						.components(separatedBy: .newlines)
						.last?
						.trimmingCharacters(in: .whitespacesAndNewlines) ?? rawName

					// 2: 老師
					let teacher = nsString.substring(with: result.range(at: 2))
						.trimmingCharacters(in: .whitespacesAndNewlines)

					// 3: 時間
					let timeRaw = nsString.substring(with: result.range(at: 3))
						.trimmingCharacters(in: .whitespacesAndNewlines)

					// 4: 地點
					let location = nsString.substring(with: result.range(at: 4))
						.trimmingCharacters(in: .whitespacesAndNewlines)

					// 5: 詳細區塊 (流水號、課號、學分、人數、各種說明與備註)
					let detailsBlockRaw = nsString.substring(with: result.range(at: 5))

					// 拆成一行一行，去掉空白行
					let detailLines = detailsBlockRaw
						.components(separatedBy: .newlines)
						.map { $0.trimmingCharacters(in: .whitespaces) }
						.filter { !$0.isEmpty }

					// 解析學分與「最後一個 XX 人」之後的備註
					var credits: Int? = nil
					var lastPeopleIndex: Int? = nil

					for (idx, line) in detailLines.enumerated() {
						// 抓學分
						if credits == nil, line.contains("學分") {
							let digits = line.filter { $0.isNumber }
							if let val = Int(digits) {
								credits = val
							}
						}

						// 抓人數: 形式類似 "138 人"
						if line.range(of: #"^\d+\s*人$"#,
									  options: .regularExpression) != nil {
							lastPeopleIndex = idx
						}
					}

					var notes = ""
					if let idx = lastPeopleIndex, idx + 1 < detailLines.count {
						let noteLines = detailLines[(idx + 1)...]
						notes = noteLines.joined(separator: "\n")
					}

					// 多時段 "一 A,B,C,D / 三 5,6"
					let timeSegments = timeRaw.components(separatedBy: "/")

					for segment in timeSegments {
						let cleanedSegment = segment.trimmingCharacters(in: .whitespaces)
						if cleanedSegment.isEmpty { continue }

						let (weekday, periods) = self.parseTime(cleanedSegment)

						if !periods.isEmpty {
							newCourses.append(
								Course(
									name: name,
									teacher: teacher,
									location: location,
									rawTime: timeRaw,
									weekday: weekday,
									periods: periods,
									isSelected: true,
									credits: credits,
									notes: notes
								)
							)
						}
					}
				}
			} catch {
				print("Regex Error: \(error)")
			}

			DispatchQueue.main.async {
				self.courses = newCourses
				let success = !newCourses.isEmpty
				completion(success)
			}
		}
	}
	
	// MARK: - 時間解析 Helper
	nonisolated func parseTime(_ raw: String) -> (Int, [Int]) {
		var weekday = 2
		var periods: [Int] = []
		
		if raw.contains("日") { weekday = 1 }
		else if raw.contains("一") { weekday = 2 }
		else if raw.contains("二") { weekday = 3 }
		else if raw.contains("三") { weekday = 4 }
		else if raw.contains("四") { weekday = 5 }
		else if raw.contains("五") { weekday = 6 }
		else if raw.contains("六") { weekday = 7 }
		
		let components = raw.components(separatedBy: .whitespaces)
		if let periodString = components.last {
			let rawPeriods = periodString.components(separatedBy: ",")
			for p in rawPeriods {
				let cleanP = p.trimmingCharacters(in: .whitespaces)
				if let intVal = Int(cleanP) {
					periods.append(intVal)
				} else {
					switch cleanP {
					case "A": periods.append(11)
					case "B": periods.append(12)
					case "C": periods.append(13)
					case "D": periods.append(14)
					default: break
					}
				}
			}
		}
		return (weekday, periods)
	}

	// MARK: - 資料管理 (修復 Crash)
	func clearCourses() {
		courses.removeAll()
	}

	// MARK: - 匯出至行事曆
	func exportToCalendar(completion: @escaping (Bool, String) -> Void) {
		let handler: @Sendable (Bool, Error?) -> Void = { [weak self] granted, error in
			guard let self = self else { return }
			if granted && error == nil {
				DispatchQueue.main.async {
					self.saveEventsToCalendar()
				}
				completion(true, "成功匯入")
			} else {
				completion(false, "沒有行事曆權限")
			}
		}

		if #available(iOS 17.0, *) {
			eventStore.requestFullAccessToEvents(completion: handler)
		} else {
			eventStore.requestAccess(to: .event, completion: handler)
		}
	}
	
	private func saveEventsToCalendar() {
		for course in self.courses where course.isSelected {
			self.createEvent(for: course)
		}
	}
	
	private func createEvent(for course: Course) {
		guard let firstClassDate = calculateDate(weekday: course.weekday, periods: course.periods) else { return }
		
		let event = EKEvent(eventStore: eventStore)
		event.title = course.name
		event.location = course.location
		event.notes = "授課老師：\(course.teacher)"
		event.startDate = firstClassDate
		event.endDate = firstClassDate.addingTimeInterval(TimeInterval(50 * 60 * course.periods.count))
		event.calendar = eventStore.defaultCalendarForNewEvents
		
		if notifyMinutesBefore > 0 {
			event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-notifyMinutesBefore * 60)))
		}
		
		let rule = EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: EKRecurrenceEnd(occurrenceCount: 16))
		event.addRecurrenceRule(rule)
		
		do {
			try eventStore.save(event, span: .thisEvent)
		} catch {
			print("Save failed: \(error)")
		}
	}
	
	private func calculateDate(weekday: Int, periods: [Int]) -> Date? {
		let calendar = Calendar.current
		let startWeekday = calendar.component(.weekday, from: startDate)
		var dayDiff = weekday - startWeekday
		if dayDiff < 0 { dayDiff += 7 }
		
		guard let targetDate = calendar.date(byAdding: .day, value: dayDiff, to: startDate) else { return nil }
		
		let startTimeString = getStartTime(for: periods.first ?? 1)
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyy-MM-dd HH:mm"
		let fullString = "\(formatter.string(from: targetDate).prefix(10)) \(startTimeString)"
		
		return formatter.date(from: fullString)
	}
	private func rfc3339String(from date: Date) -> String {
		let formatter = ISO8601DateFormatter()
		formatter.timeZone = TimeZone.current
		formatter.formatOptions = [
			.withInternetDateTime,
			.withColonSeparatorInTimeZone
		]
		return formatter.string(from: date)
	}
	// MARK: - 匯出到 Google Calendar（簡單版，使用 selectedCalendarId）
	func exportToGoogleCalendar(using signInManager: GoogleSignInManager) async -> (Bool, String) {
		// 1. 檢查是否登入
		guard let user = signInManager.user else {
			return (false, "請先在「設定」頁登入 Google 帳號")
		}

		// 2. 取得 access token
		let accessToken = user.accessToken.tokenString
		if accessToken.isEmpty {
			return (false, "找不到 Google 存取權杖")
		}

		// 3. 只匯出有勾選的課
		let selectedCourses = courses.filter { $0.isSelected }
		if selectedCourses.isEmpty {
			return (false, "沒有勾選要匯出的課程")
		}

		let calendarId = selectedCalendarId.isEmpty ? "primary" : selectedCalendarId
		let urlString = "https://www.googleapis.com/calendar/v3/calendars/\(calendarId)/events"
		guard let url = URL(string: urlString) else {
			return (false, "Google Calendar API URL 錯誤")
		}

		let timeZoneId = TimeZone.current.identifier
		var successCount = 0
		var failCount = 0

		for course in selectedCourses {
			// 4. 算第一堂課日期
			guard let startDate = calculateDate(weekday: course.weekday,
												periods: course.periods) else {
				failCount += 1
				continue
			}

			let duration = TimeInterval(50 * 60 * course.periods.count)
			let endDate = startDate.addingTimeInterval(duration)

			// 5. 組 event body
			let descLines: [String] = [
				"授課老師：\(course.teacher)",
				course.notes.isEmpty ? nil : course.notes
			].compactMap { $0 }

			let description = descLines.joined(separator: "\n\n")

			let event = GoogleCalendarEvent(
				summary: course.name,
				location: course.location.isEmpty ? nil : course.location,
				description: description.isEmpty ? nil : description,
				start: .init(
					dateTime: rfc3339String(from: startDate),
					timeZone: timeZoneId
				),
				end: .init(
					dateTime: rfc3339String(from: endDate),
					timeZone: timeZoneId
				),
				recurrence: ["RRULE:FREQ=WEEKLY;COUNT=16"]
			)

			do {
				var request = URLRequest(url: url)
				request.httpMethod = "POST"
				request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
				request.addValue("application/json", forHTTPHeaderField: "Content-Type")

				let encoder = JSONEncoder()
				request.httpBody = try encoder.encode(event)

				let (_, response) = try await URLSession.shared.data(for: request)

				if let http = response as? HTTPURLResponse,
				   (200..<300).contains(http.statusCode) {
					successCount += 1
				} else {
					failCount += 1
				}
			} catch {
				print("Google Calendar insert error:", error)
				failCount += 1
			}
		}

		if successCount > 0 && failCount == 0 {
			return (true, "成功匯出 \(successCount) 堂課到 Google 行事曆")
		} else if successCount > 0 {
			return (true, "成功匯出 \(successCount) 堂課，有 \(failCount) 堂失敗")
		} else {
			return (false, "匯出到 Google 行事曆失敗")
		}
	}

	// 讀取使用者 Google 行事曆列表，填到 googleCalendars / selectedCalendarId
	func loadGoogleCalendars(using signInManager: GoogleSignInManager) async -> (Bool, String) {
		guard let user = signInManager.user else {
			return (false, "請先在設定頁登入 Google 帳號")
		}

		let accessToken = user.accessToken.tokenString
		guard !accessToken.isEmpty else {
			return (false, "找不到 Google 存取權杖")
		}

		guard let url = URL(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList") else {
			return (false, "Google Calendar API URL 錯誤")
		}

		var request = URLRequest(url: url)
		request.httpMethod = "GET"
		request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

		do {
			let (data, response) = try await URLSession.shared.data(for: request)
			guard let http = response as? HTTPURLResponse,
				  (200..<300).contains(http.statusCode) else {
				let code = (response as? HTTPURLResponse)?.statusCode ?? -1
				return (false, "讀取日曆列表失敗（\(code)）")
			}

			struct CalendarListResponse: Decodable {
				let items: [GoogleCalendarInfo]
			}

			let decoded = try JSONDecoder().decode(CalendarListResponse.self, from: data)

			// 更新到畫面
			self.googleCalendars = decoded.items

			// 預設選 primary，找不到就選第一個
			if let primary = decoded.items.first(where: { $0.primary == true }) {
				self.selectedCalendarId = primary.id
			} else if let first = decoded.items.first {
				self.selectedCalendarId = first.id
			} else {
				self.selectedCalendarId = "primary"
			}

			return (true, "已載入 \(decoded.items.count) 個日曆")
		} catch {
			print("loadGoogleCalendars error:", error)
			return (false, "讀取日曆列表發生錯誤")
		}
	}
}

// MARK: - Google Calendar 進階功能（extension）

extension CourseViewModel {
	
// 列出使用者所有行事曆
	func fetchGoogleCalendars(using manager: GoogleSignInManager) async -> [GoogleCalendarInfo] {
		guard let token = manager.accessToken else {
			print("No Google access token")
			return []
		}
		
		guard let url = URL(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList") else {
			return []
		}
		
		var request = URLRequest(url: url)
		request.httpMethod = "GET"
		request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
		
		do {
			let (data, response) = try await URLSession.shared.data(for: request)
			guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
				print("CalendarList status not 200")
				return []
			}
			
			struct CalendarListResponse: Decodable {
				let items: [GoogleCalendarInfo]
			}
			
			let decoded = try JSONDecoder().decode(CalendarListResponse.self, from: data)
			return decoded.items
		} catch {
			print("fetchGoogleCalendars error: \(error)")
			return []
		}
	}

	// 建立新的行事曆，名稱由使用者輸入
	func createGoogleCalendar(named name: String,
							  using manager: GoogleSignInManager) async -> GoogleCalendarInfo? {
		guard let token = manager.accessToken else {
			print("No Google access token")
			return nil
		}

		guard let url = URL(string: "https://www.googleapis.com/calendar/v3/calendars") else {
			return nil
		}

		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
		request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

		let body: [String: Any] = [
			"summary": name,
			"timeZone": "Asia/Taipei"
		]

		request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

		do {
			let (data, response) = try await URLSession.shared.data(for: request)
			guard let http = response as? HTTPURLResponse,
				  (200...299).contains(http.statusCode) else {
				if let http = response as? HTTPURLResponse {
					print("createCalendar status: \(http.statusCode)")
				}
				return nil
			}
			let calendar = try JSONDecoder().decode(GoogleCalendarInfo.self, from: data)
			return calendar
		} catch {
			print("createGoogleCalendar error: \(error)")
			return nil
		}
	}

	// 進階版：明確指定 calendarID 與週數
	func exportToGoogleCalendar(using manager: GoogleSignInManager,
								calendarID: String,
								weeks: Int = 16) async -> (Bool, String) {
		guard let token = manager.accessToken else {
			return (false, "請先在設定頁登入 Google 帳號")
		}

		// 沒課就不用匯
		let targets = courses.filter { $0.isSelected }
		if targets.isEmpty {
			return (false, "目前沒有選取要匯出的課程")
		}

		// 日期格式 RFC3339
		let formatter = ISO8601DateFormatter()
		formatter.formatOptions = [.withInternetDateTime]
		formatter.timeZone = TimeZone(identifier: "Asia/Taipei")

		for course in targets {
			guard let firstDate = calculateDate(weekday: course.weekday, periods: course.periods) else {
				continue
			}

			let duration = TimeInterval(50 * 60 * course.periods.count)
			let endDate = firstDate.addingTimeInterval(duration)

			let startString = formatter.string(from: firstDate)
			let endString = formatter.string(from: endDate)

			var recurrence: [String] = []
			if weeks > 0 {
				recurrence = ["RRULE:FREQ=WEEKLY;COUNT=\(weeks)"]
			}

			let description = """
			授課老師：\(course.teacher)
			上課時間：\(course.rawTime)

			\(course.notes)
			"""

			let eventBody: [String: Any] = [
				"summary": course.name,
				"location": course.location,
				"description": description,
				"start": [
					"dateTime": startString,
					"timeZone": "Asia/Taipei"
				],
				"end": [
					"dateTime": endString,
					"timeZone": "Asia/Taipei"
				],
				"recurrence": recurrence
			]

			guard let url = URL(string: "https://www.googleapis.com/calendar/v3/calendars/\(calendarID)/events") else {
				continue
			}

			var request = URLRequest(url: url)
			request.httpMethod = "POST"
			request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
			request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
			request.httpBody = try? JSONSerialization.data(withJSONObject: eventBody, options: [])

			do {
				let (_, response) = try await URLSession.shared.data(for: request)
				guard let http = response as? HTTPURLResponse,
					  (200...299).contains(http.statusCode) else {
					print("Add event failed for \(course.name)")
					continue
				}
			} catch {
				print("Add event error: \(error)")
				continue
			}
		}

		return (true, "已匯出課程到 Google 行事曆")
	}
}

	// MARK: - Google Calendar model

	struct GoogleCalendarEvent: Encodable {
		struct DateTime: Encodable {
			let dateTime: String
			let timeZone: String
		}

		let summary: String
		let location: String?
		let description: String?
		let start: DateTime
		let end: DateTime
		let recurrence: [String]?
	}

	struct GoogleCalendarInfo: Identifiable, Decodable {
		let id: String
		let summary: String
		let primary: Bool?
	}

