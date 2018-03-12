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

    private var ruleState: RulesTrie
    private var partInput = [UnicodeScalar]()
    private var partOutput = [String: [String]]()
    private var currentRuleEpoch: UInt = 0
    private var previousRuleEpoch: UInt = UInt.max
    private var previousOutputMappingEpoch: UInt = UInt.max
    private var previousOutputType: String?
    var isReset: Bool { return ruleState.isRoot && forwardWalker.currentNode.isRoot }

    init(rules: Rules) {
        ruleState = rules.rulesTrie
        forwardWalker = TrieWalker(trie: rules.mappingTrie)
    }
    
    func reset() {
        partInput.removeAll()
        partOutput.removeAll()
        ruleState = ruleState.root
        forwardWalker.reset()
        currentRuleEpoch = currentRuleEpoch &+ 1
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
        let currentMappingEpoch = forwardWalker.walkEpoch
        var results =  [Result]()
        for forwardResult in forwardResults {
            switch forwardResult.type {
            case .mappedOutput:
                if previousOutputMappingEpoch == currentMappingEpoch {
                    ruleState = ruleState.parent
                    if let lastOutputType = previousOutputType {
                        partOutput[lastOutputType]!.removeLast()
                    }
                }
                if let mapOutput = forwardResult.output!.first(where: { return ruleState[RuleInput(type: $0.type, key: $0.key)] != nil } ) {
                    ruleState = ruleState[RuleInput(type: mapOutput.type, key: mapOutput.key)]!
                    previousOutputMappingEpoch = currentMappingEpoch
                    if let script = mapOutput.output {
                        partOutput[mapOutput.type, default: [String]()].append(script)
                        previousOutputType = mapOutput.type
                    }
                    else {
                        previousOutputType = nil
                    }
                    if let ruleValue = ruleState.value {
                        results.append(Result(input: partInput, output: ruleValue.generate(replacement: partOutput), isPreviousFinal: currentRuleEpoch != previousRuleEpoch))
                    }
                    else {
                        results.append(Result(inoutput: partInput, isPreviousFinal: currentRuleEpoch != previousRuleEpoch))
                    }
                }
                else {
                    reset()
                    results.append(contentsOf: execute(inputs: forwardResult.inputs))
                }
            case .noMappedOutput:
                    reset()
                    results.append(Result(inoutput: forwardResult.inputs, isPreviousFinal: forwardResult.isRootOutput))
            case .mappedNoOutput:
                var output = ruleState.value?.generate(replacement: partOutput) ?? ""
                output.unicodeScalars.append(contentsOf: forwardResult.inputs)
                // TODO: rethink isPreviousFinal logic - can it be based on epochs?
                results.append(Result(input: partInput, output: output, isPreviousFinal: ruleState.isRoot && forwardWalker.currentNode.parent.isRoot))
            }
            previousRuleEpoch = currentRuleEpoch
        }
        return results
    }
}
