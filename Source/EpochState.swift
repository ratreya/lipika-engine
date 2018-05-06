/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2018 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

extension String {
    static func + (lhs: String, rhs: [UnicodeScalar]) -> String {
        var stringRHS = ""
        stringRHS.unicodeScalars.append(contentsOf: rhs)
        return lhs + stringRHS
    }
}

struct EpochEvent {
    private (set) var mappingEpoch: UInt
    private (set) var mappingResultType: WalkerResultType
    private (set) var mappingInput: [UnicodeScalar]
    private (set) var mappingOutput: MappingOutput?
    private (set) var ruleEpoch: UInt
    private (set) var ruleResultType: WalkerResultType?
    private (set) var ruleInput: [RuleInput]?
    private (set) var ruleOutput: RuleOutput?
    
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
    // Mapping Epoch -> Index of first event of that epoch
    private var mappingEpochIndex = [UInt: Int]()
    // Mapping Epoch -> Index of last `.mappedOutput` in that epoch
    private var mappedOutputIndex = [UInt: Int]()
    private var lastMappedOutputResult: Result? = nil
    private var lastMappedOutputIndex: Int? = nil
    
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
    
    private func addEvent(_ event: EpochEvent) {
        if event.mappingEpoch != events.last?.mappingEpoch ?? UInt.max {
            mappingEpochIndex[event.mappingEpoch] = events.endIndex
        }
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
        let trailingStart = events.reversed().index(where: { $0.ruleResultType != .mappedNoOutput || $0.mappingResultType != .mappedOutput }) ?? events.reversed().endIndex
        events[max(trailingStart!.base, lastMappedOutputIndex ?? 0)...].forEach() {
            result.inputs.append(contentsOf: $0.mappingInput)
            result.outputs.append($0.mappingOutput!.output!)
        }
        return result
    }
    
    func reset() {
        events.removeAll()
        mappingEpochIndex.removeAll()
        mappedOutputIndex.removeAll()
        lastMappedOutputResult = nil
        lastMappedOutputIndex = nil
    }
    
    func checkReset(_ mappingResult: MappingWalker.WalkerResult) -> Bool {
        // The fact that mapping epoch changed and the last output was `.mappedNoOutput` means that it should retroactively be treated as '.noMappedOutput'
        return events.last?.mappingResultType == .mappedNoOutput && (mappingResult.type == .noMappedOutput || mappingResult.epoch != lastMappingEpoch)
    }
    
    func checkStepBack(_ mappingResult: MappingWalker.WalkerResult) -> Bool {
        if mappingResult.type == .mappedOutput, let epochIndex = mappingEpochIndex[mappingResult.epoch] {
            let shouldStepBack = events[epochIndex...].contains(where: { $0.mappingResultType == .mappedOutput && $0.ruleResultType == .mappedOutput } )
            mappingEpochIndex.removeValue(forKey: mappingResult.epoch)
            mappedOutputIndex.removeValue(forKey: mappingResult.epoch)
            return shouldStepBack
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
                lastMappedOutputResult = Result(input: inputs, output: output, isPreviousFinal: lastRuleEpoch != event.ruleEpoch)
                lastMappedOutputIndex = events.endIndex
                results.append(lastMappedOutputResult!)
            case .mappedNoOutput:
                let result = ruleMappedNoOutputResult()
                lastMappedOutputResult = Result(input: result.inputs, output: result.outputs, isPreviousFinal: lastRuleEpoch != event.ruleEpoch)
                lastMappedOutputIndex = events.endIndex
                results.append(lastMappedOutputResult!)
            case .noMappedOutput:
                results.append(Result(inoutput: event.mappingInput, isPreviousFinal: true))
            }
        case .mappedNoOutput:
            results.append(Result(input: (lastMappedOutputResult?.input ?? "").unicodeScalars + event.mappingInput, output: (lastMappedOutputResult?.output ?? "") + event.mappingInput, isPreviousFinal: lastRuleEpoch != event.ruleEpoch))
        case .noMappedOutput:
            results.append(Result(inoutput: event.mappingInput, isPreviousFinal: lastMappingEpoch != event.mappingEpoch))
        }
        return results
    }
}
