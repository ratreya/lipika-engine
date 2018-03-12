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
     _noMappedOutput_: there was no mapped output for the given _inputs_ in the Trie
     _mappedOutput_: found a mapped _output_ for the given _inputs_ in the Trie
     _mappedNoOutput_: the given _inputs_ form a valid prefix but no output yet
     */
    enum WalkerResultType { case mappedOutput, mappedNoOutput, noMappedOutput }
    /**
     Tagged union of possible outcomes of a single TrieWalk.
     - Note:
     `IsRootOuput`: if the walk passed the root of the Trie since the last output
     */
    typealias WalkerResult = (inputs: Key, output: Value?, isRootOutput: Bool, type: WalkerResultType)
    
    private var inputs: Key
    private var lastOutputIndex: Key.Index
    private var inputsSinceOutput: Key { return Key(inputs[lastOutputIndex...]) }
    var currentNode: Trie<Key, Value>
    var walkEpoch: UInt = 0

    init(trie: Trie<Key, Value>) {
        currentNode = trie
        inputs = Key()
        lastOutputIndex = inputs.startIndex
    }
    
    func reset() {
        currentNode = currentNode.root
        inputs = Key()
        lastOutputIndex = inputs.startIndex
        walkEpoch = walkEpoch &+ 1
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
                let result: WalkerResult = (inputs: inputs, output: value, isRootOutput: currentNode.parent.isRoot, type: .mappedOutput)
                lastOutputIndex = inputs.endIndex
                return [result]
            }
            return [(inputs: inputs, output: nil, isRootOutput: currentNode.parent.isRoot, type: .mappedNoOutput)]
        }
        else {
            if lastOutputIndex > inputs.startIndex {
                let remainingInputs = inputsSinceOutput
                reset()
                return walk(inputs: remainingInputs)
            }
            else {
                let result: WalkerResult = (inputs: inputs, output: nil, isRootOutput: true, type: .noMappedOutput)
                reset()
                return [result]
            }
        }
    }
}
