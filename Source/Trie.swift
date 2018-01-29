/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

extension Trie where Key.Element: RuleInput, Value: RuleOutput {
    subscript(input: Key.Element) -> Trie? {
        get {
            if input.key == nil {
                return next[input]
            }
            // Try the most specific value first
            if let result = next[input] {
                return result
            }
            // If it does not exist, then try with just the type
            return next[RuleInput(type: input.type) as! Key.Element]
        }
        set(value) {
            next[input] = value
        }
    }
}

class Trie<Key: RangeReplaceableCollection, Value: CustomStringConvertible> where Key.Element: Hashable, Key.Element: CustomStringConvertible {
    private var next = [Key.Element: Trie]()
    private var _parent: Trie?
    private var _root: Trie?
    private (set) var keyElement: Key.Element?
    private (set) var value: Value?
    var parent: Trie { return _parent == nil ? self : _parent! }
    var root: Trie { return _root == nil ? self : _root! }
    var isRoot: Bool { return _parent == nil }
    var isLeaf: Bool { return next.isEmpty }
    var key: Key {
        if isRoot { return Key() }
        var result = parent.key
        result.append(keyElement!)
        return result
    }

    static func += (lhs: Trie, rhs: Trie) {
        lhs.merge(otherTrie: rhs) { old, new in
            Logger.log.warning("Replacing \(old?.description ?? "nil") with \(new?.description ?? "nil")")
            return new
        }
    }
    
    var description: String {
        return next.reduce("") { (previous, current) -> String in
            return previous + "\(value?.description ?? "nil") =\"\(current.key)\"=> \(current.value.value?.description ?? "nil")\n"
                + current.value.description
        }
    }
    
    private func updateRoot() {
        _root = parent.root
        next.forEach() { $0.value.updateRoot() }
    }
    
    init(_ value: Value? = nil) {
        self.value = value
    }

    func merge(otherTrie: Trie, resolver: (_ old: Value?, _ new: Value?) -> Value?) {
        value = (value == nil ? otherTrie.value : resolver(value, otherTrie.value))
        otherTrie.next.forEach() { body in
            if let mySubTrie = next[body.key] {
                Logger.log.debug("Merging key: \(body.key)")
                mySubTrie.merge(otherTrie: body.value, resolver: resolver)
            }
            else {
                self[body.key] = body.value
            }
        }
    }
    
    subscript(input: Key.Element) -> Trie? {
        get {
            return next[input]
        }
        set(value) {
            value?._parent = self
            value?.keyElement = input
            value?.updateRoot()
            next[input] = value
        }
    }

    subscript(input: Key.Element, default defaultValue: @autoclosure() -> Trie) -> Trie? {
        get {
            return self[input] ?? defaultValue()
        }
        set(value) {
            self[input] = value
        }
    }
    
    subscript(inputs: Key) -> Value? {
        get {
            switch inputs.count {
            case 0:
                return value
            case 1:
                return self[inputs.first!]?.value
            default:
                var inputs = inputs
                return self[inputs.removeFirst()]?[inputs]
            }
        }
        set(value) {
            switch inputs.count {
            case 0:
                self.value = value
            case 1:
                if self[inputs.first!] == nil {
                    self[inputs.first!] = Trie(value)
                }
                else {
                    self[inputs.first!]!.value = value
                }
            default:
                var inputs = inputs
                let current = inputs.removeFirst()
                if self[current] == nil {
                    self[current] = Trie()
                }
                self[current]![inputs] = value
            }
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
