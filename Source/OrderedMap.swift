/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

public struct OrderedMap<Key: Hashable, Value> {
    private var map = [Key: Value]()
    private var list = [Key]()
    
    public var count: Int { get { return map.count } }
    public var keys: [Key] { return list }

    public mutating func updateValue(_ value: Value, forKey key: Key) {
        if map.updateValue(value, forKey: key) != nil {
            // Invariant: any existing key will occur exactly once in keys array
            list.remove(at: list.index(of: key)!)
        }
        // We move every updated key to the end to get the right Overriding behavior
        list.append(key)
    }

    public init() {}

    public init(_ map: [Key: Value]) {
        for key in map.keys {
            if let value = map[key] {
                updateValue(value, forKey: key)
            }
        }
    }

    public mutating func removeValue(forKey key: Key) -> Value? {
        list.remove(at: list.index(of: key)!)
        return map.removeValue(forKey: key)
    }

    public subscript(key: Key, default defaultValue: @autoclosure() -> Value) -> Value {
        get {
            return map[key] ?? defaultValue()
        }
        set(value) {
            self[key] = value
        }
    }

    public subscript(key: Key) -> Value? {
        get {
            return map[key]
        }
        set(value) {
            self.updateValue(value!, forKey: key)
        }
    }
    
    public mutating func removeAll() {
        list.removeAll()
        map.removeAll()
    }
}
