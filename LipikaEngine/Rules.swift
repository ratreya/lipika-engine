/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

struct Output {
    private var ouputRule: String
    private let kOutputPattern: RegEx
    
    init(rule: String) throws {
        self.ouputRule = rule
        self.kOutputPattern = try RegEx(pattern: "\\[\\$([0-9]+)\\]")
    }
    
    func generate(intermediates: [String]) -> String {
        var result = ouputRule
        while (kOutputPattern =~ result) {
            let index = Int(kOutputPattern.captured()!)! - 1
            result = kOutputPattern.replacing(with: intermediates[index])!
        }
        return result
    }
}

typealias RulesTrie = Trie<[String], Output>

class Rules {
    private let kSpecificValuePattern: RegEx
    private let kMapStringSubPattern: RegEx
    
    internal let scheme: Scheme
    private (set) var rulesTrie = RulesTrie()
    
    init(imeRules: [String], scheme: Scheme) throws {
        self.scheme = scheme
        kSpecificValuePattern = try RegEx(pattern: "[\\{\\[]([^\\{\\[]+/[^\\{\\[]+)[\\}\\]]")
        kMapStringSubPattern = try RegEx(pattern: "(\\[[^\\]]+?\\]|\\{[^\\}]+?\\})")
        
        for imeRule in imeRules {
            if imeRule.isEmpty { continue }
            let components = imeRule.components(separatedBy: "\t")
            if components.count != 2 {
                throw EngineError.parseError("IME Rule not two column TSV: \(imeRule)")
            }
            if kMapStringSubPattern =~ components[0] {
                let inputs = kMapStringSubPattern.allMatching()!.map({ $0.trimmingCharacters(in: CharacterSet(charactersIn: "{}")) })
                let output = try expandMappingRefs(components[1])
                rulesTrie[inputs] = try Output(rule: output)
            }
            else {
                throw EngineError.parseError("Input part: \(components[0]) of IME Rule: \(imeRule) cannot be parsed")
            }
        }
    }
    
    func state(for input: (class: String, key: String), at state: RulesTrie? = nil) -> RulesTrie? {
        let state = state ?? self.rulesTrie
        // Try most specific mapping first
        if let nextState = state["\(input.class)/\(input.key)"] {
            return nextState
        }
        else {
            return state[input.class]
        }
    }
    
    private func expandMappingRefs(_ input: String) throws -> String {
        var result = input
        while (kSpecificValuePattern =~ result) {
            let match = kSpecificValuePattern.matching()!
            let components = kSpecificValuePattern.captured()!.components(separatedBy: "/")
            if let map = scheme.mappings[components[0]]?[components[1]] {
                let replacement = match.hasPrefix("{") ? map.scheme[0] : map.script
                result = kSpecificValuePattern.replacing(with: replacement)!
            }
            else {
                throw EngineError.parseError("Cannot find mapping for \(match)")
            }
        }
        return result
    }
}
