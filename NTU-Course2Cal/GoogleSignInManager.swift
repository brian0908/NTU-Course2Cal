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
	@Published var accessToken: String?
	
	// 必須包含建立 calendar、讀取清單、寫入事件
	let scopes = [
		"https://www.googleapis.com/auth/calendar",
		"https://www.googleapis.com/auth/calendar.readonly",
		"https://www.googleapis.com/auth/calendar.events"
	]
	
	func signIn(presenting viewController: UIViewController) {
		
		let clientID = "385739338581-rc0bt06q6k5q8i1ormpc54uupmolpngv.apps.googleusercontent.com"  // 你之前填的那個
		
		GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
		
		GIDSignIn.sharedInstance.signIn(
			withPresenting: viewController,
			hint: nil,
			additionalScopes: scopes
		) { [weak self] result, error in
			guard let self = self else { return }
			
			if let error = error {
				print("Google sign in error: \(error)")
				return
			}
			
			guard let result = result else {
				print("Google sign in: result is nil")
				return
			}
			
			self.user = result.user
			self.accessToken = result.user.accessToken.tokenString
			
			print("Google sign in success. Access token: \(self.accessToken ?? "nil")")
		}
	}
	
	func signOut() {
		GIDSignIn.sharedInstance.signOut()
		user = nil
		accessToken = nil
	}
}
