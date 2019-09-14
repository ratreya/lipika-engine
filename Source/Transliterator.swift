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
 
 - Note:
    - `finalaizedInput`: The aggregate input in specified _script_ that will not change
    - `finalaizedOutput`: Transliterated unicode String in specified _script_ that will not change
    - `unfinalaizedInput`: The aggregate input in specified _script_ that will change based on future inputs
    - `unfinalaizedOutput`: Transliterated unicode String in specified _script_ that will change based on future inputs
 */
public typealias Literated = (finalaizedInput: String, finalaizedOutput: String, unfinalaizedInput: String, unfinalaizedOutput: String)

/**
 Stateful class that aggregates incremental input in the given _scheme_ and provides aggregated output in the specified _script_ through the transliterate API.
 
 __Usage__:
 ```
 class MyConfig: Config {
    ...
 }
 
 let factory = try TransliteratorFactory(config: MyConfig())
 
 guard let schemes = try factory.availableSchemes(), let scripts = try factory.availableScripts() else {
    // Deal with bad config
 }
 
 let tranliterator = try factory.tranliterator(schemeName: schemes[0], scriptName: scripts[0])
 
 try tranliterator.transliterate("...")
 ```
*/
public class Transliterator {
    private let config: Config
    private let engine: EngineProtocol
    private var results = [Result]()
    private var isEscaping = false
    private var wasOddEscape = false
    private var wasOddStop = false
    
    private func collapseBuffer() -> Literated {
        var response: Literated = ("", "", "", "")
        let finalizedIndex = results.lastIndex(where: { $0.isPreviousFinal }) ?? 0
        for (index, result) in results.enumerated() {
            if index < finalizedIndex {
                response.finalaizedInput += result.input
                response.finalaizedOutput += result.output
            }
            else {
                response.unfinalaizedInput += result.input
                response.unfinalaizedOutput += result.output
            }
        }
        return response
    }
    
    internal init(config: Config, engine: EngineProtocol) {
        self.config = config
        self.engine = engine
    }
    
    internal func transliterate(_ input: String) -> [Result] {
        for scalar in input.unicodeScalars {
            if scalar == config.stopCharacter {
                wasOddEscape = false
                engine.reset()
                // Output stop character only if it is escaped
                results.append(contentsOf: [Result(input: [config.stopCharacter], output: wasOddStop ? String(config.stopCharacter) : "", isPreviousFinal: true), Result(input: "", output: "", isPreviousFinal: true)])
                wasOddStop = !wasOddStop
            }
            else if scalar == config.escapeCharacter {
                wasOddStop = false
                engine.reset()
                // Output escape character only if it is escaped
                results.append(contentsOf: [Result(input: [scalar], output: wasOddEscape ? String(config.escapeCharacter) : "", isPreviousFinal: true), Result(input: "", output: "", isPreviousFinal: true)])
                isEscaping = !isEscaping
                wasOddEscape = !wasOddEscape
            }
            else {
                wasOddStop = false
                wasOddEscape = false
                if isEscaping {
                    results += [Result(inoutput: [scalar], isPreviousFinal: true), Result(input: "", output: "", isPreviousFinal: true)]
                }
                else {
                    results += engine.execute(input: scalar)
                }
            }
        }
        return results
    }
    
    /**
     A Boolean value indicating whether the `Transliterator` state is empty.
     */
    public func isEmpty() -> Bool {
        return results.isEmpty
    }
    
    /**
     Convert the given position from input index to output index or output index to input index within the aggregate state of the `Transliterator`.
     * If `inOutput` is true, `forPosition` is considered to be the output index and the corresponding input position is returned.
     * If `inOutput` is false, `forPosition` is considered to be the input index and the corresponding output position is returned.
     
     - Parameters:
       - forPosition: index position within the aggregate input or output string as specified by `inOutput` parameter
       - inOutput: if true then `forPosition` indicates position in the output string, otherwise indicates position in the input string
     - Returns: corrosponding index position in the aggregate output or input string or `nil` if the position is invalid
     */
    public func findPosition(forPosition: Int, inOutput: Bool) -> Int? {
        var remaining = forPosition
        var position = 0
        var index = 0
        while remaining > 0 {
            if index >= results.count {
                return nil
            }
            remaining -= inOutput ? results[index].output.unicodeScalars.count : results[index].input.unicodeScalars.count
            position += inOutput ? results[index].input.unicodeScalars.count : results[index].output.unicodeScalars.count
            index += 1
        }
        return position
    }

    /**
     Transliterate the aggregate input in the specified _scheme_ to the corresponding unicode string in the specified target _script_.
     
     - Important: This API maintains state and aggregates inputs given to it. Call `reset()` to clear state between invocations if desired.
     - Parameters:
       - input: (optional) Additional part of input string in specified _scheme_
       - position: (optional) Position within the aggregate input string at which to insert `input`
     - Returns: `Literated` output for the aggregated input
     */
    public func transliterate(_ input: String? = nil, position: Int? = nil) -> Literated {
        return synchronize(self) {
            if let input = input, let position = position {
                var inputs = results.reduce("", { previous, delta in return previous + delta.input })
                if position > inputs.count {
                    Logger.log.error("Position: \(position) passed to delete is larger than input string length: \(inputs.count)")
                    return collapseBuffer()
                }
                inputs.insert(contentsOf: input, at: inputs.index(inputs.startIndex, offsetBy: position))
                _ = reset()
                return transliterate(inputs)
            }
            if let input = input {
                let _:[Result] = transliterate(input)
            }
            return collapseBuffer()
        }
    }
    
    /**
     Delete the specified input character from the buffer if it exists or if unspecified, delete the last input character.

     - Important: the method is O(1) when `position` is either nil or unspecified and O(n) otherwise
     - Parameter position: (optional) the position **after** the input character to delete from the input string or the last character if unspecified
     - Returns: `Literated` output for the remaining input or `nil` if there is nothing to delete
    */
    public func delete(position: Int? = nil) -> Literated? {
        return synchronize(self) {
            engine.reset()
            if results.isEmpty || position == 0 {
                return nil
            }
            var inputs = results.reduce("", { previous, delta in return previous + delta.input })
            if let position = position {
                if position > inputs.unicodeScalars.count {
                    Logger.log.error("Position: \(position) passed to delete is larger than input string length: \(inputs.unicodeScalars.count)")
                    return nil
                }
                inputs.unicodeScalars.remove(at: inputs.unicodeScalars.index(before: inputs.unicodeScalars.index(inputs.unicodeScalars.startIndex, offsetBy: position)))
            }
            else {
                inputs.unicodeScalars.removeLast()
            }
            _ = reset()
            _ = transliterate(inputs)
            return collapseBuffer()
        }
    }
    
    /**
     Clears all transient internal state associated with previous inputs.
     
     - Returns: `Literated` output of what was in the buffer before clearing state or `nil` if there is nothing to clear
     */
    public func reset() -> Literated? {
        return synchronize(self) {
            engine.reset()
            let response = results.isEmpty ? nil: collapseBuffer()
            results = [Result]()
            isEscaping = false
            wasOddEscape = false
            wasOddStop = false
            return response
        }
    }
}
