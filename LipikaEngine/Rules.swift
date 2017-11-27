/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import Foundation

struct Output {
    private var ouputRule: String
    private let kOutputPattern: RegEx
    
    init(rule: String) throws {
        self.ouputRule = rule
        self.kOutputPattern = try RegEx(pattern: "\\[\\$([0-9]+)\\]")
    }
    
    func generate(intermediates: [String]) -> String {
        var result = ouputRule
        while (kOutputPattern =~ result) {
            let index = Int(kOutputPattern.captured()!)! - 1
            result = kOutputPattern.replacing(with: intermediates[index])!
        }
        return result
    }
}

// This needs to be a class because we recursively pass around its reference
class State {
    var output: Output?
    var next = [String: State]()
}

class Rules {
    private let kSpecificValuePattern: RegEx
    private let kMapStringSubPattern: RegEx

    let scheme: Scheme
    private (set) var state = State()
    
    init(imeRules: [String], scheme: Scheme) throws {
        self.scheme = scheme
        kSpecificValuePattern = try RegEx(pattern: "[\\{\\[]([^\\{\\[]+/[^\\{\\[]+)[\\}\\]]")
        kMapStringSubPattern = try RegEx(pattern: "(\\[[^\\]]+?\\]|\\{[^\\}]+?\\})")
        
        for imeRule in imeRules {
            if imeRule.isEmpty { continue }
            let components = imeRule.components(separatedBy: "\t")
            if components.count != 2 {
                throw EngineError.parseError("IME Rule not two column TSV: \(imeRule)")
            }
            if kMapStringSubPattern =~ components[0] {
                let inputs = kMapStringSubPattern.allMatching()!
                let output = try expandMappingRefs(components[1])
                try addRule(inputs: inputs, output: try Output(rule: output), state: state)
             }
        }
    }
    
    func state(for input: String, at state: State? = nil) -> State? {
        let state = state ?? self.state
        if let value = scheme.forwardMap[input] {
            // Try most specific mapping first
            if let nextState = state.next["\(value.1)/\(value.2)"] {
                return nextState
            }
            else {
                return state.next[value.1]
            }
        }
        else {
            return nil
        }
    }
    
    private func expandMappingRefs(_ input: String) throws -> String {
        var result = input
        while (kSpecificValuePattern =~ result) {
            let match = kSpecificValuePattern.matching()!
            let components = kSpecificValuePattern.captured()!.components(separatedBy: "/")
            if let map = scheme.mappings[components[0]]?[components[1]] {
                let replacement = match.hasPrefix("{") ? map.0 : map.1
                result = kSpecificValuePattern.replacing(with: replacement)!
            }
            else {
                throw EngineError.parseError("Cannot find mapping for \(match)")
            }
        }
        return result
    }
    
    private func addRule(inputs: [String], output: Output, state: State) throws {
        if inputs.count <= 0 {
            throw EngineError.parseError("Trying to add a rule with no inputs")
        }
        let nextState = state.next[inputs[0], default: State()]
        if inputs.count == 1 {
            nextState.output = output
        }
        else {
            try addRule(inputs: Array(inputs.dropFirst()), output: output, state: nextState)
        }
        state.next[inputs[0]] = nextState
    }
}
