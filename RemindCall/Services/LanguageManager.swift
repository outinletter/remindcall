import Foundation
import ObjectiveC
import SwiftUI

/// 앱 안에서 고르는 언어. 선택은 AppleLanguages(앱 전용)에 저장해 다음 실행에도 유지하고,
/// 실행 중에는 Bundle.main의 문자열 조회를 고른 언어의 lproj로 돌려 바로 바꾼다.
@Observable
final class LanguageManager {
    static let shared = LanguageManager()
    static let supported = ["ko", "en", "ja", "zh-Hans"]
    private static let storeKey = "appLanguage"

    /// "" = 시스템 설정 따름
    private(set) var code: String

    private init() {
        code = UserDefaults.standard.string(forKey: Self.storeKey) ?? ""
        LocalizedBundle.install()
        LocalizedBundle.select(code)
    }

    var locale: Locale {
        Locale(identifier: code.isEmpty ? (Bundle.main.preferredLocalizations.first ?? "ko") : code)
    }

    func set(_ newCode: String) {
        code = newCode
        let defaults = UserDefaults.standard
        if newCode.isEmpty {
            defaults.removeObject(forKey: Self.storeKey)
            defaults.removeObject(forKey: "AppleLanguages")
        } else {
            defaults.set(newCode, forKey: Self.storeKey)
            defaults.set([newCode], forKey: "AppleLanguages")
        }
        LocalizedBundle.select(newCode)
    }

    /// 언어 이름을 그 언어로 표기
    static func name(_ code: String) -> String {
        let locale = Locale(identifier: code)
        return locale.localizedString(forIdentifier: code)?.capitalized(with: locale) ?? code
    }
}

private var overrideKey = 0

/// Bundle.main의 문자열 조회만 고른 언어 lproj로 넘긴다.
private final class LocalizedBundle: Bundle, @unchecked Sendable {
    static func install() {
        guard !(Bundle.main is LocalizedBundle) else { return }
        object_setClass(Bundle.main, LocalizedBundle.self)
    }

    static func select(_ code: String) {
        let target = code.isEmpty ? nil : Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:))
        objc_setAssociatedObject(Bundle.main, &overrideKey, target, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let bundle = objc_getAssociatedObject(self, &overrideKey) as? Bundle {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    /// 앱에서 고른 언어의 문자열 번들(시스템 설정이면 main)
    static var app: Bundle {
        let code = LanguageManager.shared.code
        guard !code.isEmpty, let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return .main }
        return bundle
    }
}

/// 고른 앱 언어로 번역한 문자열. 화면 문구가 아닌 String 값에 쓴다.
func L(_ value: String.LocalizationValue) -> String {
    String(localized: value, bundle: .app, locale: LanguageManager.shared.locale)
}
