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
    private var lastEpoch = UInt.max
    private var lastOutput: Result?
    
    init(trie: Trie<[UnicodeScalar], String>) {
        trieWalker = TrieWalker(trie: trie)
    }
    
    func reset() {
        trieWalker.reset()
        lastEpoch = UInt.max
        lastOutput = nil
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
            switch mapOutput.type {
            case .mappedOutput:
                lastOutput = Result(input: mapOutput.inputs, output: mapOutput.output!, isPreviousFinal: wasReset)
                results.append(lastOutput!)
            case .mappedNoOutput:
                let result = Result(input: (lastOutput?.input ?? "") + mapOutput.inputs, output: (lastOutput?.output ?? "") + mapOutput.inputs, isPreviousFinal: wasReset)
                results.append(result)
            case .noMappedOutput:
                let result = Result(inoutput: mapOutput.inputs, isPreviousFinal: wasReset)
                results.append(result)
            }
            if wasReset { lastOutput = nil }
            lastEpoch = mapOutput.epoch
        }
        return results
    }
}
