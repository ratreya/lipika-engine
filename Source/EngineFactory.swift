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
    private let kThreeColumnTSVPattern: RegEx
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
        kThreeColumnTSVPattern = try RegEx(pattern: "^\\s*([^\\t]+?)\\t+([^\\t]+?)\\t+(.*)\\s*$")
        kScriptOverridePattern = try RegEx(pattern: "^\\s*Script\\s*:\\s*(.+)\\s*$")
        kSchemeOverridePattern = try RegEx(pattern: "^\\s*Scheme\\s*:\\s*(.+)\\s*$")
        kImeOverridePattern = try RegEx(pattern: "^\\s*Rule\\s*:\\s*(.+)\\s*$")
    }
    
    private func filesInDirectory(directory: URL, withExtension ext: String) throws -> [String] {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [], options: [])
            return files.filter({$0.pathExtension == ext}).compactMap { $0.deletingPathExtension().lastPathComponent }
        }
        catch let error {
            throw EngineError.ioError(error.localizedDescription)
        }
    }
    
    private func imeFile(schemeName: String, scriptName: String) -> URL {
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
            Logger.log.debug("File: \(file) does not exist, returning empty map.")
        }
        return map
    }
    
    private func mapForThreeColumnTSVFile(file: URL, map: inout [String: OrderedMap<String, String>]) throws {
        let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: CharacterSet.newlines)
        for line in lines {
            if line.isEmpty { continue }
            let components = line.components(separatedBy: "\t").map { $0.trimmingCharacters(in: .whitespaces) }
            let isAnyComponentEmpty = components.reduce(false) { result, delta in return result || delta.isEmpty }
            if components.count != 3 || isAnyComponentEmpty {
                Logger.log.warning("Ignoring unparsable line: \(line) in file: \(file.path)")
                continue
            }
            map[components[0], default: OrderedMap<String, String>()][components[1]] = components[2]
        }
    }

    private func parseIMEFile(_ file: URL, schemeMap: inout [String: OrderedMap<String, String>], scriptMap: inout [String: OrderedMap<String, String>]) throws -> Array<String> {
        var imeRules = [String]()
        let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: CharacterSet.newlines)
        for line in lines {
            if line.isEmpty { continue }
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
                    imeRules.append(contentsOf: try parseIMEFile(overrideFile, schemeMap: &schemeMap, scriptMap: &scriptMap))
                }
            }
            else {
                imeRules.append(line)
            }
        }
        return imeRules
    }
    
    func availableScripts() throws -> [String] {
        return try filesInDirectory(directory: scriptSubDirectory, withExtension: kScriptExtension)
    }
    
    func availableSchemes() throws -> [String] {
        return try filesInDirectory(directory: schemeSubDirectory, withExtension: kSchemeExtension)
    }
    
    func parse(schemeName: String, scriptName: String) throws -> (imeRules: [String], mappings: [String: MappingValue]) {
        guard try availableSchemes().contains(schemeName), try availableScripts().contains(scriptName) else {
            throw EngineError.invalidSelection("Scheme: \(schemeName) and Script: \(scriptName) are invalid")
        }
        let schemeFile = schemeSubDirectory.appendingPathComponent(schemeName).appendingPathExtension(kSchemeExtension)
        let scriptFile = scriptSubDirectory.appendingPathComponent(scriptName).appendingPathExtension(kScriptExtension)
        var schemeMap =  try mapForThreeColumnTSVFile(file: schemeFile)
        var scriptMap = try mapForThreeColumnTSVFile(file: scriptFile)
        let imeFile = self.imeFile(schemeName: schemeName, scriptName: scriptName)
        let imeRules = try parseIMEFile(imeFile, schemeMap: &schemeMap, scriptMap: &scriptMap)
        
        // Generate common mappings with ordered keys: Type->Key->([Scheme], Script)
        var mappings = [String: MappingValue]()
        for type in schemeMap.keys {
            for key in schemeMap[type]!.keys {
                let inputs = schemeMap[type]![key]!.components(separatedBy: ",").map({ $0.trimmingCharacters(in: .whitespaces) })
                let output = scriptMap[type]?[key]?.components(separatedBy: ",").map({ $0.trimmingCharacters(in: .whitespaces)}).compactMap({ String(UnicodeScalar(Int($0, radix: 16)!)!) }).joined()
                mappings[type, default: MappingValue()][key] = (inputs, output)
            }
        }
        return (imeRules, mappings)
    }
    
    func rules(schemeName: String, scriptName: String) throws -> Rules {
        let parsed = try parse(schemeName: schemeName, scriptName: scriptName)
        return try Rules(imeRules: parsed.imeRules, mappings: parsed.mappings)
    }
    
    public func engine(schemeName: String, scriptName: String) throws -> Engine {
        return try Engine(rules: rules(schemeName: schemeName, scriptName: scriptName))
    }
}
