/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import Foundation

infix operator =~

class RegEx {
    private let pattern: NSRegularExpression
    private var input: NSString?
    private var matches: [NSTextCheckingResult]?
    
    init(pattern: String) throws {
        self.pattern = try NSRegularExpression(pattern: pattern, options: [])
    }
    
    static func =~ (regex: RegEx, input: String) -> Bool {
        regex.input = input as NSString
        regex.matches = regex.pattern.matches(in: input, options: [], range: NSRange(location: 0, length: regex.input!.length))
        return regex.matches != nil && !regex.matches!.isEmpty
    }
    
    func allMatching() -> [String]? {
        guard let matches = self.matches, let input = self.input else { return nil }
        return matches.compactMap() { input.substring(with: $0.range) }
    }
    
    func matching(ordinal: Int = 0) -> String? {
        guard let matches = self.matches, let input = self.input else { return nil }
        return input.substring(with: matches[ordinal].range(at: 0))
    }
    
    func captured(match: Int = 0, capture: Int = 1) -> String? {
        guard let matches = self.matches, let input = self.input else { return nil }
        let range = matches[match].range(at: capture)
        if range.length == 0 { return nil }
        return input.substring(with: range)
    }
    
    func replacing(match: Int = 0, with replacement: String) -> String? {
        guard let matches = self.matches, let input = self.input else { return nil }
        return input.replacingCharacters(in: matches[match].range, with: replacement)
    }
}
