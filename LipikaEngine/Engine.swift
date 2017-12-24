/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

struct Result {
    var input: String
    var output: String
    /*
     * If this is true then the output is final and will not be changed anymore.
     * Else the above output should be replaced by subsequent outputs until a final output is encountered.
     */
    var isFinal: Bool?
    /*
     * If this is true then all outputs before this is final and will not be changed anymore.
     */
    var isPreviousFinal: Bool?
    
    init(input: String, output: String) {
        self.input = input
        self.output = output
    }

    init(inoutput: String) {
        self.input = inoutput
        self.output = inoutput
    }
}

class Engine {
    internal let rules: Rules
    
    private let forwardWalker: TrieWalker<String, ForwardTrieValue>
    private let ruleWalker: TrieWalker<[RuleInput], RuleOutput>
    
    private var partOutput = [String]()

    init(rules: Rules) {
        self.rules = rules
        forwardWalker = TrieWalker(trie: rules.scheme.forwardTrie)
        ruleWalker = TrieWalker(trie: rules.rulesTrie)
    }
    
    func execute(input: Character) throws -> Result? {
        let forwardResults = forwardWalker.walk(input: input)
        for forwardResult in forwardResults {
            if forwardResult.isRootOutput {
                // TODO
            }
            if let mapOutputs = forwardResult.output {
                if let mapOutput = mapOutputs.first(where: { return rules.rulesTrie[RuleInput(type: $0.type, key: $0.key)] != nil } ) {
                    let ruleOutput = rules.rulesTrie[RuleInput(type: mapOutput.type, key: mapOutput.key)]
                }
                else {
                    // TODO
                }
            }
        }
        return nil
    }
}
