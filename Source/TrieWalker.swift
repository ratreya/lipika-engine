/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

class TrieWalker<Key: RangeReplaceableCollection, Value> where Key.Element: Hashable {
    
    typealias WalkerResult = (inputs: Key, output: Value?, isRootOutput: Bool)
    
    private let trie: Trie<Key, Value>
    private var currentNode: Trie<Key, Value>
    private var inputs: Key
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
            currentNode = next
            if let value = next.value {
                let result: WalkerResult = (inputs: inputs, output: value, isRootOutput: isFirstOutputSinceRoot)
                isFirstOutputSinceRoot = false
                lastOutputIndex = inputs.endIndex
                return [result]
            }
            return [(inputs: inputs, output: nil, isRootOutput: false)]
        }
        else {
            if lastOutputIndex > inputs.startIndex {
                let remainingInputs = inputsSinceOutput
                reset()
                return walk(inputs: remainingInputs)
            }
            else {
                let result: WalkerResult = (inputs: inputs, output: nil, isRootOutput: true)
                reset()
                return [result]
            }
        }
    }
}
