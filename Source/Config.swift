/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

struct Config {
    static var stopCharacter: Character { return "\\" }
    static var schemesDirectory: URL { return Bundle.main.bundleURL.appendingPathComponent("Schemes") }
    static var logLevel: Logger.Level { return .Warning }
}
