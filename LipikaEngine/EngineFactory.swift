/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import Foundation

enum EngineError: Error {
    case ioError(String)
    case parseError(String)
}

class EngineFactory {
    private let logger = Logger()
    private let schemesDirectory: URL
    private let schemeSubDirectory: URL
    private let scriptSubDirectory: URL

    private let kSchemeExtension = "tlr"
    private let kScriptExtension = "lng"
    private let kImeExtension = "ime"
    private let kThreeColumnTSVPattern: RegEx
    private let kScriptOverridePattern: RegEx
    private let kSchemeOverridePattern: RegEx
    private let kImeOverridePattern: RegEx

    init(schemesDirectory: URL) throws {
        self.schemesDirectory = schemesDirectory
        if !FileManager.default.fileExists(atPath: schemesDirectory.path) {
            throw EngineError.ioError("Invalid schemesDirectory: \(schemesDirectory)")
        }
        self.schemeSubDirectory = schemesDirectory.appendingPathComponent("Transliteration")
        self.scriptSubDirectory = schemesDirectory.appendingPathComponent("Script")
        kThreeColumnTSVPattern = try RegEx(pattern: "^\\s*([^\\t]+?)\\t+([^\\t]+?)\\t+(.*)\\s*$")
        kScriptOverridePattern = try RegEx(pattern: "^\\s*Script\\s*:\\s*(.+)\\s*$")
        kSchemeOverridePattern = try RegEx(pattern: "^\\s*Transliteration\\s*:\\s*(.+)\\s*$")
        kImeOverridePattern = try RegEx(pattern: "^\\s*IME\\s*:\\s*(.+)\\s*$")
    }
    
    private func filesInDirectory(directory: URL, withExtension ext: String) throws -> [String]? {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [], options: [])
            return files.filter({$0.pathExtension == ext}).flatMap({($0.lastPathComponent as NSString).deletingPathExtension})
        }
        catch let error {
            throw EngineError.ioError(error.localizedDescription)
        }
    }
    
    private func imeFile(schemeName: String, scriptName: String) -> URL {
        let specificIMEFile = schemesDirectory.appendingPathComponent("\(scriptName)-\(schemeName)").appendingPathExtension("ime")
        let defaultIMEFile = schemesDirectory.appendingPathComponent("Default.ime")
        return FileManager.default.fileExists(atPath: specificIMEFile.path) ? specificIMEFile : defaultIMEFile
    }
    
    private func mapForTSVFile(file: URL, map: inout [String:OrderedMap<String, String>]) throws {
        let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: CharacterSet.newlines)
        for line in lines {
            if line.isEmpty { continue }
            let components = line.components(separatedBy: "\t").map({$0.trimmingCharacters(in: .whitespaces)})
            let isAnyComponentEmpty = components.reduce(false) {result, delta in return result || delta.isEmpty}
            if components.count != 3 || isAnyComponentEmpty {
                logger.log(level: .Warning, message: "Ignoring unparsable line: \(line) in file: \(file.path)")
                continue
            }
            if map[components[0]] == nil {
                map[components[0]] = OrderedMap<String, String>()
            }
            map[components[0]]?.updateValue(components[2], forKey: components[1])
        }
    }

    private func parseIMEFile(_ file: URL, schemeMap: inout [String:OrderedMap<String, String>], scriptMap: inout [String:OrderedMap<String, String>]) throws -> Array<String> {
        var imeRules = [String]()
        let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: CharacterSet.newlines)
        for line in lines {
            if line.isEmpty { continue }
            if kSchemeOverridePattern =~ line {
                let overrides = kSchemeOverridePattern.captured(match: 0, at: 0)!.components(separatedBy: ",").map({$0.trimmingCharacters(in: .whitespaces)})
                for override in overrides {
                    let overrideFile = schemeSubDirectory.appendingPathComponent(override).appendingPathExtension(kSchemeExtension)
                    try mapForTSVFile(file: overrideFile, map: &schemeMap)
                }
            }
            else if kScriptOverridePattern =~ line {
                let overrides = kScriptOverridePattern.captured(match: 0, at: 0)!.components(separatedBy: ",").map({$0.trimmingCharacters(in: .whitespaces)})
                for override in overrides {
                    let overrideFile = scriptSubDirectory.appendingPathComponent(override).appendingPathExtension(kScriptExtension)
                    try mapForTSVFile(file: overrideFile, map: &scriptMap)
                }
            }
            else if kImeOverridePattern =~ line {
                let overrides = kImeOverridePattern.captured(match: 0, at: 0)!.components(separatedBy: ",").map({$0.trimmingCharacters(in: .whitespaces)})
                for override in overrides {
                    let overrideFile = schemesDirectory.appendingPathComponent(override).appendingPathExtension(kImeExtension)
                    imeRules.append(contentsOf: try parseIMEFile(overrideFile, schemeMap: &schemeMap, scriptMap: &scriptMap))
                }
            }
            else {
                imeRules.append(line)
            }
        }
        return imeRules
    }
    
    func availableScripts() throws -> [String]? {
        return try filesInDirectory(directory: scriptSubDirectory, withExtension: kScriptExtension)
    }
    
    func availableSchemes() throws -> [String]? {
        return try filesInDirectory(directory: schemeSubDirectory, withExtension: kSchemeExtension)
    }
    
    func engine(schemeName: String, scriptName: String) throws -> Rules {
        let schemeFile = schemeSubDirectory.appendingPathComponent(schemeName).appendingPathExtension(kSchemeExtension)
        let scriptFile = scriptSubDirectory.appendingPathComponent(scriptName).appendingPathExtension(kScriptExtension)
        var schemeMap = [String:OrderedMap<String, String>]()
        try mapForTSVFile(file: schemeFile, map: &schemeMap)
        var scriptMap = [String:OrderedMap<String, String>]()
        try mapForTSVFile(file: scriptFile, map: &scriptMap)

        let imeFile = self.imeFile(schemeName: schemeName, scriptName: scriptName)
        let imeRules = try parseIMEFile(imeFile, schemeMap: &schemeMap, scriptMap: &scriptMap)
        
        // Generate common mappings with ordered keys
        var mappings = [String:OrderedMap<String, (String, String)>]()
        for type in scriptMap.keys {
            for key in scriptMap[type]!.keys {
                if schemeMap[type] == nil || schemeMap[type]![key] == nil { continue }
                if mappings[type] == nil {
                    mappings.updateValue(OrderedMap<String, (String, String)>(), forKey: type)
                }
                mappings[type]!.updateValue((schemeMap[type]![key]!, scriptMap[type]![key]!), forKey: key)
            }
        }
        return try Rules(imeRules: imeRules, scheme: Scheme(mappings: mappings))
    }
}
