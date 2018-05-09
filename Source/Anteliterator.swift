/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2018 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import Foundation

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
    
    private func finalizeResults(_ rawResults: [Result]) -> [Result] {
        var results = [Result]()
        var finalizedIndex = 0
        Transliterator.finalizeResults(rawResults, &results, &finalizedIndex)
        return results
    }
    
    /// This is necessary for correctness otherwise unnecessary stop characters will be introduced
    private func compactResults(_ rawResults: [Result]) -> [Result] {
        var results = [Result]()
        var wasLastInoutput = false
        for currentResult in rawResults {
            let isCurrentInoutput = currentResult.input == currentResult.output
            if wasLastInoutput && isCurrentInoutput {
                let lastResult = results.removeLast()
                results.append(Result(inoutput: lastResult.input + currentResult.input, isPreviousFinal: true))
            }
            else {
                results.append(currentResult)
            }
            wasLastInoutput = isCurrentInoutput
        }
        return results
    }
    
    /**
     Reverse transliterates unicode string in the specified target _script_ into the corresponding `Result` in the specified _scheme_.
     
     - Parameter input: Unicode String in specified _script_
     - Returns: Corresponding `Result` input in specified _scheme_
     */
    internal func anteliterate(_ output: String) -> [Result] {
        let rawResults = anteEngine.execute(inputs: output.unicodeScalars.reversed())
        var results = finalizeResults(rawResults)
        results = results.reversed().map() {
            return Result(input: $0.input.unicodeScalarReversed(), output: $0.output.unicodeScalarReversed(), isPreviousFinal: $0.isPreviousFinal)
        }
        results = compactResults(results)
        results = results.compactMap({ return Result(input: $0.input, output: $0.output.replacingOccurrences(of: "\\", with: "\\\\"), isPreviousFinal: $0.isPreviousFinal) })
        var stopIndices = [Int]()
        for (index, item) in results.enumerated().dropLast() {
            let combinedResults: Literated = transliterator.transliterate(item.output + results[index + 1].output)
            if combinedResults.finalaizedOutput + combinedResults.unfinalaizedOutput != results[index].input + results[index + 1].input {
                stopIndices.append(index + 1)
            }
            _ = transliterator.reset()
        }
        for stopIndex in stopIndices.reversed() {
            results.insert(Result(input: [], output: String(config.stopCharacter), isPreviousFinal: true), at: stopIndex)
        }
        return results
    }

    /**
     Reverse transliterates unicode string in the specified target _script_ into the corresponding input in the specified _scheme_.
     
     - Parameter input: Unicode String in specified _script_
     - Returns: Corresponding String input in specified _scheme_
     */
    public func anteliterate(_ output: String) -> String {
        return synchronize(self) {
            let results: [Result] = anteliterate(output)
            return results.reduce("", { (previous, delta) -> String in
                return previous.appending(delta.output)
            })
        }
    }
}
