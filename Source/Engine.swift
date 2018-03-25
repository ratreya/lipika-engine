/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2018 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

struct Result {
    private (set) var input: String
    private (set) var output: String

    /// If this is true then all outputs before this is final and will not be changed anymore.
    private (set) var isPreviousFinal = false
    
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
    private let mappingWalker: TrieWalker<[UnicodeScalar], [MappingOutput]>
    private let ruleWalker: TrieWalker<[RuleInput], RuleOutput>
    private var epocInput = [UnicodeScalar]()
    private var epocOuput = OrderedMap<String, [String]>()
    private var lastEpocOutputKey: String? = nil
    private var lastMappingResultType: WalkerResultType? = nil
    private var lastResult: String? = nil
    private var lastMappingEpoch = UInt.max
    private var lastRuleEpoch = UInt.max

    var isReset: Bool { return ruleWalker.currentNode.isRoot && mappingWalker.currentNode.isRoot }

    init(rules: Rules) {
        mappingWalker = TrieWalker(trie: rules.mappingTrie)
        ruleWalker = TrieWalker(trie: rules.rulesTrie)
    }
    
    func reset() {
        epocInput.removeAll()
        epocOuput.removeAll()
        ruleWalker.reset()
        mappingWalker.reset()
        lastEpocOutputKey = nil
        lastMappingResultType = nil
        lastResult = nil
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
    
    private func doMappedNoOutput(inputs: [UnicodeScalar], ruleEpoch: UInt) -> Result {
        lastEpocOutputKey = nil
        var output = lastResult ?? ""
        output.unicodeScalars.append(contentsOf: inputs)
        return Result(input: epocInput, output: output, isPreviousFinal: lastRuleEpoch != ruleEpoch)
    }
    
    func execute(input: UnicodeScalar) -> [Result] {
        epocInput.append(input)
        var results =  [Result]()
        let mappingResults = mappingWalker.walk(input: input)
        for mappingResult in mappingResults {
            switch mappingResult.type {
            case .mappedOutput:
                if lastMappingEpoch == mappingWalker.epoch {
                    if let lastMappingResultType = lastMappingResultType, lastMappingResultType == .mappedOutput {
                        ruleWalker.stepBack()
                    }
                    if let lastEpocOutputKey = lastEpocOutputKey {
                        epocOuput[lastEpocOutputKey]!.removeLast()
                    }
                }
                if let mapOutput = mappingResult.output!.first(where: { return ruleWalker.currentNode[$0.ruleInput] != nil } ) {
                    let ruleResults = ruleWalker.walk(input: mapOutput.ruleInput)
                    for ruleResult in ruleResults {
                        // `.noMappedOutput` case cannot happen here and so it is safe to assume that there is always a non-nil keyElement
                        if ruleWalker.currentNode.keyElement!.key == nil {
                            epocOuput[mapOutput.type, default: [String]()].append(mapOutput.output!)
                            lastEpocOutputKey = mapOutput.type
                        }
                        else {
                            lastEpocOutputKey = nil
                        }
                        switch ruleResult.type {
                        case .mappedOutput:
                            lastResult = ruleResult.output!.generate(replacement: epocOuput)
                            results.append(Result(input: epocInput, output: lastResult!, isPreviousFinal: lastRuleEpoch != ruleWalker.epoch))
                        case .mappedNoOutput:
                            results.append(doMappedNoOutput(inputs: mappingResult.inputs, ruleEpoch: ruleWalker.epoch))
                        case .noMappedOutput:
                            assertionFailure("RuleInput \(mapOutput) had mapping but RuleWalker returned .noMappedOutput")
                        }
                    }
                    lastRuleEpoch = ruleWalker.epoch
                }
                else {  // This is the real `.noMappedOutput` case
                    reset()
                    results.append(contentsOf: execute(inputs: mappingResult.inputs))
                }
            case .mappedNoOutput:
                results.append(doMappedNoOutput(inputs: mappingResult.inputs, ruleEpoch: ruleWalker.epoch))
            case .noMappedOutput:
                reset()
                results.append(Result(inoutput: mappingResult.inputs, isPreviousFinal: lastMappingEpoch != mappingWalker.epoch))
            }
            lastMappingResultType = mappingResult.type
        }
        lastMappingEpoch = mappingWalker.epoch
        return results
    }
}
