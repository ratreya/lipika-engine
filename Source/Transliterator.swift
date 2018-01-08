/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2018 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

public enum TransliteratorError : Error {
    
}

public class Transliterator {
    private var engine: Engine
    private(set) var schemeName: String
    private(set) var scriptName: String

    init(schemeName: String, scriptName: String) throws {
        self.schemeName = schemeName
        self.scriptName = scriptName
        engine = try EngineFactory.init(schemesDirectory: Config.schemesDirectory).engine(schemeName: schemeName, scriptName: scriptName)
    }
    
    /**
     Transliterate input in the specified scheme into the corresponding unicode string
     in the specified target script.
     
     - Parameter input: String input in specified _scheme_
     - Returns: Corresponding Unicode String in specified _script_
     - Throws: TransliteratorError
     */
    public func transliterate(_ input: String) throws -> String {
        return ""
    }
    
    /**
     Reverse transliterates unicode string in the specified target script into the
     corresponding input in the specified scheme.
     
     - Parameter input: Unicode String in specified _script_
     - Returns: Corresponding String input in specified _scheme_
     - Throws: TransliteratorError
     */
    public func anteliterate(_ output: String) throws -> String {
        return ""
    }
    
    /**
     Clears all transient internal state associated with previous inputs.
     */
    public func reset() {
    }
}
