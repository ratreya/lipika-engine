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
     * If this is true then all outputs before this is final and will not be changed anymore.
     */
    var isPreviousFinal = false
    
    init(input: String, output: String, isPreviousFinal: Bool) {
        self.input = input
        self.output = output
        self.isPreviousFinal = isPreviousFinal
    }

    init(inoutput: String, isPreviousFinal: Bool) {
        self.input = inoutput
        self.output = inoutput
        self.isPreviousFinal = isPreviousFinal
    }
}

class Engine {
    private let forwardWalker: TrieWalker<String, ForwardTrieValue>

    private var rulesState: RulesTrie
    private var partInput = ""
    private var partOutput = [String]()

    init(rules: Rules) {
        rulesState = rules.rulesTrie
        forwardWalker = TrieWalker(trie: rules.scheme.forwardTrie)
    }
    
    private func resetRules() {
        partInput = ""
        partOutput = [String]()
        rulesState = rulesState.root
    }
    
    public func reset() {
        resetRules()
        forwardWalker.reset()
    }
    
    public func execute(inputs: String) throws -> [Result] {
        return try inputs.reduce([Result]()) { (previous, input) -> [Result] in
            let result = try execute(input: input)
            return previous + result
        }
    }
    
    func execute(input: Character) throws -> [Result] {
        partInput.append(input)
        let forwardResults = forwardWalker.walk(input: input)
        for forwardResult in forwardResults {
            if forwardResult.isRootOutput && forwardResult.output == nil {
                resetRules()
            }
            if let mapOutputs = forwardResult.output {
                if !forwardResult.isRootOutput {
                    rulesState = rulesState.parent
                }
                if let mapOutput = mapOutputs.first(where: { return rulesState[RuleInput(type: $0.type, key: $0.key)] != nil } ) {
                    rulesState = rulesState[RuleInput(type: mapOutput.type, key: mapOutput.key)]!
                    if let script = mapOutput.script {
                        partOutput.append(script)
                    }
                    if let ruleValue = rulesState.value {
                        return [Result(input: partInput, output: ruleValue.generate(intermediates: partOutput), isPreviousFinal: rulesState.parent.isRoot)]
                    }
                }
                else {
                    resetRules()
                    return try execute(inputs: forwardResult.inputs)
                }
            }
            return [Result(inoutput: forwardResult.inputs, isPreviousFinal: forwardResult.isRootOutput)]
        }
        return []
    }
}
