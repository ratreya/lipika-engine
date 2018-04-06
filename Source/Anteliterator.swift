/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2018 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import Foundation

extension String.UnicodeScalarView {
    func hasPrefix (_ target: String.UnicodeScalarView) -> Bool {
        if self.count < target.count { return false }
        for (lvalue, rvalue) in zip(self, self.prefix(target.count)) {
            if lvalue != rvalue { return false }
        }
        return true
    }
}

/**
 Stateless class that provides the ability to reverse-transliterate from the given _script_ to the specified _scheme_ with the anteliterate API. Unlike the Transliterator, this class does not aggregate inputs. The assumption is that while anteliterating the clients already have the full output string that they want to reverse-transliterate into the specified _scheme_.
 
 __Usage__:
 ````
 struct MyConfig: Config {
 ...
 }
 
 let factory = try TransliteratorFactory(config: MyConfig())
 
 guard let schemes = try factory.availableSchemes(), let scripts = try factory.availableScripts() else {
 // Deal with bad config
 }
 
 let anteliterator = try factory.anteliterator(schemeName: schemes[0], scriptName: scripts[0])
 
 try anteliterator.anteliterate("...")
 ````
 */
public class Anteliterator {
    private let config: Config
    private let transliterator: Transliterator
    private let anteEngine: Engine
    
    internal init(config: Config, mappings: [String: MappingValue], imeRules: [String]) throws {
        self.config = config
        let transRules = try Rules(imeRules: imeRules, mappings: mappings)
        self.transliterator = Transliterator(config: config, engine: Engine(rules: transRules))
        let anteRules = try Rules(imeRules: imeRules, mappings: mappings, isReverse: true)
        self.anteEngine = Engine(rules: anteRules)
    }
    /**
     Reverse transliterates unicode string in the specified target _script_ into the corresponding `Result` in the specified _scheme_.
     
     - Parameter input: Unicode String in specified _script_
     - Returns: Corresponding `Result` input in specified _scheme_
     */
    internal func anteliterate(_ output: String) -> [Result] {
        let results = anteEngine.execute(inputs: output.unicodeScalars.reversed())
        var buffer = [Result]()
        var finalizedIndex = 0
        for result in results {
            if result.isPreviousFinal {
                finalizedIndex = buffer.endIndex
            }
            else {
                buffer.removeSubrange(finalizedIndex...)
            }
            buffer.append(result)
        }
        buffer = buffer.reversed().map() {
            return Result(input: $0.input.unicodeScalars.reversed(), output: String($0.output.reversed()), isPreviousFinal: $0.isPreviousFinal)
        }
        var stopIndices = [Int]()
        for (index, item) in buffer.enumerated().dropLast() {
            let firstResult = transliterator.transliterate(item.output)
            let original = firstResult.finalaizedOutput + firstResult.unfinalaizedOutput
            let nextResult = transliterator.transliterate(buffer[index + 1].output)
            assert(item.input == original, "\(original) != Trans(Ante(\(item.input)))")
            if !nextResult.finalaizedOutput.unicodeScalars.hasPrefix(original.unicodeScalars) {
                stopIndices.append(index + 1)
            }
            _ = transliterator.reset()
        }
        for stopIndex in stopIndices {
            buffer.insert(Result(input: [], output: String(config.stopCharacter), isPreviousFinal: true), at: stopIndex)
        }
        return buffer
    }

    /**
     Reverse transliterates unicode string in the specified target _script_ into the corresponding input in the specified _scheme_.
     
     - Parameter input: Unicode String in specified _script_
     - Returns: Corresponding String input in specified _scheme_
     */
    public func anteliterate(_ output: String) -> String {
        let results: [Result] = anteliterate(output)
        return results.reduce("", { (previous, delta) -> String in
            return previous.appending(delta.output)
        })
    }
}
