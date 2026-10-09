import Foundation

public enum ModeError: Error, Equatable {
    case emptyName
    case nameTooLong
    case duplicateName
    case notFound
    case lastMode
    case limitReached
}

extension ModeError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .emptyName: return "Mod adı boş olamaz."
        case .nameTooLong: return "Mod adı en fazla \(ModeLibrary.maxNameLength) karakter olabilir."
        case .duplicateName: return "Bu isimde bir mod zaten var."
        case .notFound: return "Mod bulunamadı."
        case .lastMode: return "Son mod silinemez."
        case .limitReached: return "En fazla \(ModeLibrary.maxModes) mod olabilir."
        }
    }
}

/// The user's modes. Always holds at least one mode when built through `starter` / `migrating`.
public struct ModeLibrary: Codable, Equatable, Sendable {
    public static let maxModes = 20
    public static let maxNameLength = 40

    public private(set) var modes: [FocusMode]

    public init(modes: [FocusMode] = []) {
        self.modes = modes
    }

    public func mode(id: UUID) -> FocusMode? {
        modes.first { $0.id == id }
    }

    public mutating func add(_ mode: FocusMode) throws {
        guard modes.count < Self.maxModes else { throw ModeError.limitReached }
        var new = mode
        new.name = try validatedName(mode.name, excluding: nil)
        modes.append(new)
    }

    public mutating func update(_ mode: FocusMode) throws {
        guard let index = modes.firstIndex(where: { $0.id == mode.id }) else { throw ModeError.notFound }
        var updated = mode
        updated.name = try validatedName(mode.name, excluding: mode.id)
        modes[index] = updated
    }

    public mutating func delete(id: UUID) throws {
        guard let index = modes.firstIndex(where: { $0.id == id }) else { throw ModeError.notFound }
        guard modes.count > 1 else { throw ModeError.lastMode }
        modes.remove(at: index)
    }

    /// Inserts a copy right after the source and returns it.
    @discardableResult
    public mutating func duplicate(id: UUID) throws -> FocusMode {
        guard let index = modes.firstIndex(where: { $0.id == id }) else { throw ModeError.notFound }
        guard modes.count < Self.maxModes else { throw ModeError.limitReached }

        var copy = modes[index]
        copy.id = UUID()
        var candidate = "\(copy.name) kopya"
        var number = 2
        while isNameTaken(candidate, excluding: nil) {
            candidate = "\(copy.name) kopya \(number)"
            number += 1
        }
        copy.name = candidate
        modes.insert(copy, at: index + 1)
        return copy
    }

    // MARK: - Starter content

    public static func starter() -> ModeLibrary {
        migrating(legacySites: [], legacyApps: [])
    }

    /// Starter modes. Sites and apps from the old single-list version go into "Sosyal Medya",
    /// and "Derin Odak" is the union of everything.
    public static func migrating(legacySites: [String], legacyApps: [BlockedApp]) -> ModeLibrary {
        var social = FocusMode(name: "Sosyal Medya", symbol: "bubble.left.and.bubble.right.fill", color: .pink)
        let socialSites = legacySites.isEmpty && legacyApps.isEmpty ? DefaultBlockList.socialSites : legacySites
        socialSites.forEach { social.addSite($0) }
        legacyApps.forEach { social.addApp($0) }

        var work = FocusMode(name: "Çalışma", symbol: "briefcase.fill", color: .blue)
        DefaultBlockList.workSites.forEach { work.addSite($0) }

        var deep = FocusMode(name: "Derin Odak", symbol: "moon.stars.fill", color: .purple)
        (social.sites + work.sites + DefaultBlockList.deepFocusExtraSites).forEach { deep.addSite($0) }
        social.apps.forEach { deep.addApp($0) }

        return ModeLibrary(modes: [social, work, deep])
    }

    // MARK: - Names

    private func isNameTaken(_ name: String, excluding id: UUID?) -> Bool {
        modes.contains {
            $0.id != id && $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    private func validatedName(_ raw: String, excluding id: UUID?) throws -> String {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ModeError.emptyName }
        guard name.count <= Self.maxNameLength else { throw ModeError.nameTooLong }
        guard !isNameTaken(name, excluding: id) else { throw ModeError.duplicateName }
        return name
    }
}
