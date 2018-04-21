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
    
    /**
     If this is true then even though `isPreviousFinal` is false, previous result must not be discarded; rather this result must be seen as an appendage to the previous unfinalized result.
     */
    private (set) var isAppendage = false
    
    init(input: [UnicodeScalar], output: String, isPreviousFinal: Bool, isAppendage: Bool = false) {
        self.input = ""
        self.input.unicodeScalars.append(contentsOf: input)
        self.output = output
        self.isPreviousFinal = isPreviousFinal
        self.isAppendage = isAppendage
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
    private var epochInput = [UnicodeScalar]()
    private var epochOuput = OrderedMap<String, [String]>()
    private var epochMappingResultTypes = [WalkerResultType]()
    private var lastEpochOutputKey: String? = nil
    private var lastMappingEpoch = UInt.max
    private var lastRuleEpoch = UInt.max

    init(rules: Rules) {
        mappingWalker = TrieWalker(trie: rules.mappingTrie)
        ruleWalker = TrieWalker(trie: rules.rulesTrie)
    }
    
    private func reset(exceptMapping: Bool) {
        epochInput.removeAll()
        epochOuput.removeAll()
        _ = ruleWalker.reset()
        if (!exceptMapping) { mappingWalker.reset() }
        lastEpochOutputKey = nil
        epochMappingResultTypes.removeAll()
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
    
    func execute(input: UnicodeScalar) -> [Result] {
        epochInput.append(input)
        var results =  [Result]()
        let mappingResults = mappingWalker.walk(input: input)
        for mappingResult in mappingResults {
            if lastMappingEpoch != mappingWalker.epoch, let lastMappingResultType = epochMappingResultTypes.last, lastMappingResultType == .mappedNoOutput {
                // The fact that mapping epoch changed and the last output was `.mappedNoOutput` means that it should retroactively be treated as '.noMappedOutput'
                reset(exceptMapping: true)
                epochInput.append(input)
            }
            switch mappingResult.type {
            case .mappedOutput:
                if lastMappingEpoch == mappingWalker.epoch, epochMappingResultTypes.contains(.mappedOutput) {
                    ruleWalker.stepBack()
                    if let lastEpocOutputKey = lastEpochOutputKey {
                        epochOuput[lastEpocOutputKey]!.removeLast()
                    }
                }
                if let mappingOutput = mappingResult.output!.first(where: { return ruleWalker.currentNode[$0.ruleInput] != nil } ) {
                    let ruleResults = ruleWalker.walk(input: mappingOutput.ruleInput)
                    for ruleResult in ruleResults {
                        // `.noMappedOutput` case cannot happen here and so it is safe to assume that there is always a non-nil keyElement
                        if ruleWalker.currentNode.keyElement!.key == nil {
                            epochOuput[mappingOutput.type, default: [String]()].append(mappingOutput.output!)
                            lastEpochOutputKey = mappingOutput.type
                        }
                        else {
                            lastEpochOutputKey = nil
                        }
                        switch ruleResult.type {
                        case .mappedOutput:
                            results.append(Result(input: epochInput, output: ruleResult.output!.generate(replacement: epochOuput), isPreviousFinal: lastRuleEpoch != ruleWalker.epoch))
                        case .mappedNoOutput:
                            results.append(Result(input: mappingResult.inputs, output: mappingOutput.output!, isPreviousFinal: lastRuleEpoch != ruleWalker.epoch, isAppendage: true))
                        case .noMappedOutput:
                            assertionFailure("RuleInput \(mappingOutput) had mapping but RuleWalker returned .noMappedOutput")
                        }
                    }
                }
                else {  // This is the real `.noMappedOutput` case
                    if mappingResult.inputs == epochInput {
                        reset()
                        results.append(Result(inoutput: mappingResult.inputs, isPreviousFinal: true))
                    }
                    else {
                        reset()
                        results.append(contentsOf: execute(inputs: mappingResult.inputs))
                    }
                }
                lastRuleEpoch = ruleWalker.epoch
            case .mappedNoOutput:
                results.append(Result(input: [input], output: String(input), isPreviousFinal: lastRuleEpoch != ruleWalker.epoch, isAppendage: true))
                lastRuleEpoch = ruleWalker.epoch
            case .noMappedOutput:
                reset()
                results.append(Result(inoutput: mappingResult.inputs, isPreviousFinal: lastMappingEpoch != mappingWalker.epoch))
                // Don't set `lastRuleEpoch` to current RuleEpoch because the next output will never replace this output (`isPreviousFinal` should always be `true`)
            }
            if lastMappingEpoch != mappingWalker.epoch {
                epochMappingResultTypes.removeAll()
            }
            epochMappingResultTypes.append(mappingResult.type)
            lastMappingEpoch = mappingWalker.epoch
        }
        return results
    }
}
