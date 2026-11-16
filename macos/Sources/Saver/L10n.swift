// IcoNVader (ricostruzione macOS) — traduzioni.
//
// I testi stanno in Resources/<lingua>.lproj/Localizable.strings, generati da i18n/stringhe.json
// (inglese e francese sono quelli dell'originale). La lingua segue quella del sistema; per i collaudi
// si può forzare con la variabile d'ambiente ICONVADER_LANG (en, fr, it).

import Foundation

enum L10n {
    static let supported = ["en", "fr", "it"]
    private static let bundle = Bundle(for: IcoNVaderView.self)

    /// Lingua attiva: quella del sistema tra le disponibili, altrimenti inglese (come l'originale).
    static var language: String {
        if let forced = ProcessInfo.processInfo.environment["ICONVADER_LANG"], supported.contains(forced) {
            return forced
        }
        let preferred = Bundle.preferredLocalizations(from: supported, forPreferences: Locale.preferredLanguages)
        return preferred.first.flatMap { supported.contains($0) ? $0 : nil } ?? "en"
    }

    private static var cache: (language: String, table: [String: String])?

    private static var table: [String: String] {
        let lang = language
        if let cache, cache.language == lang { return cache.table }
        var table: [String: String] = [:]
        if let path = bundle.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: lang),
           let dict = NSDictionary(contentsOfFile: path) as? [String: String] {
            table = dict
        }
        cache = (lang, table)
        return table
    }

    /// Testo tradotto per la chiave; se manca, la chiave stessa.
    static func t(_ key: String) -> String { table[key] ?? key }

    /// Nome tradotto di un comportamento (chiave "behavior.<identificatore>").
    static func behaviorName(_ identifier: String) -> String { t("behavior.\(identifier)") }
}
