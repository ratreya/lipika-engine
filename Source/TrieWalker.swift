/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

class TrieWalker<Key: RangeReplaceableCollection, Value: CustomStringConvertible> where Key.Element: Hashable, Key.Element: CustomStringConvertible {
    /**
     Tagged union of possible outcomes of a single TrieWalk.
     - Note:
     `IsRootOuput`: if the walk passed the root of the Trie since the last output
     - Important:
     Possible Combinations:
     * `(output: nil, isRootOutput: true)` or _NoMappedOutput_: there was no mapped output for the given _inputs_ in the Trie
     * `(output: non-nil)` or _MappedOutput_: found a mapped _output_ for the given _inputs_ in the Trie
     * `(output: nil, isRootOutput: false)` or _MappedNoOutput_: the given _inputs_ form a valid prefix but no output yet
     */
    typealias WalkerResult = (inputs: Key, output: Value?, isRootOutput: Bool)
    
    private var currentNode: Trie<Key, Value>
    private var inputs: Key
    private var lastOutputIndex: Key.Index
    private var inputsSinceOutput: Key { return Key(inputs[lastOutputIndex...]) }

    init(trie: Trie<Key, Value>) {
        currentNode = trie
        inputs = Key()
        lastOutputIndex = inputs.startIndex
    }
    
    func reset() {
        currentNode = currentNode.root
        inputs = Key()
        lastOutputIndex = inputs.startIndex
    }
    
    func walk(inputs: Key) -> [WalkerResult] {
        return inputs.reduce([WalkerResult]()) { (previous, input) -> [WalkerResult] in
            previous + walk(input: input)
        }
    }
    
    func walk(input: Key.Element) -> [WalkerResult] {
        inputs.append(input)
        if let next = currentNode[input] {
            currentNode = next
            if let value = next.value {
                let result: WalkerResult = (inputs: inputs, output: value, isRootOutput: currentNode.parent.isRoot)
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
