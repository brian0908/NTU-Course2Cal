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

// MARK: - Model types

struct Semester: Identifiable, Codable, Equatable {
	var id: UUID = UUID()
	var name: String          // 例如 "114-1"
	var startDate: Date
	var courses: [Course]
	var isArchived: Bool = false
}

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
// MARK: - ViewModel

@MainActor
class CourseViewModel: ObservableObject {
	
	// 現在畫面上這個學期的課程
	@Published var courses: [Course] = []
	
	// 所有學期
	@Published var semesters: [Semester] = []
	@Published var currentSemesterId: UUID? = nil
	
	// Google 行事曆列表與選取的 calendarId
	@Published var googleCalendars: [GoogleCalendarInfo] = []
	@Published var selectedCalendarId: String = "primary"
	@Published var appleCalendars: [EKCalendar] = []
	@AppStorage("appleTargetCalendarId") var appleTargetCalendarId: String = ""
	@AppStorage("semesterStartDate") var semesterStartDate: Double = Date().timeIntervalSince1970
	// 行事曆事件的提醒時間
	@AppStorage("notifyMinutesBeforeCalendar") var notifyMinutesBeforeCalendar: Int = 10

	// App 本地通知的提醒時間
	@AppStorage("notifyMinutesBeforeLocal") var notifyMinutesBeforeLocal: Int = 10
	
	// 儲存所有學期資料用
	@AppStorage("storedSemestersData") private var storedSemestersData: Data = Data()
	@AppStorage("storedCurrentSemesterId") private var storedCurrentSemesterId: String = ""
	
	let eventStore = EKEventStore()
	
	var startDate: Date {
		get { Date(timeIntervalSince1970: semesterStartDate) }
		set { semesterStartDate = newValue.timeIntervalSince1970 }
	}
	
	// 方便歷史課程頁用
	var activeSemesters: [Semester] {
		semesters.filter { !$0.isArchived }
	}
	
	var archivedSemesters: [Semester] {
		semesters.filter { $0.isArchived }
	}
	
	// MARK: - 初始化載入
	
	init() {
		loadSemestersFromStorage()
		
		// 如果有學期, 載入目前學期
		if let id = currentSemesterId,
		   let sem = semesters.first(where: { $0.id == id }) {
			self.courses = sem.courses
			self.startDate = sem.startDate
		} else if let first = semesters.first {
			// 沒有 currentId 就用第一個
			currentSemesterId = first.id
			storedCurrentSemesterId = first.id.uuidString
			self.courses = first.courses
			self.startDate = first.startDate
		}
	}
	
	// MARK: - 永久儲存學期資料
	
	private func saveSemestersToStorage() {
		do {
			let encoder = JSONEncoder()
			encoder.dateEncodingStrategy = .iso8601
			let data = try encoder.encode(semesters)
			storedSemestersData = data
			if let id = currentSemesterId {
				storedCurrentSemesterId = id.uuidString
			}
		} catch {
			print("saveSemestersToStorage error:", error)
		}
	}
	
	private func loadSemestersFromStorage() {
		guard !storedSemestersData.isEmpty else { return }
		do {
			let decoder = JSONDecoder()
			decoder.dateDecodingStrategy = .iso8601
			let decoded = try decoder.decode([Semester].self, from: storedSemestersData)
			self.semesters = decoded
			
			if let uuid = UUID(uuidString: storedCurrentSemesterId) {
				self.currentSemesterId = uuid
			}
		} catch {
			print("loadSemestersFromStorage error:", error)
		}
	}
	
	// MARK: - 學期管理
	
	func createSemester(name: String, startDate: Date) {
		let newSem = Semester(name: name, startDate: startDate, courses: [])
		semesters.append(newSem)
		currentSemesterId = newSem.id
		semesterStartDate = startDate.timeIntervalSince1970
		courses = []
		saveSemestersToStorage()
	}
	
	func switchSemester(to id: UUID) {
		guard let sem = semesters.first(where: { $0.id == id }) else { return }
		currentSemesterId = id
		courses = sem.courses
		startDate = sem.startDate
		saveSemestersToStorage()
	}
	
	func saveCurrentSemesterCourses() {
		guard let id = currentSemesterId,
			  let index = semesters.firstIndex(where: { $0.id == id }) else { return }
		
		semesters[index].courses = courses
		semesters[index].startDate = startDate
		saveSemestersToStorage()
	}
	
	func archiveCurrentSemester() {
		guard let id = currentSemesterId,
			  let index = semesters.firstIndex(where: { $0.id == id }) else { return }
		
		semesters[index].courses = courses
		semesters[index].startDate = startDate
		semesters[index].isArchived = true
		
		if let newActive = activeSemesters.first {
			currentSemesterId = newActive.id
			courses = newActive.courses
			startDate = newActive.startDate
		} else {
			currentSemesterId = nil
			courses = []
		}
		
		saveSemestersToStorage()
	}
	
	// MARK: - 雙重 Regex 解析邏輯
	
	func parseText(_ text: String, completion: @escaping (Bool) -> Void) {
		DispatchQueue.global(qos: .userInitiated).async { [weak self] in
			guard let self = self else { return }
			var newCourses: [Course] = []
			
			let pattern =
			"(.+)\\n" +
			"(.+)\\n" +
			"([一二三四五六日][^\\n]+)\\n" +
			"(.+)\\n" +
			"([\\s\\S]*?)(?=\\n已選上|$)"
			
			do {
				let regex = try NSRegularExpression(pattern: pattern, options: [])
				let nsString = text as NSString
				let matches = regex.matches(
					in: text,
					options: [],
					range: NSRange(location: 0, length: nsString.length)
				)
				
				if matches.isEmpty {
					print("未能解析出任何課程")
				} else {
					print("Pattern 成功匹配到 \(matches.count) 筆資料")
				}
				
				for result in matches {
					let rawName = nsString.substring(with: result.range(at: 1))
					let name = rawName
						.components(separatedBy: .newlines)
						.last?
						.trimmingCharacters(in: .whitespacesAndNewlines) ?? rawName
					
					let teacher = nsString.substring(with: result.range(at: 2))
						.trimmingCharacters(in: .whitespacesAndNewlines)
					
					let timeRaw = nsString.substring(with: result.range(at: 3))
						.trimmingCharacters(in: .whitespacesAndNewlines)
					
					let location = nsString.substring(with: result.range(at: 4))
						.trimmingCharacters(in: .whitespacesAndNewlines)
					
					let detailsBlockRaw = nsString.substring(with: result.range(at: 5))
					
					let detailLines = detailsBlockRaw
						.components(separatedBy: .newlines)
						.map { $0.trimmingCharacters(in: .whitespaces) }
						.filter { !$0.isEmpty }
					
					var credits: Int? = nil
					var lastPeopleIndex: Int? = nil
					
					for (idx, line) in detailLines.enumerated() {
						if credits == nil, line.contains("學分") {
							let digits = line.filter { $0.isNumber }
							if let val = Int(digits) {
								credits = val
							}
						}
						
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
				if success {
					self.saveCurrentSemesterCourses()
					if UserDefaults.standard.bool(forKey: "enableLocalNotifications") {
						self.rescheduleAllClassNotifications()
					}
				}
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
	
	// MARK: - 資料管理
	
	func clearCourses() {
		courses.removeAll()
		saveCurrentSemesterCourses()
	}
	
	// MARK: - 匯出至 Apple 行事曆
	
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
			
			// 優先用使用者選擇的行事曆
			if let target = eventStore.calendar(withIdentifier: appleTargetCalendarId) {
				event.calendar = target
			} else {
				event.calendar = eventStore.defaultCalendarForNewEvents
			}
			
			if notifyMinutesBeforeCalendar > 0 {
				event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-notifyMinutesBeforeCalendar * 60)))
			}
			
			let rule = EKRecurrenceRule(
				recurrenceWith: .weekly,
				interval: 1,
				end: EKRecurrenceEnd(occurrenceCount: 16)
			)
			event.addRecurrenceRule(rule)
			
			do {
				try eventStore.save(event, span: .thisEvent)
			} catch {
				print("Save failed: \(error)")
			}
		}
		
		// 請求 Apple 行事曆權限
		func requestAppleCalendarAccess(completion: @escaping (Bool, String) -> Void) {
			let handler: @Sendable (Bool, Error?) -> Void = { granted, error in
				Task { @MainActor in
					if granted, error == nil {
						completion(true, "已取得行事曆權限")
					} else {
						completion(false, "沒有行事曆權限")
					}
				}
			}
			
			if #available(iOS 17.0, *) {
				eventStore.requestFullAccessToEvents(completion: handler)
			} else {
				eventStore.requestAccess(to: .event, completion: handler)
			}
		}
		
		// 讀取可寫入的 Apple 行事曆
		func loadAppleCalendars(completion: @escaping (Bool, String) -> Void) {
			requestAppleCalendarAccess { [weak self] granted, msg in
				guard let self = self, granted else {
					completion(false, msg)
					return
				}
				
				let all = self.eventStore.calendars(for: .event)
				// 只留可以寫入的
				let writable = all.filter { $0.allowsContentModifications }
				
				self.appleCalendars = writable
				
				// 若目前設定的 id 不存在,就選第一個或 default
				if let current = self.eventStore.calendar(withIdentifier: self.appleTargetCalendarId),
				   current.allowsContentModifications {
					// ok, 不用改
				} else if let first = writable.first {
					self.appleTargetCalendarId = first.calendarIdentifier
				} else if let def = self.eventStore.defaultCalendarForNewEvents {
					self.appleTargetCalendarId = def.calendarIdentifier
				}
				
				completion(true, "已載入 \(writable.count) 個行事曆")
			}
		}
		
		// 建立新的 Apple 行事曆
		func createAppleCalendar(named name: String,
								 completion: @escaping (Bool, String) -> Void) {
			requestAppleCalendarAccess { [weak self] granted, msg in
				guard let self = self, granted else {
					completion(false, msg)
					return
				}
				
				let newCalendar = EKCalendar(for: .event, eventStore: self.eventStore)
				newCalendar.title = name
				
				// 優先使用 iCloud, 再用本機
				let sources = self.eventStore.sources
				let iCloudSource = sources.first { $0.sourceType == .calDAV && $0.title.contains("iCloud") }
				let localSource = sources.first { $0.sourceType == .local }
				
				guard let source = iCloudSource ?? localSource else {
					completion(false, "找不到可用的行事曆來源 (iCloud 或本機)")
					return
				}
				
				newCalendar.source = source
				
				do {
					try self.eventStore.saveCalendar(newCalendar, commit: true)
					self.appleCalendars.append(newCalendar)
					self.appleTargetCalendarId = newCalendar.calendarIdentifier
					completion(true, "已建立行事曆「\(name)」")
				} catch {
					print("createAppleCalendar error:", error)
					completion(false, "建立行事曆失敗: \(error.localizedDescription)")
				}
			}
		}
		
		// 設定要匯出的 Apple 行事曆 id
		func setAppleTargetCalendar(id: String) {
			appleTargetCalendarId = id
		}
	
	private func calculateDate(weekday: Int,
							   periods: [Int],
							   weekOffset: Int = 0) -> Date? {
		let calendar = Calendar.current
		let startWeekday = calendar.component(.weekday, from: startDate)
		var dayDiff = weekday - startWeekday
		if dayDiff < 0 { dayDiff += 7 }
		
		// 加上第幾週
		dayDiff += weekOffset * 7
		
		guard let targetDate = calendar.date(
			byAdding: .day,
			value: dayDiff,
			to: startDate
		) else { return nil }
		
		let startTimeString = getStartTime(for: periods.first ?? 1)
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyy-MM-dd HH:mm"
		
		let datePart = formatter.string(from: targetDate).prefix(10)
		let fullString = "\(datePart) \(startTimeString)"
		
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
	
	// MARK: - 匯出到 Google Calendar (簡單版, 使用 selectedCalendarId)
	
	func exportToGoogleCalendar(using signInManager: GoogleSignInManager) async -> (Bool, String) {
		guard let user = signInManager.user else {
			return (false, "請先在「設定」頁登入 Google 帳號")
		}
		
		let accessToken = user.accessToken.tokenString
		if accessToken.isEmpty {
			return (false, "找不到 Google 存取權杖")
		}
		
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
			guard let startDate = calculateDate(weekday: course.weekday, periods: course.periods) else {
				failCount += 1
				continue
			}
			
			let duration = TimeInterval(50 * 60 * course.periods.count)
			let endDate = startDate.addingTimeInterval(duration)
			
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
	
	// MARK: - Google Calendar 列表 (設定頁用)
	
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
			
			self.googleCalendars = decoded.items
			
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
	
	// MARK: - Google Calendar 進階功能
	
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
	
	func exportToGoogleCalendar(using manager: GoogleSignInManager,
								calendarID: String,
								weeks: Int = 16) async -> (Bool, String) {
		guard let token = manager.accessToken else {
			return (false, "請先在設定頁登入 Google 帳號")
		}
		
		let targets = courses.filter { $0.isSelected }
		if targets.isEmpty {
			return (false, "目前沒有選取要匯出的課程")
		}
		
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
			}
		}
		
		return (true, "已匯出課程到 Google 行事曆")
	}
	func deleteCourses(_ targets: [Course], inSemesterId semesterId: UUID) {
		guard let idx = semesters.firstIndex(where: { $0.id == semesterId }) else { return }
		
		semesters[idx].courses.removeAll { course in
			targets.contains(course)
		}
		
		// 如果剛好是目前學期也要同步更新畫面上的 courses
		if semesterId == currentSemesterId {
			courses = semesters[idx].courses
		}
		
		saveSemestersToStorage()
	}
	// MARK: - 本地通知

	func requestNotificationAuthorization() {
		let center = UNUserNotificationCenter.current()
		center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
			if let error = error {
				print("Notification auth error:", error)
			} else {
				print("Notification granted:", granted)
			}
		}
	}

	/// 重新排程所有「已勾選」課程的通知
	func rescheduleAllClassNotifications() {
		let center = UNUserNotificationCenter.current()
		
		// 先清掉舊的課程通知（這裡示範直接全清）
		center.removeAllPendingNotificationRequests()
		
		let selectedCourses = courses.filter { $0.isSelected }
		guard notifyMinutesBeforeLocal > 0, !selectedCourses.isEmpty else { return }
		
		for course in selectedCourses {
			scheduleNotifications(for: course, center: center)
		}
	}

	/// 為單一課程排 16 週的提醒（你可以依學期長度調整）
	private func scheduleNotifications(for course: Course,
									   center: UNUserNotificationCenter,
									   weeks: Int = 16) {
		for weekOffset in 0..<weeks {
			guard let classDate = calculateDate(
				weekday: course.weekday,
				periods: course.periods,
				weekOffset: weekOffset
			) else { continue }
			
			// 提前 N 分鐘
			let fireDate = classDate.addingTimeInterval(
				TimeInterval(-notifyMinutesBeforeLocal * 60)
			)
			if fireDate < Date() { continue }  // 過去的時間不用排
			
			let content = UNMutableNotificationContent()
			content.title = course.name
			content.body = "即將上課：\(course.rawTime) \(course.location)（\(course.teacher)）"
			content.sound = .default
			
			let comps = Calendar.current.dateComponents(
				[.year, .month, .day, .hour, .minute],
				from: fireDate
			)
			
			let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
			
			// 用課名 + 星期 + 週次當作 id，方便之後如果要精準移除
			let identifier = "course_\(course.name)_\(course.weekday)_\(weekOffset)"
				.replacingOccurrences(of: " ", with: "_")
			
			let request = UNNotificationRequest(
				identifier: identifier,
				content: content,
				trigger: trigger
			)
			
			center.add(request) { error in
				if let error = error {
					print("Add notification error:", error)
				}
			}
		}
	}
}

