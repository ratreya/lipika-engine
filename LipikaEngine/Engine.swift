/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

struct Result {
    var input: String
    var output: String
    /*
     * If this is true then the output is final and will not be changed anymore.
     * Else the above output could be replaced by subsequent outputs until
     * a final output is encountered.
     */
    var isFinal: Bool?
    /*
     * If this is true then all outputs before this is final and will not be changed anymore.
     * Else the previous outputs could be replaced by subsequent outputs until a final output
     * is encountered.
     */
    var isPreviousFinal: Bool?
    
    init(input: String, output: String) {
        self.input = input
        self.output = output
    }

    init(inoutput: String) {
        self.input = inoutput
        self.output = inoutput
    }
}

class Engine {
    internal let rules: Rules
    
    private var current: RulesTrie?
    private var inputs = ""
    private var outputs = ""
    
    private var isAtRoot: Bool { return current == nil }

    init(rules: Rules) {
        self.rules = rules
    }
    
    private func reset() {
        current = nil
        inputs = ""
        outputs = ""
    }
    
    func execute(input: Character) throws -> Result {
        var result: Result
        if input == Config.stopCharacter {
            // Include in output only when it is a no-op
            if isAtRoot {
                inputs.append(input)
            }
            result = Result(inoutput: inputs)
            result.isPreviousFinal = true
            result.isFinal = true
            reset()
            return result
        }
        inputs.append(input)
        result = Result(inoutput: inputs)
        return result
    }
}
