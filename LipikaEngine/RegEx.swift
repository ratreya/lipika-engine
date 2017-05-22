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
    private var input: String?
    private var matches: [NSTextCheckingResult]?
    
    init(pattern: String) throws {
        self.pattern = try NSRegularExpression(pattern: pattern, options: [])
    }
    
    static func =~ (regex: RegEx, input: String) -> Bool {
        regex.input = input
        regex.matches = regex.pattern.matches(in: input, options: [], range: NSRange(location: 0, length: input.lengthOfBytes(using: .utf8)))
        return !regex.matches!.isEmpty
    }
    
    func matching() -> [String]? {
        if let matches = self.matches, let input = self.input {
            return matches.flatMap({ (input as NSString).substring(with: $0.rangeAt(0)) })
        }
        else {
            return nil
        }
    }
    
    func captured(match: Int, at: Int) -> String? {
        if let matches = matches?[match], matches.numberOfRanges > at + 1 {
            let range = matches.rangeAt(at + 1)
            if range.length == 0 { return nil }
            return (input as NSString?)?.substring(with: range)
        }
        else {
            return nil
        }
    }
}
