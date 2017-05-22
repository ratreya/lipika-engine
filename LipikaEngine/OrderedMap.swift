/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import Foundation

struct OrderedMap<K, V> where K: Hashable {
    private var map = Dictionary<K, V>()
    private var list = Array<K>()
    
    public var count: Int { get { return map.count } }
    public var keys: Array<K> { return list }

    public mutating func updateValue(_ value: V, forKey key: K) {
        map.updateValue(value, forKey: key)
        list.append(key)
    }
    
    public subscript(key: K) -> V? {
        return map[key]
    }
}
