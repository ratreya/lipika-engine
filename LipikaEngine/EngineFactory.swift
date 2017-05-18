/*
 * LipikaIME is a user-configurable phonetic Input Method Engine for Mac OS X.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import Foundation

enum SchemeFactoryError: Error {
    case ioError(String)
    case parseError(String)
}

class EngineFactory {
    let logger = Logger()
    let schemesDirectory: URL
    let schemeSubDirectory: URL
    let scriptSubDirectory: URL

    let kSchemeExtension = "tlr"
    let kScriptExtension = "lng"
    let kImeExtension = "ime"
    let kThreeColumnTSVPattern: NSRegularExpression
    let kScriptOverridePattern: NSRegularExpression
    let kSchemeOverridePattern: NSRegularExpression
    let kImeOverridePattern: NSRegularExpression

    init(schemesDirectory: URL) throws {
        self.schemesDirectory = schemesDirectory
        if !FileManager.default.fileExists(atPath: schemesDirectory.path) {
            throw SchemeFactoryError.ioError("Invalid schemesDirectory: \(schemesDirectory)")
        }
        self.schemeSubDirectory = schemesDirectory.appendingPathComponent("Transliteration")
        self.scriptSubDirectory = schemesDirectory.appendingPathComponent("Script")
        kThreeColumnTSVPattern = try NSRegularExpression(pattern: "^\\s*([^\\t]+?)\\t+([^\\t]+?)\\t+(.*)\\s*$", options: [])
        kScriptOverridePattern = try NSRegularExpression(pattern: "^\\s*Script\\s*:\\s*(.+)\\s*$", options: [])
        kSchemeOverridePattern = try NSRegularExpression(pattern: "^\\s*Transliteration\\s*:\\s*(.+)\\s*$", options: [])
        kImeOverridePattern = try NSRegularExpression(pattern: "^\\s*IME\\s*:\\s*(.+)\\s*$", options: [])
    }
    
    private func filesInDirectory(directory: URL, withExtension ext: String) throws -> [String]? {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [], options: [])
            return files.filter({$0.pathExtension == ext}).flatMap({($0.lastPathComponent as NSString).deletingPathExtension})
        }
        catch let error {
            throw SchemeFactoryError.ioError(error.localizedDescription)
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
            let components = line.components(separatedBy: "\t")
            if components.count != 3 {
                throw SchemeFactoryError.parseError("Unable to parse line: \(line) in file: \(file.path)")
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
            let fullRange = NSRange(location: 0, length: line.lengthOfBytes(using: .utf8))
            if kSchemeOverridePattern.numberOfMatches(in: line, options: [], range: fullRange) > 0 {
                let overrides = kSchemeOverridePattern.stringByReplacingMatches(in: line, options: [], range: fullRange, withTemplate: "$1").components(separatedBy: ",").map({$0.trimmingCharacters(in: .whitespaces)})
                for override in overrides {
                    let overrideFile = schemeSubDirectory.appendingPathComponent(override).appendingPathExtension(kSchemeExtension)
                    try mapForTSVFile(file: overrideFile, map: &schemeMap)
                }
            }
            else if kScriptOverridePattern.numberOfMatches(in: line, options: [], range: fullRange) > 0 {
                let overrides = kScriptOverridePattern.stringByReplacingMatches(in: line, options: [], range: fullRange, withTemplate: "$1").components(separatedBy: ",").map({$0.trimmingCharacters(in: .whitespaces)})
                for override in overrides {
                    let overrideFile = scriptSubDirectory.appendingPathComponent(override).appendingPathExtension(kScriptExtension)
                    try mapForTSVFile(file: overrideFile, map: &scriptMap)
                }
            }
            else if kImeOverridePattern.numberOfMatches(in: line, options: [], range: fullRange) > 0 {
                let overrides = kImeOverridePattern.stringByReplacingMatches(in: line, options: [], range: fullRange, withTemplate: "$1").components(separatedBy: ",").map({$0.trimmingCharacters(in: .whitespaces)})
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
    
    func engine(schemeName: String, scriptName: String) throws -> Engine {
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
        return Engine(imeRules: imeRules, scheme: Scheme(mappings: mappings))
    }
}
