// IcoNVader (ricostruzione macOS) — preferenze persistenti e caricamento dei set di icone.

import AppKit
import ScreenSaver

/// Preferenze salvate con ScreenSaverDefaults (dominio = identificatore del bundle).
enum PreferencesStore {
    private static var moduleName: String {
        Bundle(for: IcoNVaderView.self).bundleIdentifier ?? "io.github.robertod91.IcoNVader"
    }

    private static var defaults: UserDefaults? {
        ScreenSaverDefaults(forModuleWithName: moduleName)
    }

    static func load() -> IVPreferences {
        guard let defaults else { return IVPreferences() }
        return IVPreferences(dictionary: defaults.dictionaryRepresentation())
    }

    static func save(_ prefs: IVPreferences) {
        guard let defaults else { return }
        for (key, value) in prefs.clamped().dictionary { defaults.set(value, forKey: key) }
        defaults.synchronize()
    }
}

/// Set di icone: come nell'originale vengono cercati nelle risorse del bundle e nelle cartelle
/// Application Support (di sistema e dell'utente). Ogni set è una cartella di file .icns o .png.
enum IconLibrary {
    private static var searchFolders: [URL] {
        var urls: [URL] = []
        if let res = Bundle(for: IcoNVaderView.self).resourceURL {
            urls.append(res.appendingPathComponent("Icon Sets", isDirectory: true))
        }
        for domain in [FileManager.SearchPathDomainMask.localDomainMask, .userDomainMask] {
            if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: domain).first {
                urls.append(support.appendingPathComponent("IcoNVader/Icon Sets", isDirectory: true))
            }
        }
        return urls
    }

    /// Nomi dei set disponibili, in ordine alfabetico.
    static func availableSets() -> [String] {
        var names = Set<String>()
        for folder in searchFolders {
            let items = (try? FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)) ?? []
            for item in items where (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                names.insert(item.lastPathComponent)
            }
        }
        return names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    static func iconURLs(forSet name: String) -> [URL] {
        for folder in searchFolders.reversed() { // le cartelle dell'utente hanno la precedenza
            let dir = folder.appendingPathComponent(name, isDirectory: true)
            let files = (try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
            let icons = files.filter { ["icns", "png"].contains($0.pathExtension.lowercased()) }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            if !icons.isEmpty { return icons }
        }
        return []
    }

    /// Carica le icone del set come CGImage 128×128 (la rappresentazione 'it32' dei file .icns).
    static func loadImages(forSet name: String) -> [CGImage] {
        var urls = iconURLs(forSet: name)
        if urls.isEmpty { urls = iconURLs(forSet: IVPreferences().iconSet) }
        return urls.compactMap { url in
            guard let image = NSImage(contentsOf: url) else { return nil }
            var rect = NSRect(x: 0, y: 0, width: 128, height: 128)
            return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        }
    }
}
