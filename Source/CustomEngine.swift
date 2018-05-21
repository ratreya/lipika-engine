/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2018 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

class CustomEngine : EngineProtocol {
    private let trieWalker: TrieWalker<[UnicodeScalar], String>
    private var lastMappedOutput: Result?
    private var lastEpoch = UInt.max
    
    init(trie: Trie<[UnicodeScalar], String>) {
        trieWalker = TrieWalker(trie: trie)
    }
    
    func reset() {
        trieWalker.reset()
        lastMappedOutput = nil
        lastEpoch = UInt.max
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
        var results = [Result]()
        for mapOutput in trieWalker.walk(input: input) {
            let wasReset = lastEpoch != mapOutput.epoch
            if lastEpoch != UInt.max && wasReset {
                lastMappedOutput = nil
            }
            var result: Result
            switch mapOutput.type {
            case .mappedOutput:
                result = Result(input: mapOutput.inputs, output: mapOutput.output!, isPreviousFinal: wasReset)
                lastMappedOutput = result
            case .mappedNoOutput:
                if let lastMappedOutput = lastMappedOutput {
                    let remainingInputs = Array<UnicodeScalar>(mapOutput.inputs[lastMappedOutput.input.unicodeScalars.count...])
                    result = Result(input: mapOutput.inputs, output: lastMappedOutput.output + remainingInputs, isPreviousFinal: wasReset)
                }
                else {
                    result = Result(inoutput: mapOutput.inputs, isPreviousFinal: wasReset)
                }
            case .noMappedOutput:
                result = Result(inoutput: mapOutput.inputs, isPreviousFinal: wasReset)
            }
            results.append(result)
            lastEpoch = mapOutput.epoch
        }
        return results
    }
}
