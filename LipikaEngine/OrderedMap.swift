/*
 * LipikaIME is a user-configurable phonetic Input Method Engine for Mac OS X.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import Foundation

struct OrderedMap<K, V> where K: Hashable {
    var map = Dictionary<K, V>()
    var list = Array<K>()
    
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
