/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

class TrieWalker<Key: RangeReplaceableCollection, Value> where Key.Element: Hashable {
    
    typealias WalkerOutput = (value: Value, isRootOutput: Bool)
    typealias WalkerResult = (inputs: Key, output: WalkerOutput?)
    
    private let trie: Trie<Key, Value>
    private var currentNode: Trie<Key, Value>
    private var inputs: Key
    private var output: WalkerOutput?
    private var lastOutputIndex: Key.Index
    private var isFirstOutputSinceRoot: Bool
    private var inputsSinceOutput: Key { return Key(inputs[lastOutputIndex...]) }

    init(trie: Trie<Key, Value>) {
        self.trie = trie
        currentNode = trie
        inputs = Key()
        lastOutputIndex = inputs.startIndex
        isFirstOutputSinceRoot = true
    }
    
    private func reset() {
        currentNode = trie
        inputs = Key()
        output = nil
        lastOutputIndex = inputs.startIndex
        isFirstOutputSinceRoot = true
    }
    
    func walk(inputs: Key) -> [WalkerResult] {
        return inputs.reduce([WalkerResult]()) { (previous, input) -> [WalkerResult] in
            return previous + walk(input: input)
        }
    }
    
    func walk(input: Key.Element) -> [WalkerResult] {
        inputs.append(input)
        if let next = currentNode[input] {
            if let value = next.value {
                output = (value, isFirstOutputSinceRoot)
                isFirstOutputSinceRoot = false
                lastOutputIndex = inputs.endIndex
            }
            currentNode = next
            return [(inputs: inputs, output: output)]
        }
        else {
            if lastOutputIndex > inputs.startIndex {
                let remainingInputs = inputsSinceOutput
                reset()
                return walk(inputs: remainingInputs)
            }
            else {
                let result: WalkerResult = (inputs: inputs, output: nil)
                reset()
                return [result]
            }
        }
    }
}
