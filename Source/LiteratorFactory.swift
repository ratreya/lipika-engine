/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2018 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

/**
 Use this class to get an instance of Transliterator. This class is responsible for the two step initialization that is needed to generate an instance of Transliterator.
 
 - Important: Handle any exception that are thrown from `init` and `instance` - these are indicative of a bad config.
 */
public class LiteratorFactory {
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
     - Throws: EngineError
     */
    public func transliterator(schemeName: String, scriptName: String) throws -> Transliterator {
        return try Transliterator(config: config, engine: factory.engine(schemeName: schemeName, scriptName: scriptName))
    }
}
