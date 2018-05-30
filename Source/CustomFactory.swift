/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2018 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import Foundation

class CustomFactory {
    struct CustomMapping {
        fileprivate var name: String?
        fileprivate var version: Double?
        fileprivate var stopChar: UnicodeScalar = "\\"
        fileprivate var usingClasses = false
        fileprivate var classStart: Character = "{"
        fileprivate var classEnd: Character = "}"
        fileprivate var wildcard: Character = "*"
        fileprivate var trie = Trie<[UnicodeScalar], String>()
    }

    private let kCustomExtension = "scm"
    private let kName = "name";
    private let kVersion = "version";
    private let kStopChar = "stop-char";
    private let kClassDelimiters = "class-delimiters";
    private let kWildcard = "wildcard";
    
    private let mappingDirectory: URL
    private let headerPattern: RegEx
    private let usingClassesPattern: RegEx
    private let classesDelimiterPattern: RegEx
    private let simpleMappingPattern: RegEx
    private var classDefinitionPattern: RegEx?
    private var classKeyPattern: RegEx?
    private var wildcardValuePattern: RegEx?
    
    private var currentClass: String?
    // Class Name -> Key -> Value
    private var classes = [String: [String: String]]()
    private var customMapping = CustomMapping()

    init(mappingDirectory: URL) throws {
        headerPattern = try RegEx(pattern: "^\\s*(.*\\S)\\s*:\\s*(.*\\S)\\s*$")
        usingClassesPattern = try RegEx(pattern: "^\\s*using\\s+classes\\s*$")
        classesDelimiterPattern = try RegEx(pattern: "^\\s*(\\S)\\s*(\\S)\\s*$")
        simpleMappingPattern = try RegEx(pattern: "^\\s*(\\S+)\\s+(\\S+)\\s*$")
        self.mappingDirectory = mappingDirectory
    }
    
    func availableCustomMappings() throws -> [String] {
        guard FileManager.default.fileExists(atPath: mappingDirectory.path) else {
            return []
        }
        do {
            return try filesInDirectory(directory: mappingDirectory, withExtension: kCustomExtension)
        }
        catch {
            throw EngineError.ioError(error.localizedDescription)
        }
    }
    
    private func parseHeaders(line: String, index: Int) throws -> Bool {
        if headerPattern =~ line {
            let key = headerPattern.captured(capture: 1)!
            let value = headerPattern.captured(capture: 2)!
            switch key.lowercased() {
            case kVersion:
                guard let version = Double(value) else {
                    throw EngineError.parseError("version has to be a double at line \(index)")
                }
                customMapping.version = version
            case kName:
                guard !value.isEmpty else {
                    throw EngineError.parseError("name has to be a non-empty string")
                }
                customMapping.name = value
            case kStopChar:
                guard value.unicodeScalars.count == 1 else {
                    throw EngineError.parseError("stop-char needs to have a single unicode scalar at line \(index)")
                }
                customMapping.stopChar = value.unicodeScalars.first!
            case kWildcard:
                guard value.count == 1 else {
                    throw EngineError.parseError("wildcard needs to be a single character at line \(index)")
                }
                customMapping.wildcard = value.first!
            case kClassDelimiters:
                guard classesDelimiterPattern =~ value, let startChar = classesDelimiterPattern.captured(capture: 1), startChar.count == 1, let endChar = classesDelimiterPattern.captured(capture: 2), endChar.count == 1 else {
                    throw EngineError.parseError("Invalid class delimiter values: \(value) at line \(index)")
                }
                customMapping.classStart = startChar.first!
                customMapping.classEnd = endChar.first!
            default:
                throw EngineError.parseError("Invalid header key: \(key) at line \(index)")
            }
        }
        else if usingClassesPattern =~ line {
            customMapping.usingClasses = true
        }
        else {
            classDefinitionPattern = try RegEx(pattern: "^\\s*class\\s+(\\S+)\\s+\\\(customMapping.classStart)\\s*$")
            classKeyPattern = try RegEx(pattern: "^\\s*(\\S*)\\\(customMapping.classStart)(\\S+)\\\(customMapping.classEnd)(\\S*)\\s*$")
            wildcardValuePattern = try RegEx(pattern: "^\\s*(\\S*)\\\(customMapping.wildcard)(\\S*)\\s*$")
            return true
        }
        return false
    }
    
    private func parseMapping(line: String, index: Int, isReverse: Bool) throws {
        if simpleMappingPattern =~ line {
            guard let input = simpleMappingPattern.captured(capture: 1), let output = simpleMappingPattern.captured(capture: 2) else {
                throw EngineError.parseError("Simple mapping at line \(index) is missing input or output: \(line)")
            }
            if classKeyPattern! =~ input {
                let preClass = classKeyPattern!.captured(capture: 1) ?? ""
                let postClass = classKeyPattern!.captured(capture: 3) ?? ""
                guard let className = classKeyPattern!.captured(capture: 2) else {
                    throw EngineError.parseError("Class key mapping at line \(index) is malformed: \(line)")
                }
                guard customMapping.usingClasses else {
                    throw EngineError.parseError("Header does not specify using classes but class: \(className) encountered at line: \(index)")
                }
                guard className != currentClass else {
                    throw EngineError.parseError("Attempting to use class: \(className) before its definition was closed at line: \(index)")
                }
                guard let classMap = classes[className] else {
                    throw EngineError.parseError("Class name: \(className) is undefined at line: \(index)")
                }
                if wildcardValuePattern! =~ output {
                    let preWildcard = wildcardValuePattern!.captured(capture: 1) ?? ""
                    let postWildcard = wildcardValuePattern!.captured(capture: 2) ?? ""
                    classMap.forEach() {
                        if isReverse {
                            customMapping.trie["\(preWildcard)\($0.value)\(postWildcard)".unicodeScalars.reversed()] = "\(preClass)\($0.key)\(postClass)".unicodeScalarReversed()
                        }
                        else {
                            customMapping.trie["\(preClass)\($0.key)\(postClass)".unicodeScalars()] = "\(preWildcard)\($0.value)\(postWildcard)"
                        }
                    }
                }
                else {
                    classMap.keys.forEach() {
                        if isReverse {
                            customMapping.trie[output.unicodeScalars.reversed()] = "\(preClass)\($0)\(postClass)".unicodeScalarReversed()
                        }
                        else {
                            customMapping.trie["\(preClass)\($0)\(postClass)".unicodeScalars()] = output
                        }
                    }
                }
            }
            else {
                if let currentClass = currentClass {
                    classes[currentClass, default: [String: String]()][input] = output
                }
                else {
                    if isReverse {
                        customMapping.trie[output.unicodeScalars.reversed()] = input
                    }
                    else {
                        customMapping.trie[input.unicodeScalars()] = output
                    }
                }
            }
        }
        else if classDefinitionPattern! =~ line {
            guard let className = classDefinitionPattern?.captured(capture: 1) else {
                throw EngineError.parseError("Class definition at line \(index) is invalid: \(line)")
            }
            guard customMapping.usingClasses else {
                throw EngineError.parseError("Header does not specify using classes but class: \(className) encountered at line: \(index)")
            }
            guard currentClass == nil else {
                throw EngineError.parseError("Class definition for class: \(currentClass!) not closed but new definition for class: \(className) opened at line \(index)")
            }
            currentClass = className
        }
        else if line.count == 1 && line.first! == customMapping.classEnd {
            guard currentClass != nil else {
                throw EngineError.parseError("Closing a class definition that was never opened at line: \(index)")
            }
            guard customMapping.usingClasses else {
                throw EngineError.parseError("Header does not specify using classes but class close encountered at line: \(index)")
            }
            currentClass = nil
        }
        else {
            throw EngineError.parseError("Malformed mapping at line \(index): \(line)")
        }
    }
    
    func customEngine(customMapping customMappingName: String, isReverse: Bool = false) throws -> CustomEngine {
        let fileURL = mappingDirectory.appendingPathComponent(customMappingName).appendingPathExtension(kCustomExtension)
        var lines: [String]
        do {
            lines = try String(contentsOf: fileURL, encoding: .utf8).components(separatedBy: .newlines)
        }
        catch {
            throw EngineError.ioError(error.localizedDescription)
        }
        var doneParsingHeaders = false
        for (index, line) in lines.enumerated() {
            if line.isEmpty || line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            if !doneParsingHeaders {
                doneParsingHeaders = try parseHeaders(line: line, index: index)
            }
            if doneParsingHeaders {
                try parseMapping(line: line, index: index, isReverse: isReverse)
            }
        }
        return CustomEngine(trie: customMapping.trie)
    }
}
