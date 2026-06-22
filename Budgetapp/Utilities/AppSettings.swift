import Foundation

/// Lightweight user preferences stored in `UserDefaults`. Kept tiny and offline;
/// no analytics, no remote config.
enum AppSettings {
    private enum Keys {
        static let currencyCode = "settings.currencyCode"
        static let hapticsEnabled = "settings.hapticsEnabled"
    }

    static var currencyCode: String {
        get { UserDefaults.standard.string(forKey: Keys.currencyCode) ?? "INR" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.currencyCode) }
    }

    static var currencySymbol: String {
        let locale = Locale(identifier: "en_IN")
        if currencyCode == "INR" { return "₹" }
        return locale.localizedString(forCurrencyCode: currencyCode) ?? currencyCode
    }

    static var hapticsEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Keys.hapticsEnabled) == nil { return true }
            return UserDefaults.standard.bool(forKey: Keys.hapticsEnabled)
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.hapticsEnabled) }
    }

    /// Currencies offered in Settings.
    static let supportedCurrencies = ["INR", "USD", "EUR", "GBP", "AUD", "CAD", "SGD", "AED"]
}
