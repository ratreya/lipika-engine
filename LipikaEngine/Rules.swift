/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import Foundation

class Output {
    private var ouputRule: String
    private let kOutputPattern: RegEx
    
    init(rule: String) throws {
        self.ouputRule = rule
        self.kOutputPattern = try RegEx(pattern: "[\\$([0-9]+)]")
    }
    
    func generate(intermediates: [String]) -> String {
        // Copy the rule which will be modidfied to the produce the output
        if kOutputPattern =~ ouputRule {
            let matches = kOutputPattern.matching()!
            for (index, match) in matches.enumerated() {
                let index = Int(kOutputPattern.captured(match: index, at: 0)!)!
                if !kOutputPattern.replace(match: index, with: intermediates[index]) {
                    assert(false, "Unable to replace mapping reference: \(match) with replacement: \(intermediates[index])")
                }
            }
            return kOutputPattern.input!
        }
        return ouputRule
    }
}

class State {
    var output: Output?
    var next = [String: State]()
    
    init() {}
}

class Rules {
    private let kSpecificValuePattern: RegEx
    private let kMapStringSubPattern: RegEx

    private let scheme: Scheme
    private (set) var state = State()
    
    init(imeRules: [String], scheme: Scheme) throws {
        self.scheme = scheme
        kSpecificValuePattern = try RegEx(pattern: "^[\\{\\[](.+)/(.+)$[\\}\\]]")
        kMapStringSubPattern = try RegEx(pattern: "(\\[[^\\]]+?\\]|\\{[^\\}]+?\\})")
        
        for imeRule in imeRules {
            if imeRule.isEmpty { continue }
            let components = imeRule.components(separatedBy: "\t")
            if components.count != 2 {
                throw EngineError.parseError("IME Rule not two column TSV: \(imeRule)")
            }
            let inputRule = components[0]
            let outputRule = components[1]
            if kMapStringSubPattern =~ inputRule {
                var inputs = kMapStringSubPattern.matching()!
                let output = try expandMappingRefs(outputRule)
                addRule(inputs: &inputs, output: try Output(rule: output), state: &state)
             }
        }
    }
    
    private func expandMappingRefs(_ input: String) throws -> String {
        if kSpecificValuePattern =~ input {
            for (index, match) in kSpecificValuePattern.matching()!.enumerated() {
                let components = match.components(separatedBy: "/")
                if let map = scheme.mappings[components[0]]?[components[1]] {
                    let replacement = match.hasPrefix("{") ? map.0 : map.1
                    if !kSpecificValuePattern.replace(match: index, with: replacement) {
                        assert(false, "Unable to replace mapping reference: \(match) with replacement: \(replacement)")
                    }
                }
                else {
                    throw EngineError.parseError("Cannot find mapping for \(match)")
                }
            }
            return kSpecificValuePattern.input!
        }
        return input
    }
    
    private func addRule(inputs: inout [String], output: Output, state: inout State) {
        var nextState = state.next[inputs[0]]
        if nextState == nil {
            nextState = State()
            state.next.updateValue(nextState!, forKey: inputs[0])
        }
        if inputs.count == 1 {
            nextState!.output = output
        }
        if inputs.count > 1 {
            inputs.remove(at: 0)
            addRule(inputs: &inputs, output: output, state: &nextState!)
        }
    }
}
