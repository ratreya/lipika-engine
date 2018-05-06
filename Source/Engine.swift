/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2018 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

typealias MappingWalker = TrieWalker<[UnicodeScalar], [MappingOutput]>
typealias RuleWalker = TrieWalker<[RuleInput], RuleOutput>

struct Result {
    private (set) var input: String
    private (set) var output: String
    
    /// If this is true then all outputs before this is final and will not be changed anymore.
    var isPreviousFinal = false
    
    init(input: [UnicodeScalar], output: String, isPreviousFinal: Bool) {
        self.input = "" + input
        self.output = output
        self.isPreviousFinal = isPreviousFinal
    }

    init(inoutput: [UnicodeScalar], isPreviousFinal: Bool) {
        input = "" + inoutput
        output = input
        self.isPreviousFinal = isPreviousFinal
    }
}

/*
 `Engine` is essentially a `TrieWalker` for the RulesTrie. It does a tandem walk first of the MappingTrie and then uses the output of the walk as input to walk the RulesTrie. The crux of the algorithm lies in stepping back and revising history. There are two situations where a step-back is needed: (a) when there is a new output in the same epoch of the MappingWalker, we need to step-back the RuleWalker and (b) if the last output in the previous Mapping Epoch was `.mappingNoOutput` then we need to revise history and treat it as `.noMappingOutput`. It is also important to try each of the possible MappingTrie outputs at the current node of the RulesTrie before deciding which path to walk. Essentially, we greedily walk forward where there is a path and when we hit a deadend, we retroactively step back and revise history.
 */
class Engine {
    private let mappingWalker: MappingWalker
    private let ruleWalker: RuleWalker
    private var epochState = EpochState()
    private var epochInputs = [UnicodeScalar]()

    init(rules: Rules) {
        mappingWalker = TrieWalker(trie: rules.mappingTrie)
        ruleWalker = TrieWalker(trie: rules.rulesTrie)
    }
    
    func reset() {
        epochState.reset()
        epochInputs.removeAll()
        ruleWalker.reset()
        mappingWalker.reset()
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
        epochInputs.append(input)
        var results =  [Result]()
        let mappingResults = mappingWalker.walk(input: input)
        for mappingResult in mappingResults {
            if epochState.checkReset(mappingResult) {
                ruleWalker.reset()
            }
            if mappingResult.type == .mappedOutput {
                if epochState.checkStepBack(mappingResult) {
                    ruleWalker.stepBack()
                }
                if let mappingOutput = mappingResult.output!.first(where: { return ruleWalker.currentNode[$0.ruleInput] != nil } ) {
                    let ruleResults = ruleWalker.walk(input: mappingOutput.ruleInput)
                    for ruleResult in ruleResults {
                        // `.noMappedOutput` case cannot happen here and so it is safe to assume that there is always a non-nil keyElement
                        assert(ruleResult.type != .noMappedOutput, "RuleInput \(mappingOutput) had mapping but RuleWalker returned .noMappedOutput")
                        let event = EpochEvent(mappingResult: mappingResult, mappingOutput: mappingOutput, ruleResult: ruleResult)
                        results.append(contentsOf: epochState.handle(event: event))
                    }
                }
                else {  // This is the real `.noMappedOutput` case
                    if mappingResult.inputs == epochInputs {
                        reset()
                        let event = EpochEvent(mappingResult: mappingResult, ruleEpoch: ruleWalker.epoch, ruleResultType: .noMappedOutput)
                        results.append(contentsOf: epochState.handle(event: event))
                    }
                    else {
                        if let reversal = epochState.handlePartialReplay(mappingResult) {
                            results.append(reversal)
                        }
                        reset()
                        results.append(contentsOf: execute(inputs: mappingResult.inputs))
                    }
                }
            }
            else {
                let event = EpochEvent(mappingResult: mappingResult, ruleEpoch: ruleWalker.epoch)
                results.append(contentsOf: epochState.handle(event: event))
                if mappingResult.type == .noMappedOutput {
                    reset()
                }
            }
        }
        return results
    }
}
