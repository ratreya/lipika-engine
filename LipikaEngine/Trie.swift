/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

class Trie<Key: RangeReplaceableCollection, Value> where Key.Element: Hashable {
    internal var next = [Key.Element: Trie]()
    private (set) var value: Value?
    
    var description: String {
        return next.reduce("", { (previous, current) -> String in
            return previous + "\(value.debugDescription) =\"\(current.key)\"=> \(current.value.value.debugDescription)\n"
                + current.value.description
        })
    }
    
    init(_ value: Value? = nil) {
        self.value = value
    }
    
    func keyPrefixExists(_ prefix: Key) -> Bool {
        if prefix.count <= 0 {
            return true
        }
        var prefix = prefix
        return next[prefix.removeFirst()] != nil && keyPrefixExists(prefix)
    }

    subscript(input: Key.Element) -> Trie? {
        get {
            return next[input]
        }
        set(value) {
            next[input] = value
        }
    }

    subscript(inputs: Key.Element, default defaultValue: @autoclosure() -> Trie) -> Trie? {
        get {
            return self[inputs] ?? defaultValue()
        }
        set(value) {
            self[inputs] = value
        }
    }
    
    subscript(inputs: Key) -> Value? {
        get {
            assert(inputs.count > 0, "Index out of range")
            if inputs.count == 1 {
                return next[inputs.first!]?.value
            }
            var inputs = inputs
            return next[inputs.removeFirst()]?[inputs]
        }
        set(value) {
            assert(inputs.count > 0, "Index out of range")
            if inputs.count == 1 {
                next[inputs.first!] = Trie(value)
                return
            }
            var inputs = inputs
            let current = inputs.removeFirst()
            if next[current] == nil {
                next[current] = Trie()
            }
            next[current]![inputs] = value
        }
    }

    subscript(inputs: Key, default defaultValue: @autoclosure() -> Value) -> Value? {
        get {
            return self[inputs] ?? defaultValue()
        }
        set(value) {
            self[inputs] = value
        }
    }
}
