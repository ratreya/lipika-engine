/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2018 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

/**
 Transliterated output of any function that changes input.
 
 *Notes*:
    - `finalaizedInput`: The aggregate input in specified _script_ that will not change
    - `finalaizedOutput`: Transliterated unicode String in specified _script_ that will not change
    - `unfinalaizedInput`: The aggregate input in specified _script_ that will change based on future inputs
    - `unfinalaizedOutput`: Transliterated unicode String in specified _script_ that will change based on future inputs
 */
public typealias Literated = (finalaizedInput: String, finalaizedOutput: String, unfinalaizedInput: String, unfinalaizedOutput: String)

/**
 Stateful class that aggregates incremental input in the given _scheme_ and provides aggregated output in the specified _script_ through the transliterate API.
 
 __Usage__:
 ````
 struct MyConfig: Config {
    ...
 }
 
 let factory = try TransliteratorFactory(config: MyConfig())
 
 guard let schemes = try factory.availableSchemes(), let scripts = try factory.availableScripts() else {
    // Deal with bad config
 }
 
 let tranliterator = try factory.tranliterator(schemeName: schemes[0], scriptName: scripts[0])
 
 try tranliterator.transliterate("...")
 ````
*/
public class Transliterator {
    private let config: Config
    private let engine: EngineProtocol
    private var results = [Result]()
    private var finalizedIndex = 0
    
    // This logic is shared with the Anteliterator
    static func finalizeResults(_ rawResults: [Result], _ results: inout [Result], _ finalizedIndex: inout Int) {
        for rawResult in rawResults {
            if rawResult.isPreviousFinal {
                finalizedIndex = results.endIndex
            }
            else {
                results.removeSubrange(finalizedIndex...)
            }
            results.append(rawResult)
        }
    }
    
    private func finalizeResults(_ finalizedResults: [Result]) {
        Transliterator.finalizeResults(finalizedResults, &results, &finalizedIndex)
    }
    
    private func collapseBuffer() -> Literated {
        var result: Literated = ("", "", "", "")
        for index in results.indices {
            if index < finalizedIndex {
                result.finalaizedInput += results[index].input
                result.finalaizedOutput += results[index].output
            }
            else {
                result.unfinalaizedInput += results[index].input
                result.unfinalaizedOutput += results[index].output
            }
        }
        return result
    }

    internal init(config: Config, engine: EngineProtocol) {
        self.config = config
        self.engine = engine
    }
    
    internal func transliterate(_ input: String) -> [Result] {
        var wasStopChar = false
        for scalar in input.unicodeScalars {
            if scalar == config.stopCharacter {
                engine.reset()
                // Output stop character only if it is escaped
                finalizeResults([Result(input: [config.stopCharacter], output: wasStopChar ? String(config.stopCharacter) : "", isPreviousFinal: true)])
                wasStopChar = !wasStopChar
            }
            else {
                finalizeResults(engine.execute(input: scalar))
                wasStopChar = false
            }
        }
        return results
    }
    
    /**
     Transliterate the aggregate input in the specified _scheme_ to the corresponding unicode string in the specified target _script_.
     
     - Important: This API maintains state and aggregates inputs given to it. Call `reset()` to clear state between invocations if desired.
     - Parameter input: Latest part of String input in specified _scheme_
     - Returns: `Literated` output for the aggregated input
     */
    public func transliterate(_ input: String) -> Literated {
        return synchronize(self) {
            let _:[Result] = transliterate(input)
            return collapseBuffer()
        }
    }
    
    /**
     Delete the last input character from the buffer if it exists.
     
     - Returns
       - `input`: String input remaining after the delete
       - `output`: Corrosponding Unicode String in specified _script_
       - `wasHandled`: true if there was something that was actually deleted; false if there was nothing to delete
    */
    public func delete() -> (input: String, output: String, wasHandled: Bool) {
        return synchronize(self) {
            if results.isEmpty {
                return ("", "", false)
            }
            let last = results.removeLast()
            engine.reset()
            let newResults = engine.execute(inputs: String(last.input.dropLast()))
            finalizeResults(newResults)
            let response = collapseBuffer()
            assert(response.finalaizedInput.isEmpty && response.finalaizedOutput.isEmpty, "Deleting produced finalized input/output!")
            return (response.unfinalaizedInput, response.unfinalaizedOutput, true)
        }
    }
    
    /**
     Clears all transient internal state associated with previous inputs.
     
     - Returns: `Literated` output of what was in the buffer before clearing state
     */
    public func reset() -> Literated {
        return synchronize(self) {
            engine.reset()
            let response = collapseBuffer()
            results = [Result]()
            finalizedIndex = results.startIndex
            return response
        }
    }
}
