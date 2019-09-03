/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2018 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import Foundation

extension String {
    func isWhitespace() -> Bool {
        return !self.isEmpty && self.unicodeScalars.reduce(true) { (previous, delta) -> Bool in
            return previous && CharacterSet.whitespacesAndNewlines.contains(delta)
        }
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
    private let anteEngine: EngineProtocol
    
    internal init(config: Config, transEngine: EngineProtocol, anteEngine: EngineProtocol) throws {
        self.config = config
        self.transliterator = Transliterator(config: config, engine: transEngine)
        self.anteEngine = anteEngine
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
        anteEngine.reset()
        var results = anteEngine.execute(inputs: output.unicodeScalars.reversed())
        results = results.reversed().map() {
            return Result(input: $0.input.unicodeScalarReversed(), output: $0.output.unicodeScalarReversed(), isPreviousFinal: $0.isPreviousFinal)
        }
        results = compactResults(results)
        results = results.compactMap() {
            var output = $0.output.replacingOccurrences(of: String(config.stopCharacter), with: String(config.stopCharacter) + String(config.stopCharacter))
            output = output.replacingOccurrences(of: String(config.escapeCharacter), with: String(config.escapeCharacter) + String(config.escapeCharacter))
            return Result(input: $0.input, output: output, isPreviousFinal: $0.isPreviousFinal)
        }
        // Add stop characters
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
        // Add escape characters
        var escapeIndices = [Int]()
        for (index, item) in results.enumerated() {
            if item.input == item.output, !item.input.isWhitespace(), (index == 0 || results[index-1].input != results[index-1].output) {
                escapeIndices.append(index)
            }
            if (item.input != item.output || item.input.isWhitespace()), escapeIndices.count % 2 != 0 {
                escapeIndices.append(index)
            }
        }
        for escapeIndex in escapeIndices.reversed() {
            results.insert(Result(input: [], output: String(config.escapeCharacter), isPreviousFinal: true), at: escapeIndex)
        }
        if escapeIndices.count%2 != 0 {
            results.append(Result(input: [], output: String(config.escapeCharacter), isPreviousFinal: true))
        }
        return results
    }

    /**
     Reverse transliterates unicode string in the specified target _script_ into the corresponding input String in the specified _scheme_.
     
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
