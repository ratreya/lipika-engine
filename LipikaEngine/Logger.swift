/*
 * LipikaIME is a user-configurable phonetic Input Method Engine for Mac OS X.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import Foundation

enum LoggerError: Error {
    case alreadyCapturing
}

class Logger {
    var capture: Array<String>?
    
    enum Level: String {
        case Debug = "Debug"
        case Warning = "Warning"
        case Error = "Error"
        case Fatal = "Fatal"
    }
    
    func log(level: Level, message: String) {
        let log = "[\(level.rawValue)] \(message)"
        NSLog(log)
        if var capture = self.capture {
            capture.append(log)
        }
    }
    
    func startCapture(_ store: inout Array<String>) throws {
        if capture != nil {
            throw LoggerError.alreadyCapturing
        }
        capture = store
    }
    
    func endCapture() -> Array<String>? {
        return capture
    }
}
