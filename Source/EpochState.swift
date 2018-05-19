/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2018 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

struct EpochEvent {
    let mappingEpoch: UInt
    let mappingResultType: WalkerResultType
    let mappingInput: [UnicodeScalar]
    let mappingOutput: MappingOutput?
    let ruleEpoch: UInt
    let ruleResultType: WalkerResultType?
    let ruleInput: [RuleInput]?
    let ruleOutput: RuleOutput?
    fileprivate (set) var result: Result?
    
    init(mappingResult: MappingWalker.WalkerResult, mappingOutput: MappingOutput, ruleResult: RuleWalker.WalkerResult) {
        mappingEpoch = mappingResult.epoch
        mappingResultType = mappingResult.type
        mappingInput = mappingResult.inputs
        self.mappingOutput = mappingOutput
        ruleEpoch = ruleResult.epoch
        ruleResultType = ruleResult.type
        ruleInput = ruleResult.inputs
        ruleOutput = ruleResult.output
    }
    
    init(mappingResult: MappingWalker.WalkerResult, ruleEpoch: UInt, ruleResultType: WalkerResultType? = nil) {
        mappingEpoch = mappingResult.epoch
        mappingResultType = mappingResult.type
        mappingInput = mappingResult.inputs
        mappingOutput = nil
        self.ruleEpoch = ruleEpoch
        self.ruleResultType = ruleResultType
        ruleInput = nil
        ruleOutput = nil
    }
}

class EpochState {
    private var events = [EpochEvent]()
    // Mapping Epoch -> Index of last `.mappedOutput` in that epoch
    private var mappedOutputIndex = [UInt: Int]()

    private var lastRuleEpoch: UInt { return events.last?.ruleEpoch ?? UInt.max }
    private var lastMappingEpoch: UInt { return events.last?.mappingEpoch ?? UInt.max }
    private var inputs: [UnicodeScalar] { return mappedOutputIndex.keys.sorted().reduce([], { $0 + events[mappedOutputIndex[$1]!].mappingInput } ) }
    private var replacements: OrderedMap<String, [String]> {
        var replacements = OrderedMap<String, [String]>()
        for key in mappedOutputIndex.keys.sorted() {
            let index = mappedOutputIndex[key]!
            if events[index].ruleInput!.last!.key == nil {
                replacements[events[index].mappingOutput!.type, default: [String]()].append(events[index].mappingOutput!.output!)
            }
        }
        return replacements
    }
    private var lastMappedOutputResult: Result? {
        if let lastOutputEpoch = mappedOutputIndex.keys.sorted(by: >).first(where: { events[mappedOutputIndex[$0]!].result != nil }) {
            return events[mappedOutputIndex[lastOutputEpoch]!].result
        }
        return nil
    }

    private func addEvent(_ event: EpochEvent) {
        if event.mappingResultType == .mappedOutput && event.ruleResultType != .noMappedOutput {
            mappedOutputIndex[event.mappingEpoch] = events.endIndex
        }
        events.append(event)
    }
    
    /// If there is no intermediate rule then we default to contatinating all remaining mapping outputs to the last mapped output result
    private func ruleMappedNoOutputResult() -> (inputs: [UnicodeScalar], outputs: String) {
        var result = (inputs: [UnicodeScalar](), outputs: "")
        if let lastMappedOutputResult = lastMappedOutputResult {
            result.inputs.append(contentsOf: lastMappedOutputResult.input.unicodeScalars)
            result.outputs.append(lastMappedOutputResult.output)
        }
        result.inputs.append(contentsOf: events.last!.mappingInput)
        result.outputs.append(events.last!.mappingOutput!.output!)
        return result
    }
    
    func reset() {
        events.removeAll()
        mappedOutputIndex.removeAll()
    }
    
    func checkReset(_ mappingResult: MappingWalker.WalkerResult) -> Bool {
        // The fact that mapping epoch changed and the last output was `.mappedNoOutput` means that it should retroactively be treated as '.noMappedOutput'
        return events.last?.mappingResultType == .mappedNoOutput && (mappingResult.type == .noMappedOutput || mappingResult.epoch != lastMappingEpoch)
    }
    
    func checkStepBack(_ mappingResult: MappingWalker.WalkerResult) -> Bool {
        if mappingResult.type != .noMappedOutput, mappedOutputIndex[mappingResult.epoch] != nil {
            mappedOutputIndex.removeValue(forKey: mappingResult.epoch)
            return true
        }
        return false
    }
    
    func handlePartialReplay(_ mappingResult: MappingWalker.WalkerResult) -> Result? {
        // If there were mappedNoOutputs appended to the last result which will be replayed now, retroactively remove them
        if events.last?.mappingResultType == .mappedNoOutput, var lastMappedOutputResult = lastMappedOutputResult {
            lastMappedOutputResult.isPreviousFinal = false
            return lastMappedOutputResult
        }
        return nil
    }
    
    func handle(event: EpochEvent) -> [Result] {
        var results = [Result]()
        if checkReset(MappingWalker.WalkerResult(inputs: event.mappingInput, output: nil, type: event.mappingResultType, epoch: event.mappingEpoch)) {
            // Replace the mappedOutput + mappedNoOuput with mappedOutput
            if var lastMappedOutputResult = lastMappedOutputResult {
                lastMappedOutputResult.isPreviousFinal = false
                results.append(lastMappedOutputResult)
            }
            // Make the mappedNoOuput, noMappedOutput
            results.append(Result(inoutput: events.last!.mappingInput, isPreviousFinal: lastMappedOutputResult != nil))
            reset()
        }
        let lastRuleEpoch = self.lastRuleEpoch
        let lastMappingEpoch = self.lastMappingEpoch
        addEvent(event)
        switch event.mappingResultType {
        case .mappedOutput:
            switch event.ruleResultType! {
            case .mappedOutput:
                let output = event.ruleOutput!.generate(replacement: replacements)
                events[events.endIndex - 1].result = Result(input: inputs, output: output, isPreviousFinal: lastRuleEpoch != event.ruleEpoch)
                results.append(events.last!.result!)
            case .mappedNoOutput:
                let result = ruleMappedNoOutputResult()
                events[events.endIndex - 1].result = Result(input: result.inputs, output: result.outputs, isPreviousFinal: lastRuleEpoch != event.ruleEpoch)
                results.append(events.last!.result!)
            case .noMappedOutput:
                results.append(Result(inoutput: event.mappingInput, isPreviousFinal: true))
            }
        case .mappedNoOutput:
            results.append(Result(input: (lastMappedOutputResult?.input ?? "") + event.mappingInput, output: (lastMappedOutputResult?.output ?? "") + event.mappingInput, isPreviousFinal: lastRuleEpoch != event.ruleEpoch))
        case .noMappedOutput:
            results.append(Result(inoutput: event.mappingInput, isPreviousFinal: lastMappingEpoch != event.mappingEpoch))
        }
        return results
    }
}
