/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

class RuleOutput: CustomStringConvertible {
    enum Parts {
        case replacent(String)
        case fixed(String)
    }
    
    private let output: [Parts]
    
    var description: String {
        return output.description
    }
    
    init(output: [Parts]) throws {
        self.output = output
    }
    
    func generate(replacement: [String: String]) -> String {
        return output.reduce("") { (previous, delta) -> String in
            switch delta {
            case .replacent(let type):
                return previous + (replacement[type] ?? "")
            case .fixed(let fixed):
                return previous + fixed
            }
        }
    }
}

class RuleInput: Hashable, CustomStringConvertible {
    private var _replacentKey: String?
    private (set) var type: String
    private (set) var key: String?
    var replacentKey: String { return _replacentKey ?? type }

    var description: String {
        return key == nil ? type : "\(type)/\(key!)"
    }

    init(type: String) {
        let pieces = type.components(separatedBy: ":")
        if pieces.count > 1 {
            _replacentKey = type
            self.type = pieces[1]
        }
        else {
            self.type = type
        }
    }
    
    init(type: String, key: String) {
        self.type = type
        self.key = key
    }
    
    var hashValue: Int {
        if let key = key {
            return (type.hashValue << 5) &+ type.hashValue &+ key.hashValue /* djb2 */
        }
        return type.hashValue
    }

    static func == (lhs: RuleInput, rhs: RuleInput) -> Bool {
        return lhs.type == rhs.type && lhs.key == rhs.key
    }
}

struct TrieValue: CustomStringConvertible {
    var output: String?
    var type: String
    var key: String
    var description: String {
        return "\(type)/\(key):\(output ?? "nil")"
    }
}

typealias MappingValue = OrderedMap<String, (scheme: [String], script: String?)>
typealias MappingTrie = Trie<String, [TrieValue]>
typealias RulesTrie = Trie<[RuleInput], RuleOutput>

class Rules {
    private let kSpecificValuePattern: RegEx
    private let kMapStringSubPattern: RegEx
    /// Type->Key->([Scheme], Script)
    private let mappings: [String: MappingValue]

    private (set) var rulesTrie = RulesTrie()
    private (set) var mappingTrie = MappingTrie()

    init(imeRules: [String], mappings: [String: MappingValue]) throws {
        kSpecificValuePattern = try RegEx(pattern: "[\\{\\[]([^\\{\\[]+/[^\\{\\[]+)[\\}\\]]")
        kMapStringSubPattern = try RegEx(pattern: "(\\[[^\\]]+?\\]|\\{[^\\}]+?\\})")
        self.mappings = mappings
        for type in mappings.keys {
            for key in mappings[type]!.keys {
                let script = mappings[type]![key]!.script
                let scheme = mappings[type]![key]!.scheme
                for input in scheme {
                    mappingTrie[input, default: [TrieValue]()]!.append(TrieValue(output: script, type: type, key: key))
                }
            }
        }
        for imeRule in imeRules {
            if imeRule.isEmpty { continue }
            let components = imeRule.components(separatedBy: "\t")
            guard components.count == 2 else {
                throw EngineError.parseError("IME Rule not two column TSV: \(imeRule)")
            }
            guard kMapStringSubPattern =~ components[0] else {
                throw EngineError.parseError("Input part: \(components[0]) of IME Rule: \(imeRule) cannot be parsed")
            }
            let inputStrings = kMapStringSubPattern.allMatching()!.map() { $0.trimmingCharacters(in: CharacterSet(charactersIn: "{}[]")) }
            let inputs = inputStrings.flatMap(){ (inputString) -> RuleInput in
                let parts = inputString.components(separatedBy: "/")
                return parts.count > 1 ? RuleInput(type: parts[0], key: parts[1]): RuleInput(type: parts[0])
            }
            guard kMapStringSubPattern =~ components[1] else {
                throw EngineError.parseError("Output part: \(components[1]) of IME Rule: \(imeRule) cannot be parsed")
            }
            let outputStrings = kMapStringSubPattern.allMatching()!
            let outputs = try outputStrings.flatMap({ (outputString) -> RuleOutput.Parts in
                let rulePart = outputString.trimmingCharacters(in: CharacterSet(charactersIn: "{}[]"))
                let pieces = rulePart.components(separatedBy: "/")
                switch pieces.count {
                case 1:
                    return .replacent(pieces[0])
                case 2:
                    guard let map = mappings[pieces[0]]?[pieces[1]] else {
                        throw EngineError.parseError("Cannot find mapping for \(outputString)")
                    }
                    let replacement = outputString.hasPrefix("{") ? map.scheme[0] : map.script
                    return .fixed(replacement!)
                default:
                    throw EngineError.parseError("Unable to component: \(outputString) of rule: \(imeRule)")
                }
            })
            rulesTrie[inputs] = try RuleOutput(output: outputs)
        }
    }
}
