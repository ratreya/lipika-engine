/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2018 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

struct Result {
    private (set) var input: String
    private (set) var output: String
    
    /// If this is true then all outputs before this is final and will not be changed anymore.
    var isPreviousFinal = false
    
    init(input: String, output: String, isPreviousFinal: Bool) {
        self.input = input
        self.output = output
        self.isPreviousFinal = isPreviousFinal
    }
    
    init(input: [UnicodeScalar], output: String, isPreviousFinal: Bool) {
        self.init(input: "" + input, output: output, isPreviousFinal: isPreviousFinal)
    }
    
    init(inoutput: String, isPreviousFinal: Bool) {
        self.init(input: inoutput, output: inoutput, isPreviousFinal: isPreviousFinal)
    }
    
    init(inoutput: [UnicodeScalar], isPreviousFinal: Bool) {
        let strInoutput = "" + inoutput
        self.init(input: strInoutput, output: strInoutput, isPreviousFinal: isPreviousFinal)
    }
}

protocol EngineProtocol {
    func reset()
    func execute(inputs: String) -> [Result]
    func execute(inputs: [UnicodeScalar]) -> [Result]
    func execute(input: UnicodeScalar) -> [Result]
}

/**
 Use this class to get an instance of Transliterator and Anteliterator. This class is responsible for the two step initialization that is needed to generate an instance of Transliterator or Anteliterator.
 
 - Important: Handle any exception that are thrown from `init`, `transliterator` and `anteliterator` - these are indicative of a bad config.
 */
public class LiteratorFactory {
    private let factory: EngineFactory
    private let customFactory: CustomFactory
    private let config: Config
    
    /**
     Initialize with an implementation of the `Config` protocol.
     
     - Parameter config: Instance of a custom implementation of the `Config` protocol
     - Throws: EngineError
     */
    public init(config: Config) throws {
        self.config = config
        setThreadLocalData(key: Logger.logLevelKey, value: config.logLevel)
        self.factory = try EngineFactory(schemesDirectory: config.mappingDirectory)
        self.customFactory = try CustomFactory(mappingDirectory: config.customMappingDirectory)
    }
    
    /**
     Available schemes in the scheme directory provided by the custom implementation of `Config` that was used to initialize this factory class.
     
     - Returns: Array of _scheme_ names that can be passed to the `instance` function
     - Throws: EngineError
     */
    public func availableSchemes() throws -> [String] {
        return try factory.availableSchemes()
    }
    
    /**
     Available scripts in the scheme directory provided by the given implementation of `Config` that was used to initialize this factory class.
     
     - Returns: Array of _script_ names that can be passed to the `transliterator` or `anteliterator` function
     - Throws: EngineError
     */
    public func availableScripts() throws -> [String] {
        return try factory.availableScripts()
    }
    
    /**
     Available custom mappings in the directory provided by the given implementation of `Config` that was used to initialize this factory class.
     
     - Returns: Array of _customMapping_ names that can be passed to the `transliterator` or `anteliterator` function
     - Throws: EngineError
     */
    public func availableCustomMappings() throws -> [String] {
        return try customFactory.availableCustomMappings()
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
        return try synchronize(self) {
            return try Transliterator(config: config, engine: factory.engine(schemeName: schemeName, scriptName: scriptName))
        }
    }

    /**
     Get an instance of Anteliterator for the specified _scheme_ and _script_.
     
     - Parameters:
     - schemeName: Name of the _scheme_ which should be one of `availableSchemes`
     - scriptName: Name of the _script_ which should be one of `availableScripts`
     - Returns: Instance of Anteliterator for the given _scheme_ and _script_
     - Throws: EngineError
     */
    public func anteliterator(schemeName: String, scriptName: String) throws -> Anteliterator {
        return try synchronize(self) {
            let parsed = try factory.parse(schemeName: schemeName, scriptName: scriptName)
            let transRules = try Rules(imeRules: parsed.rules, mappings: parsed.mappings)
            let transEngine = Engine(rules: transRules)
            let anteRules = try Rules(imeRules: parsed.rules, mappings: parsed.mappings, isReverse: true)
            let anteEngine = Engine(rules: anteRules)
            return try Anteliterator(config: config, transEngine: transEngine, anteEngine: anteEngine)
        }
    }
    
    /**
     Get an instance of Transliterator for the specified _customMapping_.
     
     - Parameters:
     - customMapping: Name of the _customMapping_ which should be one of `availableCustomMappings`
     - Returns: Instance of Transliterator for the given _customMapping_
     - Throws: EngineError
     */
    public func transliterator(customMapping: String) throws -> Transliterator {
        return try synchronize(self) {
            return try Transliterator(config: config, engine: customFactory.customEngine(customMapping: customMapping, isReverse: false))
        }
    }
    
    /**
     Get an instance of Anteliterator for the specified _customMapping_.
     
     - Parameters:
     - customMapping: Name of the _customMapping_ which should be one of `availableCustomMappings`
     - Returns: Instance of Anteliterator for the given _customMapping_
     - Throws: EngineError
     */
    public func anteliterator(customMapping: String) throws -> Anteliterator {
        return try synchronize(self) {
            let transEngine = try customFactory.customEngine(customMapping: customMapping, isReverse: false)
            let anteEngine = try customFactory.customEngine(customMapping: customMapping, isReverse: true)
            return try Anteliterator(config: config, transEngine: transEngine, anteEngine: anteEngine)
        }
    }
}
