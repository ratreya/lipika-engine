/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import Foundation

public enum EngineError: Error {
    case ioError(String)
    case parseError(String)
    case invalidSelection(String)
}

class EngineFactory {
    private let mappingDirectory: URL
    private let schemeSubDirectory: URL
    private let scriptSubDirectory: URL

    private let kSchemeExtension = "scheme"
    private let kScriptExtension = "script"
    private let kRuleExtension = "rule"
    private let kScriptOverridePattern: RegEx
    private let kSchemeOverridePattern: RegEx
    private let kImeOverridePattern: RegEx

    init(schemesDirectory: URL) throws {
        self.mappingDirectory = schemesDirectory
        guard FileManager.default.fileExists(atPath: schemesDirectory.path) else {
            throw EngineError.ioError("Invalid schemesDirectory: \(schemesDirectory)")
        }
        self.schemeSubDirectory = schemesDirectory.appendingPathComponent("Scheme")
        self.scriptSubDirectory = schemesDirectory.appendingPathComponent("Script")
        kScriptOverridePattern = try RegEx(pattern: "^\\s*Script\\s*:\\s*(.+)\\s*$")
        kSchemeOverridePattern = try RegEx(pattern: "^\\s*Scheme\\s*:\\s*(.+)\\s*$")
        kImeOverridePattern = try RegEx(pattern: "^\\s*Rule\\s*:\\s*(.+)\\s*$")
    }
    
    private func ruleFile(schemeName: String, scriptName: String) -> URL {
        let specificIMEFile = mappingDirectory.appendingPathComponent("\(scriptName)-\(schemeName)").appendingPathExtension(kRuleExtension)
        let defaultIMEFile = mappingDirectory.appendingPathComponent("Default").appendingPathExtension(kRuleExtension)
        return FileManager.default.fileExists(atPath: specificIMEFile.path) ? specificIMEFile : defaultIMEFile
    }
    
    private func mapForThreeColumnTSVFile(file: URL) throws -> [String:OrderedMap<String, String>] {
        var map = [String: OrderedMap<String, String>]()
        if FileManager.default.fileExists(atPath: file.path) {
            try mapForThreeColumnTSVFile(file: file, map: &map)
        }
        else {
            throw EngineError.ioError("File: \(file) does not exist but was expected")
        }
        return map
    }
    
    private func mapForThreeColumnTSVFile(file: URL, map: inout [String: OrderedMap<String, String>]) throws {
        let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: CharacterSet.newlines)
        for line in lines {
            if line.isEmpty || line.trimmingCharacters(in: .whitespaces).isEmpty || line.trimmingCharacters(in: .whitespaces).starts(with: "//") { continue }
            let components = line.components(separatedBy: "\t").map { $0.trimmingCharacters(in: .whitespaces) }
            let isAnyComponentEmpty = components.reduce(false) { result, delta in return result || delta.isEmpty }
            if components.count != 3 || isAnyComponentEmpty {
                Logger.log.warning("Ignoring unparsable line: \(line) in file: \(file.path)")
                continue
            }
            map[components[0], default: OrderedMap<String, String>()][components[1]] = components[2]
        }
    }

    private func parseRuleFile(_ file: URL, schemeMap: inout [String: OrderedMap<String, String>], scriptMap: inout [String: OrderedMap<String, String>]) throws -> [String] {
        var imeRules = [String]()
        let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: .newlines)
        for line in lines {
            if line.isEmpty || line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            if kSchemeOverridePattern =~ line {
                let overrides = kSchemeOverridePattern.captured()!.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                for override in overrides {
                    let overrideFile = schemeSubDirectory.appendingPathComponent(override).appendingPathExtension(kSchemeExtension)
                    try mapForThreeColumnTSVFile(file: overrideFile, map: &schemeMap)
                }
            }
            else if kScriptOverridePattern =~ line {
                let overrides = kScriptOverridePattern.captured()!.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                for override in overrides {
                    let overrideFile = scriptSubDirectory.appendingPathComponent(override).appendingPathExtension(kScriptExtension)
                    try mapForThreeColumnTSVFile(file: overrideFile, map: &scriptMap)
                }
            }
            else if kImeOverridePattern =~ line {
                let overrides = kImeOverridePattern.captured()!.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                for override in overrides {
                    let overrideFile = mappingDirectory.appendingPathComponent(override).appendingPathExtension(kRuleExtension)
                    imeRules.append(contentsOf: try parseRuleFile(overrideFile, schemeMap: &schemeMap, scriptMap: &scriptMap))
                }
            }
            else {
                imeRules.append(line)
            }
        }
        return imeRules
    }
    
    func availableScripts() throws -> [String] {
        do {
            return try filesInDirectory(directory: scriptSubDirectory, withExtension: kScriptExtension)
        }
        catch {
            throw EngineError.ioError(error.localizedDescription)
        }
    }
    
    func availableSchemes() throws -> [String] {
        do {
            return try filesInDirectory(directory: schemeSubDirectory, withExtension: kSchemeExtension)
        }
        catch {
            throw EngineError.ioError(error.localizedDescription)
        }
    }
    
    func parse(schemeName: String, scriptName: String) throws -> (rules: [String], mappings: [String: MappingValue]) {
        guard try availableSchemes().contains(schemeName), try availableScripts().contains(scriptName) else {
            throw EngineError.invalidSelection("Scheme: \(schemeName) and Script: \(scriptName) are invalid")
        }
        let schemeFile = schemeSubDirectory.appendingPathComponent(schemeName).appendingPathExtension(kSchemeExtension)
        let scriptFile = scriptSubDirectory.appendingPathComponent(scriptName).appendingPathExtension(kScriptExtension)
        var schemeMap =  try mapForThreeColumnTSVFile(file: schemeFile)
        var scriptMap = try mapForThreeColumnTSVFile(file: scriptFile)
        let ruleFile = self.ruleFile(schemeName: schemeName, scriptName: scriptName)
        let rules = try parseRuleFile(ruleFile, schemeMap: &schemeMap, scriptMap: &scriptMap)
        
        // Generate common mappings with ordered keys: Type->Key->([Scheme], Script)
        var mappings = [String: MappingValue]()
        for type in schemeMap.keys {
            for key in schemeMap[type]!.keys {
                let inputs = schemeMap[type]![key]!.components(separatedBy: ",").map({ $0.trimmingCharacters(in: .whitespaces) })
                let output = scriptMap[type]?[key]?.components(separatedBy: ",").map({ $0.trimmingCharacters(in: .whitespaces)}).compactMap({ String(UnicodeScalar(Int($0, radix: 16)!)!) }).joined()
                mappings[type, default: MappingValue()][key] = (inputs, output)
            }
        }
        return (rules, mappings)
    }
    
    func rules(schemeName: String, scriptName: String) throws -> Rules {
        let parsed = try parse(schemeName: schemeName, scriptName: scriptName)
        return try Rules(imeRules: parsed.rules, mappings: parsed.mappings)
    }
    
    func engine(schemeName: String, scriptName: String) throws -> Engine {
        return try Engine(rules: rules(schemeName: schemeName, scriptName: scriptName))
    }
}
