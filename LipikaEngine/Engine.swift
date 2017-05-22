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
    private var replacements: [String]?
    
    init(rule: String) throws {
        let kOutputPattern = try RegEx(pattern: "[\\$([0-9]+)]")
        if kOutputPattern =~ rule {
            replacements = kOutputPattern.matching()
        }
    }
    
    func generate(intermediates: [String]) -> String {
        return ""
    }
}

class State {
    var output: Output?
    var next = [String: State]()
    
    init() {}
}

class Engine {

    let kSpecificValuePattern: NSRegularExpression
    let kMapStringSubPattern: NSRegularExpression
    let kAddendumSubPattern: NSRegularExpression

    let scheme: Scheme
    var state = State()
    
    init(imeRules: [String], scheme: Scheme) throws {
        self.scheme = scheme
        kSpecificValuePattern = try NSRegularExpression(pattern: "^\\s*(.+)\\s*/\\s*(.+)\\s*$", options: [])
        kMapStringSubPattern = try NSRegularExpression(pattern: "(\\[[^\\]]+?\\]|\\{[^\\}]+?\\})", options: [])
        kAddendumSubPattern = try NSRegularExpression(pattern: "%@", options: [])
        
        for imeRule in imeRules {
            if imeRule.isEmpty { continue }
            let components = imeRule.components(separatedBy: "\t")
            if components.count != 2 {
                throw EngineError.parseError("IME Rule not two column TSV: \(imeRule)")
            }
            let inputRule = components[0]
            let outputRule = components[1]
            let fullRange = NSRange(location: 0, length: inputRule.lengthOfBytes(using: .utf8))
            if kMapStringSubPattern.numberOfMatches(in: inputRule, options: [], range: fullRange) > 0 {
                let matches = kMapStringSubPattern.matches(in: inputRule, options: [], range: fullRange)
                var inputs = matches.flatMap({ (inputRule as NSString).substring(with: $0.rangeAt(0)) })
                addRule(inputs: &inputs, output: try Output(rule: outputRule), state: &state)
             }
        }
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
