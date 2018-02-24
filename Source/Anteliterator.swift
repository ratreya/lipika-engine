/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2018 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

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
    private let transEngine: Engine
    private let anteEngine: Engine
    
    internal init(config: Config, mappings: [String: MappingValue], imeRules: [String]) throws {
        self.config = config
        let transRules = try Rules(imeRules: imeRules, mappings: mappings)
        self.transEngine = Engine(rules: transRules)
        let anteRules = try Rules(imeRules: imeRules, mappings: mappings, isReverse: true)
        self.anteEngine = Engine(rules: anteRules)
    }
    
    /**
     Reverse transliterates unicode string in the specified target _script_ into the corresponding input in the specified _scheme_.
     
     - Parameter input: Unicode String in specified _script_
     - Returns: Corresponding String input in specified _scheme_
     - Throws: EngineError
     */
    public func anteliterate(_ output: String) throws -> String {
        return ""
    }
}
