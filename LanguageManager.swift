//
//  LanguageManager.swift
//  NTU-Course2Cal
//
//  Created by Brian Lee on 12/8/25.
//


import Foundation

class LanguageManager {
    static func localizedString(_ key: String) -> String {
        let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "zh-Hant"

        guard let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, comment: "")
        }

        return NSLocalizedString(key, tableName: nil, bundle: bundle, value: "", comment: "")
    }
}