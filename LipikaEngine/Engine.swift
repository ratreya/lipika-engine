/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import Foundation

class Engine {
    let rules: Rules
    private var current: State?
    private var inputs = [Character]()
    private var lastOutputIndex = 0

    init(rules: Rules) {
        self.rules = rules
    }
    
    func nextNode(for input: Character) -> State? {
        return nil
    }
}
