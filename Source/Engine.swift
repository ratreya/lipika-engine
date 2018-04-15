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

/*
 `Engine` is essentially a `TrieWalker` for the RulesTrie. It does a tandem walk first of the MappingTrie and then uses the output of the walk as input to walk the RulesTrie. The crux of the algorithm lies in stepping back and revising history. There are two situations where a step-back is needed: (a) when there is a new output in the same epoch of the MappingWalker, we need to step-back the RuleWalker and (b) if the last output in the previous Mapping Epoch was `.mappingNoOutput` then we need to revise history and treat it as `.noMappingOutput`. It is also important to try each of the possible MappingTrie outputs at the current node of the RulesTrie before deciding which path to walk. Essentially, we greedily walk forward where there is a path and when we hit a deadend, we retroactively step back and revise history.
 */
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
    
    private func reset(exceptMapping: Bool) {
        epocInput.removeAll()
        epocOuput.removeAll()
        _ = ruleWalker.reset()
        if (!exceptMapping) { mappingWalker.reset() }
        lastEpocOutputKey = nil
        lastMappingResultType = nil
        lastResult = nil
    }
    
    func reset() {
        reset(exceptMapping: false)
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
    
    private func mappedNoOutputResult(inputs: [UnicodeScalar], ruleEpoch: UInt) -> Result {
        var output = lastResult ?? ""
        output.unicodeScalars.append(contentsOf: inputs)
        return Result(input: epocInput, output: output, isPreviousFinal: lastRuleEpoch != ruleEpoch)
    }
    
    func execute(input: UnicodeScalar) -> [Result] {
        epocInput.append(input)
        var results =  [Result]()
        let mappingResults = mappingWalker.walk(input: input)
        for mappingResult in mappingResults {
            if lastMappingEpoch != mappingWalker.epoch, let lastMappingResultType = lastMappingResultType, lastMappingResultType == .mappedNoOutput {
                // The fact that mapping epoch changed and the last output was `.mappedNoOutput` means that it should retroactively be treated as '.noMappedOutput'
                reset(exceptMapping: true)
                epocInput.append(input)
            }
            switch mappingResult.type {
            case .mappedOutput:
                if lastMappingEpoch == mappingWalker.epoch, let lastMappingResultType = lastMappingResultType, lastMappingResultType == .mappedOutput {
                    ruleWalker.stepBack()
                    if let lastEpocOutputKey = lastEpocOutputKey {
                        epocOuput[lastEpocOutputKey]!.removeLast()
                    }
                }
                if let mappingOutput = mappingResult.output!.first(where: { return ruleWalker.currentNode[$0.ruleInput] != nil } ) {
                    let ruleResults = ruleWalker.walk(input: mappingOutput.ruleInput)
                    for ruleResult in ruleResults {
                        // `.noMappedOutput` case cannot happen here and so it is safe to assume that there is always a non-nil keyElement
                        if ruleWalker.currentNode.keyElement!.key == nil {
                            epocOuput[mappingOutput.type, default: [String]()].append(mappingOutput.output!)
                            lastEpocOutputKey = mappingOutput.type
                        }
                        else {
                            lastEpocOutputKey = nil
                        }
                        switch ruleResult.type {
                        case .mappedOutput:
                            lastResult = ruleResult.output!.generate(replacement: epocOuput)
                            results.append(Result(input: epocInput, output: lastResult!, isPreviousFinal: lastRuleEpoch != ruleWalker.epoch))
                        case .mappedNoOutput:
                            lastResult = (lastResult ?? "") + mappingOutput.output!
                            results.append(Result(input: epocInput, output: lastResult!, isPreviousFinal: lastRuleEpoch != ruleWalker.epoch))
                        case .noMappedOutput:
                            assertionFailure("RuleInput \(mappingOutput) had mapping but RuleWalker returned .noMappedOutput")
                        }
                    }
                }
                else {  // This is the real `.noMappedOutput` case
                    if ruleWalker.currentNode.isRoot {
                        reset()
                        results.append(Result(inoutput: mappingResult.inputs, isPreviousFinal: true))
                    }
                    else {
                        reset(exceptMapping: true)
                        results.append(contentsOf: execute(inputs: mappingResult.inputs))
                    }
                }
                lastRuleEpoch = ruleWalker.epoch
            case .mappedNoOutput:
                results.append(mappedNoOutputResult(inputs: mappingResult.inputs, ruleEpoch: ruleWalker.epoch))
                lastRuleEpoch = ruleWalker.epoch
            case .noMappedOutput:
                reset()
                results.append(Result(inoutput: mappingResult.inputs, isPreviousFinal: lastMappingEpoch != mappingWalker.epoch))
                // Don't set `lastRuleEpoch` to current RuleEpoch because the next output will never replace this output (`isPreviousFinal` should always be `true`)
            }
            lastMappingResultType = mappingResult.type
            lastMappingEpoch = mappingWalker.epoch
        }
        return results
    }
}
