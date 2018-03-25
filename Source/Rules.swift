/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import Foundation

class RuleOutput: CustomStringConvertible {
    enum Parts: CustomStringConvertible {
        var description: String {
            switch self {
            case .fixed(let part): return "fixed(\(part))"
            case .replacent(let part): return "replacent(\(part))"
            }
        }
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
    
    func generate(replacement: OrderedMap<String, [String]>) -> String {
        var replacement = replacement
        return output.reduce("") { (previous, delta) -> String in
            switch delta {
            case .replacent(let type):
                // The assumption is that replacements for a given type are made in the same order as they were output
                return previous + (replacement[type] == nil ? "" : replacement[type]!.removeFirst())
            case .fixed(let fixed):
                return previous + fixed
            }
        }
    }
}

class RuleInput: Hashable, CustomStringConvertible {
    private (set) var type: String
    private (set) var key: String?

    var description: String {
        return key == nil ? type : "\(type)/\(key!)"
    }

    init(type: String) {
        self.type = type
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

class MappingOutput {
    private (set) var type: String
    private (set) var key: String
    private (set) var output: String?
    var ruleInput: RuleInput { return RuleInput(type: type, key: key) }
    
    var description: String {
        return "\(type)/\(key):\(output ?? "nil")"
    }
    
    init (output: String?, type: String, key: String) {
        self.type = type
        self.key = key
        self.output = output
    }
}

typealias MappingValue = OrderedMap<String, (scheme: [String], script: String?)>
typealias MappingTrie = Trie<[UnicodeScalar], [MappingOutput]>

class Rules {
    private let kSpecificValuePattern: RegEx
    private let kMapStringSubPattern: RegEx

    private (set) var rulesTrie = Trie<[RuleInput], RuleOutput>()
    private (set) var mappingTrie = MappingTrie()

    init(imeRules: [String], mappings: [String: MappingValue], isReverse: Bool = false) throws {
        kSpecificValuePattern = try RegEx(pattern: "[\\{\\[]([^\\{\\[]+/[^\\{\\[]+)[\\}\\]]")
        kMapStringSubPattern = try RegEx(pattern: "(\\[[^\\]]+?\\]|\\{[^\\}]+?\\})")
        /*
         To build a reverse mappingTrie, we first have to play out the overrides by expanding them into a dictionary. Otherwise, the following bug can come about: Let's say scheme A, B maps to script 1 and then later we override A to map to 2. If we build a reverse mappingTrie on this, 2 reverse maps to A and 1 reverse maps to A, B. Now 1 can reverse map to A but then when you forward map A, you don't get back 1 but rather you will get 2.
        */
        var overridden = [String: (String, MappingOutput)]()
        for type in mappings.keys {
            for key in mappings[type]!.keys {
                let script = mappings[type]![key]!.script
                let scheme = mappings[type]![key]!.scheme
                if isReverse {
                    if let script = script {
                        overridden["\(type)/\(key)/\(scheme[0])"] = (script, MappingOutput(output: scheme[0], type: type, key: key))  // Just choose the first option
                    }
                }
                else {
                    for input in scheme {
                        mappingTrie[Array(input.unicodeScalars), default: [MappingOutput]()]!.append(MappingOutput(output: script, type: type, key: key))
                    }
                }
            }
        }
        if isReverse {
            for value in overridden.values {
                mappingTrie[Array(value.0.unicodeScalars), default: [MappingOutput]()]!.append(value.1)
            }
        }
        for imeRule in imeRules {
            if imeRule.isEmpty { continue }
            let components = imeRule.components(separatedBy: "\t")
            guard components.count == 2 else {
                throw EngineError.parseError("IME Rule not two column TSV: \(imeRule)")
            }
            guard kMapStringSubPattern =~ components[isReverse ? 1 : 0] else {
                throw EngineError.parseError("Input part: \(components[isReverse ? 1 : 0]) of IME Rule: \(imeRule) cannot be parsed")
            }
            var inputStrings = kMapStringSubPattern.allMatching()!.map() { $0.trimmingCharacters(in: CharacterSet(charactersIn: "{}[]")) }
            if isReverse {
                inputStrings.reverse()
            }
            let inputs = inputStrings.flatMap(){ (inputString) -> RuleInput in
                let parts = inputString.components(separatedBy: "/")
                return parts.count > 1 ? RuleInput(type: parts[0], key: parts[1]): RuleInput(type: parts[0])
            }
            guard kMapStringSubPattern =~ components[isReverse ? 0 : 1] else {
                throw EngineError.parseError("Output part: \(components[isReverse ? 1 : 0]) of IME Rule: \(imeRule) cannot be parsed")
            }
            var outputStrings = kMapStringSubPattern.allMatching()!
            if isReverse {
                outputStrings.reverse()
            }
            let outputs = try outputStrings.flatMap() { (outputString) -> RuleOutput.Parts in
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
            }
            rulesTrie[inputs] = try RuleOutput(output: outputs)
        }
        // Set a custom subscript rule that matches a `type/key` to a `type` if `type\key` does not exist
        rulesTrie.setCustomSubscript { (input: RuleInput, map: [RuleInput: Trie<[RuleInput], RuleOutput>]) -> Trie<[RuleInput], RuleOutput>? in
            if input.key == nil {
                return map[input]
            }
            if let value = map[input] {
                return value
            }
            else {
                return map[RuleInput(type: input.type)]
            }
        }
    }
}
