/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

struct ReverseTrieValue: CustomStringConvertible {
    var scheme: [String]
    var type: String
    var key: String
    var description: String {
        return "\(scheme)/\(type):\(key)"
    }
}

typealias MappingValue = OrderedMap<String, (scheme: [String], script: String?)>
typealias ReverseTrie = Trie<String, ReverseTrieValue>
typealias ForwardTrieValue = [(script: String?, type: String, key: String)]
typealias ForwardTrie = Trie<String, ForwardTrieValue>

class Scheme {
    /// Type->Key->([Scheme], Script)
    let mappings: [String: MappingValue]
    /// Script->([Scheme], Type, Key)
    private (set) var reverseTrie = ReverseTrie()
    /// Scheme->[(Script, Type, Key)]
    private (set) var forwardTrie = ForwardTrie()
    
    init(mappings: [String: MappingValue]) {
        self.mappings = mappings
        for type in mappings.keys {
            for key in mappings[type]!.keys {
                let script = mappings[type]![key]!.script
                let scheme = mappings[type]![key]!.scheme
                for input in scheme {
                    forwardTrie[input, default: ForwardTrieValue()]?.append((script, type, key))
                }
                if let script = script {
                    reverseTrie[script] = ReverseTrieValue(scheme: scheme, type: type, key: key)
                }
            }
        }
    }
}
