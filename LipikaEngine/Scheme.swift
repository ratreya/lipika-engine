/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import Foundation

class Scheme {
    // Class->Key->(Scheme, Script)
    let mappings: [String:OrderedMap<String, (String, String)>]
    // Script->(Scheme, Class, Key)
    private (set) var reverseMap: [String:(String, String, String)]
    // Scheme->(Script, Class, Key)
    private (set) var forwardMap: [String:(String, String, String)]
    
    init(mappings: [String:OrderedMap<String, (String, String)>]) {
        self.mappings = mappings
        reverseMap = [String:(String, String, String)]()
        forwardMap = [String:(String, String, String)]()
        for type in mappings.keys {
            for key in mappings[type]!.keys {
                reverseMap.updateValue((mappings[type]![key]!.0, type, key), forKey: mappings[type]![key]!.1)
                forwardMap.updateValue((mappings[type]![key]!.1, type, key), forKey: mappings[type]![key]!.0)
            }
        }
    }
}
