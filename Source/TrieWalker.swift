/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

/**
 - `noMappedOutput`: there was no mapped output for the given _inputs_ in the Trie
 - `mappedOutput`: found a mapped _output_ for the given _inputs_ in the Trie
 - `mappedNoOutput`: the given _inputs_ form a valid prefix but no output yet
 */
enum WalkerResultType { case mappedOutput, mappedNoOutput, noMappedOutput }

class TrieWalker<Key: RangeReplaceableCollection, Value: CustomStringConvertible> where Key: BidirectionalCollection, Key.Element: Hashable, Key.Element: CustomStringConvertible {
    /**
     Tagged union of possible outcomes of a single TrieWalk.
     */
    typealias WalkerResult = (inputs: Key, output: Value?, type: WalkerResultType, epoch: UInt)

    private var outputIndics = [Key.Index]()
    private var inputsSinceOutput: Key { return Key(inputs[(outputIndics.last ?? inputs.startIndex)...]) }
    // This is the strong reference to the root and currentNode is a weak pointer
    private let trie: Trie<Key, Value>
    private (set) var inputs: Key
    private (set) var epoch: UInt = 0
    private (set) unowned var currentNode: Trie<Key, Value>

    init(trie: Trie<Key, Value>) {
        self.trie = trie
        currentNode = trie
        inputs = Key()
    }
    
    func reset() {
        currentNode = currentNode.root
        inputs.removeAll()
        outputIndics.removeAll()
        epoch = epoch + 1
    }
    
    func stepBack() {
        guard !currentNode.isRoot else { return }
        inputs.removeLast()
        if currentNode.value != nil {
            outputIndics.removeLast()
        }
        currentNode = currentNode.parent
    }
    
    func walk(inputs: Key) -> [WalkerResult] {
        return inputs.reduce([WalkerResult]()) { (previous, input) -> [WalkerResult] in
            previous + walk(input: input)
        }
    }
    
    func walk(input: Key.Element) -> [WalkerResult] {
        if let next = currentNode[input] {
            // Doing this rather than always appending `input` because these two object are equal but not necessarily the same
            inputs.append(next.keyElement!)
            currentNode = next
            outputIndics.append(inputs.endIndex)
            if let value = next.value {
                let result: WalkerResult = (inputs: inputs, output: value, type: .mappedOutput, epoch: epoch)
                return [result]
            }
            return [(inputs: inputs, output: nil, type: .mappedNoOutput, epoch: epoch)]
        }
        else {
            inputs.append(input)
            if let lastOutputIndex = outputIndics.last, lastOutputIndex > inputs.startIndex {
                let remainingInputs = inputsSinceOutput
                reset()
                return walk(inputs: remainingInputs)
            }
            else {
                let result: WalkerResult = (inputs: inputs, output: nil, type: .noMappedOutput, epoch: epoch)
                reset()
                return [result]
            }
        }
    }
}
