/*
 * LipikaIME is a user-configurable phonetic Input Method Engine for Mac OS X.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import Foundation

class Engine {
    let imeRules: [String]
    let scheme: Scheme
    
    init(imeRules: [String], scheme: Scheme) {
        self.imeRules = imeRules
        self.scheme = scheme
    }
}
