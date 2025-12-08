//
//  GoogleSignInManager.swift
//  NTU Course2Cal
//
//  Created by Brian Lee on 12/6/25.
//

import Foundation
import GoogleSignIn
import Combine

class GoogleSignInManager: ObservableObject {
	@Published var user: GIDGoogleUser?

	/// 動態從目前 user 取 access token
	var accessToken: String? {
		user?.accessToken.tokenString
	}

	/// 你需要的 scope
	let scopes = [
		"https://www.googleapis.com/auth/calendar",
		"https://www.googleapis.com/auth/calendar.readonly",
		"https://www.googleapis.com/auth/calendar.events"
	]

	init() {
		restorePreviousSignIn()
	}

	/// 嘗試還原前一次登入狀態
	func restorePreviousSignIn() {
		GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
			if let error = error {
				print("restorePreviousSignIn error:", error)
				DispatchQueue.main.async {
					self?.user = nil
				}
				return
			}

			DispatchQueue.main.async {
				self?.user = user
				if let u = user {
					print("restorePreviousSignIn success, user:", u.profile?.email ?? "no email")
				} else {
					print("restorePreviousSignIn: no previous user")
				}
			}
		}
	}

	/// 顯示 Google 登入畫面
	func signIn(presenting viewController: UIViewController) {
		let clientID = "385739338581-rc0bt06q6k5q8i1ormpc54uupmolpngv.apps.googleusercontent.com"

		GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

		GIDSignIn.sharedInstance.signIn(
			withPresenting: viewController,
			hint: nil,
			additionalScopes: scopes
		) { [weak self] result, error in
			guard let self = self else { return }

			if let error = error {
				print("Google sign in error:", error)
				return
			}

			guard let result = result else {
				print("Google sign in: result is nil")
				return
			}

			DispatchQueue.main.async {
				self.user = result.user
				print("Google sign in success. Access token:", result.user.accessToken.tokenString)
			}
		}
	}

	/// 登出，清乾淨本地狀態
	func signOut() {
		GIDSignIn.sharedInstance.signOut()
		DispatchQueue.main.async {
			self.user = nil
		}
	}
}
