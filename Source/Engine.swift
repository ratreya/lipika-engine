/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2019 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

typealias MappingWalker = TrieWalker<[UnicodeScalar], [MappingOutput]>
typealias RuleWalker = TrieWalker<[RuleInput], RuleOutput>

private class InternalResult: Result {
    // The last event that went into producing this resule
    var eventEpoch: UInt
    // Usually newer Results of the same Rules Epoch replace older Results except when this is true
    // Instead of replaceing, this result is expected to be appended to the old Result
    var shouldAppend = false
    
    init(input: String, output: String, eventEpoch: UInt, isPreviousFinal: Bool = false, shouldAppend: Bool = false) {
        self.shouldAppend = shouldAppend
        self.eventEpoch = eventEpoch
        super.init(input: input, output: output, isPreviousFinal: isPreviousFinal)
    }
    
    convenience init(input: [UnicodeScalar], output: String, eventEpoch: UInt, isPreviousFinal: Bool = false, shouldAppend: Bool = false) {
        self.init(input: "" + input, output: output, eventEpoch: eventEpoch, isPreviousFinal: isPreviousFinal, shouldAppend: shouldAppend)
    }
    
    convenience init(inoutput: [UnicodeScalar], eventEpoch: UInt, isPreviousFinal: Bool = false) {
        self.init(input: inoutput, output: "" + inoutput, eventEpoch: eventEpoch, isPreviousFinal: isPreviousFinal)
    }
    
    func appending(another: InternalResult) -> InternalResult {
        return InternalResult(input: input + another.input, output: output + another.output, eventEpoch: another.eventEpoch)
    }
}

extension Array where Element: Result {
    static func += (lhs: inout [Element], rhs: [Element]) {
        lhs.removeSubrange((lhs.lastIndex(where: { $0.isPreviousFinal }) ?? 0)..<lhs.count)
        rhs.first?.isPreviousFinal = true
        lhs.append(contentsOf: rhs)
    }
    
    static func + (lhs: [Result], rhs: [Result]) -> [Result] {
        var result = Array<Result>(lhs)
        result += rhs
        return result
    }
}

private class RuleRunner {
    private let ruleWalker: RuleWalker
    private var lastRuleEpoch: UInt
    private var inputs = [UnicodeScalar]()
    private var results =  [UInt: Result]()
    private var replacements = [String: [String]]()
    var epoch: UInt { return ruleWalker.epoch }
    
    init(rules: Rules) {
        ruleWalker = TrieWalker(trie: rules.rulesTrie)
        lastRuleEpoch = ruleWalker.epoch
    }
    
    func reset() {
        ruleWalker.reset()
        inputs.removeAll()
        results.removeAll()
        replacements.removeAll()
    }
    
    // The expectation is that peek is always called before execute
    func peek(_ event: MappingWalker.WalkerResult) -> MappingOutput? {
        if let eventOutput = event.output!.first(where: { return ruleWalker.currentNode[$0.ruleInput] != nil } ) {
            return eventOutput
        }
        reset()
        return event.output!.first(where: { return ruleWalker.currentNode[$0.ruleInput] != nil } )
    }

    func execute(event: MappingWalker.WalkerResult, output: MappingOutput) -> [UInt: InternalResult] {
        inputs.append(contentsOf: event.inputs)
        let ruleResults = ruleWalker.walk(input: output.ruleInput)
        var results = [UInt: InternalResult]()
        for ruleResult in ruleResults {
            // Only store replacements if the rule segment is not fully resolved to a key
            if ruleResult.inputs.last!.key == nil {
                replacements[output.type, default: [String]()].append(output.output!)
            }
            switch ruleResult.type {
            case .mappedOutput:
                let ruleOutput = ruleResult.output!.generate(replacement: replacements)
                results[ruleResult.epoch] = InternalResult(input: inputs, output: ruleOutput, eventEpoch: event.epoch)
            case .mappedNoOutput:
                results[ruleResult.epoch] = InternalResult(input: inputs, output: output.output!, eventEpoch: event.epoch, shouldAppend: true)
            case .noMappedOutput:
                assertionFailure("RuleRunner.execute called for: \(output.ruleInput) before calling peek thus causing noMappedOutput")
            }
        }
        return results
    }
}

/**
 `Engine` is essentially a `TrieWalker` for the RulesTrie. It does a tandem walk first of the MappingTrie and then uses the output of the walk as input to walk the RulesTrie. The crux of the algorithm lies in figuring out at what point the output of the Engine can be finalized - meaning that it won't change any further. Essentially, *all output up to but excluding the last finalized mapping output that also finalized the rules trie can be finalized*. Please [see the complete design document](https://github.com/ratreya/lipika-engine/wiki) for further details.
 */
class Engine : EngineProtocol {
    private let mappingWalker: MappingWalker
    private let ruleRunner: RuleRunner
    private var unfinalizedEvents = [UInt: MappingWalker.WalkerResult]()
    private var lastMappingEpoch: UInt
    
    init(rules: Rules) {
        mappingWalker = TrieWalker(trie: rules.mappingTrie)
        ruleRunner = RuleRunner(rules: rules)
        lastMappingEpoch = mappingWalker.epoch
    }

    func reset() {
        unfinalizedEvents.removeAll()
        mappingWalker.reset()
    }
    
    func execute(inputs: String) -> [Result] {
        return execute(inputs: inputs.unicodeScalars())
    }
    
    func execute(inputs: [UnicodeScalar]) -> [Result] {
        return inputs.reduce([Result]()) { (previous, input) -> [Result] in
            let result = execute(input: input)
            return previous + result
        }
    }
    
    func execute(input: UnicodeScalar) -> [Result] {
        let mappingResults = mappingWalker.walk(input: input)
        // Merge the latest mapping results into unfinalized events
        let resultsDict = mappingResults.reduce(into: [UInt: MappingWalker.WalkerResult]()) { $0[$1.epoch] = $1 }
        unfinalizedEvents.merge(resultsDict) { (_, new) in new }
        // Run the RulesTrie on all unfinalized events
        ruleRunner.reset()
        var results = [UInt: InternalResult]()
        for mappingEpoch in unfinalizedEvents.keys.sorted() {
            let event = unfinalizedEvents[mappingEpoch]!
            if event.type == .mappedOutput, let eventOutput = ruleRunner.peek(event) {
                results.merge(ruleRunner.execute(event: event, output: eventOutput)) { (old, new) in
                    new.shouldAppend ? old.appending(another: new) : new
                }
            }
            else {
                // Bump the epoch
                ruleRunner.reset()
                // Consume the new epoch
                if event.type == .mappedOutput, let output = event.output!.count == 1 ? event.output!.first : event.output!.first(where: { $0.type != "DEPENDENT" }) {
                    // This means that the Rules Trie did not have mapping - just output the first non-dependent type as-is
                    results[ruleRunner.epoch] = InternalResult(input: event.inputs, output: output.output!, eventEpoch: event.epoch)
                }
                else {
                    results[ruleRunner.epoch] = InternalResult(inoutput: event.inputs, eventEpoch: event.epoch)
                }
                // Bump the epoch again
                ruleRunner.reset()
            }
        }
        // Mark the finalization point if it exists
        var epochs = results.keys.sorted()
        if epochs.count > 2 {
            results[epochs[epochs.count-2]]!.isPreviousFinal = true
            // Remove all finalized events
            for mappingEpoch in unfinalizedEvents.keys.min()!...results[epochs[epochs.count-3]]!.eventEpoch {
                unfinalizedEvents.removeValue(forKey: mappingEpoch)
            }
        }
        return epochs.map() { results[$0]! }
    }
}
