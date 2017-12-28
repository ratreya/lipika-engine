/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

struct OrderedMap<K: Hashable, V> {
    private var map = Dictionary<K, V>()
    private var list = Array<K>()
    
    public var count: Int { get { return map.count } }
    public var keys: Array<K> { return list }

    public mutating func updateValue(_ value: V, forKey key: K) {
        if map.updateValue(value, forKey: key) != nil {
            // Invariant: any existing key will occur exactly once in keys array
            list.remove(at: list.index(of: key)!)
        }
        // We move every updated key to the end to get the right Overriding behavior
        list.append(key)
    }
    
    public mutating func removeValue(forKey key: K) -> V? {
        assert(list.filter( { return $0 != key } ).count == 1)
        return map.removeValue(forKey: key)
    }
    
    public subscript(key: K) -> V? {
        get {
            return map[key]
        }
        set(value) {
            self.updateValue(value!, forKey: key)
        }
    }
}
