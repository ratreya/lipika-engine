/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2018 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

public enum TransliteratorError : Error {
    case invalidInput(String)
    case invalidSelection(String)
}

/**
 Use this class to get an instance of Transliterator. This class is responsible for the two step initialization that is needed to generate an instance of Transliterator.
 
 - Important: Handle any exception that are thrown from `init` and `instance` - these are indicative of a bad config.
 */
public class TransliteratorFactory {
    private let factory: EngineFactory
    private let config: Config
    
    /**
     Initialize with an implementation of the `Config` protocol.
    
     - Parameter config: Instance of a custom implementation of the `Config` protocol
     - Throws: EngineError
     */
    public init(config: Config) throws {
        self.config = config
        setThreadLocalData(key: Logger.logLevelKey, value: config.logLevel)
        self.factory = try EngineFactory.init(schemesDirectory: config.schemesDirectory)
    }

    /**
     Available schemes in the scheme directory provided by the custom implementation of `Config` that was used to initialize this factory class.
    
     - Returns: Array of _scheme_ names that can be passed to the `instance` function
     - Throws: EngineError
     */
    public func availableSchemes() throws -> [String]? {
        return try factory.availableSchemes()
    }
    
    /**
     Available scripts in the scheme directory provided by the custom implementation of `Config` that was used to initialize this factory class.
     
     - Returns: Array of _script_ names that can be passed to the `instance` function
     - Throws: EngineError
     */
    public func availableScripts() throws -> [String]? {
        return try factory.availableScripts()
    }
    
    /**
     Get an instance of Transliterator for the specified _scheme_ and _script_.
    
     - Parameters:
       - schemeName: Name of the _scheme_ which should be one of `availableSchemes`
       - scriptName: Name of the _script_ which should be one of `availableScripts`
     - Returns: Instance of Transliterator for the given _scheme_ and _script_
     - Throws: TransliteratorError
     */
    public func instance(schemeName: String, scriptName: String) throws -> Transliterator {
        if let isValidScheme = try availableSchemes()?.contains(schemeName), let isValidScript = try availableScripts()?.contains(scriptName), !isValidScript || !isValidScheme {
            throw TransliteratorError.invalidSelection("Scheme: \(schemeName) and Script: \(scriptName) are invalid")
        }
        return try Transliterator(config: config, engine: factory.engine(schemeName: schemeName, scriptName: scriptName))
    }
}

/**
 Stateful class that aggregates incremental input and provides aggregated output through the transliterate API. It also provides the ability to reverse-transliterate with the anteliterate API.
 
 `Usage`:
 ````
 struct MyConfig: Config {
    ...
 }
 
 let factory = try TransliteratorFactory(config: MyConfig())
 
 guard let schemes = try factory.availableSchemes(), let scripts = try factory.availableScripts() else {
    // Deal with bad config
 }
 
 let tranliterator = try factory.instance(schemeName: schemes[0], scriptName: scripts[0])
 
 try tranliterator.transliterate("...")
 ````
*/
public class Transliterator {
    private let config: Config
    private let engine: Engine
    private var buffer = [Result]()
    private var finalizedIndex = 0
    
    private func collapseBuffer() -> (finalaizedInput: String, finalaizedOutput: String, unfinalaizedinput: String, unfinalaizedOutput: String) {
        return ("", "", "", "")
    }

    /**
     Initialize with the given _scheme_ and _script_ names. These should be from `availableSchemes` and `availableScripts` respectively.
     
     - Parameters:
         - schemeName: name of the desired scheme from `availableSchemes`
         - scriptName: name of the desired script from `availableScripts`
     - Throws: TransliteratorError
    */
    fileprivate init(config: Config, engine: Engine) throws {
        self.config = config
        self.engine = engine
    }
    
    /**
     Transliterate the aggregate input in the specified _scheme_ to the corresponding unicode string in the specified target _script_.
     
     - Important: This API maintains state and aggregates inputs given to it. Call `reset()` to clear state between invocations if desired.
     - Parameter input: Latest part of String input in specified _scheme_
     - Returns:
        - `finalaizedInput`: The aggregate input in specified _script_ that will not change
        - `finalaizedOutput`: Transliterated unicode String in specified _script_ that will not change
        - `unfinalaizedInput`: The aggregate input in specified _script_ that will change based on future inputs
        - `unfinalaizedOutput`: Transliterated unicode String in specified _script_ that will change based on future inputs
     - Throws: TransliteratorError
     */
    public func transliterate(_ input: String) throws -> (finalaizedInput: String, finalaizedOutput: String, unfinalaizedinput: String, unfinalaizedOutput: String) {
        for inputCharacter in input {
            if inputCharacter.unicodeScalars.count != 1 {
                throw TransliteratorError.invalidInput("Input character: \(inputCharacter) in Input: \(input) is not an ASCII character")
            }
            if inputCharacter == config.stopCharacter {
                
            }
            if CharacterSet.whitespacesAndNewlines.contains(inputCharacter.unicodeScalars.first!) {
                
            }
            for result in engine.execute(input: inputCharacter) {
                if result.isPreviousFinal {
                    finalizedIndex = buffer.endIndex
                }
                buffer.append(result)
            }
        }
        return collapseBuffer()
    }
    
    /**
     Reverse transliterates unicode string in the specified target _script_ into the corresponding input in the specified _scheme_.
     
     - Parameter input: Unicode String in specified _script_
     - Returns: Corresponding String input in specified _scheme_
     - Throws: TransliteratorError
     */
    public func anteliterate(_ output: String) throws -> String {
        return ""
    }
    
    /**
     Delete the last input character from the buffer if it exists.
     
     - Returns
       - `input`: String input remaining after the delete
       - `output`: Corrosponding Unicode String in specified _script_
       - `wasHandled`: true if there was something that was actually deleted; false if there was nothing to delete
    */
    public func delete() -> (input: String, output: String, wasHandled: Bool) {
        return ("", "", false)
    }
    
    /**
     Clears all transient internal state associated with previous inputs.
     
     - Returns
         - `input`: Remaining unfinalized input in specified _scheme_ that was cleared
         - `output`: Remaining unfinalized output in specified _script_ that was cleared
     */
    public func reset() -> (input: String, output: String) {
        return ("", "")
    }
}
