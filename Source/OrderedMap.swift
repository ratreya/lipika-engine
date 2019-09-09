/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

/**
 Dictionary with ordered enumeration of keys. Keys are sorted by increasing recency of creation/mutation.
 So, keys at the beginning were created/updated the longest time ago and the towards the end were recently created/updated.
 */
public struct OrderedMap<Key: Hashable, Value> {
    private var map = [Key: Value]()
    private var list = [Key]()

    /// The number of key-value pairs in the dictionary.
    public var count: Int { get { return map.count } }
    /// List containing keys of the dictionary in increasing order of recency.
    public var keys: [Key] { return list }

    /**
     Updates the value stored in the dictionary for the given key, or adds a new key-value pair if the key does not exist.
     The updated key is moved to the end of the sorted list of keys as it would now be the most recently updated key.
     - Complexity: O(n), where n is the number of key-value pairs in the dictionary.
     */
    @discardableResult public mutating func updateValue(_ value: Value, forKey key: Key) -> Value? {
        // We move every updated key to the end to get the right Overriding behavior
        list.append(key)
        if let old = map.updateValue(value, forKey: key) {
            // Invariant: any existing key will occur exactly once in keys array
            list.remove(at: list.firstIndex(of: key)!)
            return old
        }
        return nil
    }

    /// Initialize an empty data-structure.
    public init() {}

    /// Initialize the data-structure from the list of tuples. Later keys in the list override older keys.
    public init(_ map: [Key: Value]) {
        for key in map.keys {
            if let value = map[key] {
                updateValue(value, forKey: key)
            }
        }
    }

    /**
     Removes the given key and its associated value from the dictionary.
     - Complexity: O(n), where n is the number of key-value pairs in the dictionary.
     */
    public mutating func removeValue(forKey key: Key) -> Value? {
        // Invariant: any existing key will occur exactly once in keys array
        list.remove(at: list.firstIndex(of: key)!)
        return map.removeValue(forKey: key)
    }

    /// Get or set the value of the given key. `defaultValue` is not evaluated unless needed.
    public subscript(key: Key, default defaultValue: @autoclosure() -> Value) -> Value {
        get {
            return map[key] ?? defaultValue()
        }
        set(value) {
            self[key] = value
        }
    }

    /// Get or set the value of the given key.
    public subscript(key: Key) -> Value? {
        get {
            return map[key]
        }
        set(value) {
            self.updateValue(value!, forKey: key)
        }
    }
    
    /// Removes all key-value pairs from the dictionary.
    public mutating func removeAll() {
        list.removeAll()
        map.removeAll()
    }
}
