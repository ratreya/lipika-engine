/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

class Trie<Key: RangeReplaceableCollection, Value: CustomStringConvertible> where Key.Element: Hashable {
    internal var next = [Key.Element: Trie]()
    private var _parent: Trie?
    private var _root: Trie?
    private (set) var value: Value?
    var parent: Trie { return _parent == nil ? self : _parent! }
    var root: Trie { return _root == nil ? self : _root! }
    
    var description: String {
        return next.reduce("", { (previous, current) -> String in
            return previous + "\(value?.description ?? "nil") =\"\(current.key)\"=> \(current.value.value?.description ?? "nil")\n"
                + current.value.description // Recurse
        })
    }
    
    private func updateRoot() {
        _root = parent.root
        next.forEach( { $0.value.updateRoot() } )
    }
    
    init(_ value: Value? = nil) {
        self.value = value
    }

    subscript(input: Key.Element) -> Trie? {
        get {
            return next[input]
        }
        set(value) {
            value?._parent = self
            value?.updateRoot()
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
                return self[inputs.first!]?.value
            }
            var inputs = inputs
            return self[inputs.removeFirst()]?[inputs]
        }
        set(value) {
            assert(inputs.count > 0, "Index out of range")
            if inputs.count == 1 {
                if self[inputs.first!] == nil {
                    self[inputs.first!] = Trie(value)
                }
                else {
                    self[inputs.first!]!.value = value
                }
                return
            }
            var inputs = inputs
            let current = inputs.removeFirst()
            if self[current] == nil {
                self[current] = Trie()
            }
            self[current]![inputs] = value
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
