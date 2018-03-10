/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2018 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

struct Result {
    var input: String
    var output: String

    /// If this is true then all outputs before this is final and will not be changed anymore.
    var isPreviousFinal = false
    
    init(input: [UnicodeScalar], output: String, isPreviousFinal: Bool) {
        self.input = ""
        self.input.unicodeScalars.append(contentsOf: input)
        self.output = output
        self.isPreviousFinal = isPreviousFinal
    }

    init(inoutput: [UnicodeScalar], isPreviousFinal: Bool) {
        self.input = ""
        self.input.unicodeScalars.append(contentsOf: inoutput)
        self.output = input
        self.isPreviousFinal = isPreviousFinal
    }
}

class Engine {
    private let forwardWalker: TrieWalker<[UnicodeScalar], [TrieValue]>

    private var rulesState: RulesTrie
    private var partInput = [UnicodeScalar]()
    private var partOutput = [String: [String]]()
    internal var isReset: Bool { return rulesState.isRoot && forwardWalker.isAtRoot }

    init(rules: Rules) {
        rulesState = rules.rulesTrie
        forwardWalker = TrieWalker(trie: rules.mappingTrie)
    }
    
    private func resetRules() {
        partInput = [UnicodeScalar]()
        partOutput = [String: [String]]()
        rulesState = rulesState.root
    }
    
    func reset() {
        resetRules()
        forwardWalker.reset()
    }
    
    func execute(inputs: String) -> [Result] {
        return execute(inputs: Array(inputs.unicodeScalars))
    }
    
    func execute(inputs: [UnicodeScalar]) -> [Result] {
        return inputs.reduce([Result]()) { (previous, input) -> [Result] in
            let result = execute(input: input)
            return previous + result
        }
    }
    
    func execute(input: UnicodeScalar) -> [Result] {
        partInput.append(input)
        let forwardResults = forwardWalker.walk(input: input)
        for forwardResult in forwardResults {
            if let mapOutputs = forwardResult.output {  // Case of MappedOutput
                if !forwardResult.isRootOutput {
                    rulesState = rulesState.parent
                }
                if let mapOutput = mapOutputs.first(where: { return rulesState[RuleInput(type: $0.type, key: $0.key)] != nil } ) {
                    rulesState = rulesState[RuleInput(type: mapOutput.type, key: mapOutput.key)]!
                    if let script = mapOutput.output {
                        partOutput[mapOutput.type, default: [String]()].append(script)
                    }
                    if let ruleValue = rulesState.value {
                        return [Result(input: partInput, output: ruleValue.generate(replacement: partOutput), isPreviousFinal: rulesState.parent.isRoot)]
                    }
                }
                else {
                    reset()
                    return execute(inputs: forwardResult.inputs)
                }
            }
            else if forwardResult.isRootOutput {    // Case of NoMappedOutput
                resetRules()
                return [Result(inoutput: forwardResult.inputs, isPreviousFinal: forwardResult.isRootOutput)]
            }
            // Case of MappedNoOutput
            return [Result(inoutput: forwardResult.inputs, isPreviousFinal: rulesState.parent.isRoot)]
        }
        assertionFailure("Trie walk produced an empty array for input: \(input)")
        return []
    }
}
