import Foundation

/// What the `wifiorisp` command was asked to do.
public enum CLICommand: Equatable, Sendable {
    public enum HistoryFormat: Equatable, Sendable {
        case text, json, csv
    }

    case help
    case version
    /// Asks the running app.
    case app(CLIRequest.Action, json: Bool)
    /// Read straight from the log on disk.
    case history(since: TimeInterval, format: HistoryFormat)
    case report(since: TimeInterval)
}

public struct CLIArgumentError: Error, Equatable {
    public var message: String
}

public enum CLIArguments {
    public static let defaultHistory: TimeInterval = 86_400
    public static let defaultReport: TimeInterval = 7 * 86_400

    public static func parse(_ arguments: [String]) throws -> CLICommand {
        guard let first = arguments.first else { return .help }
        var options = Array(arguments.dropFirst())
        let command: CLICommand
        switch first {
        case "help", "-h", "--help":
            return .help
        case "version", "--version":
            return .version
        case "status", "watch", "speed", "lag":
            let json = take("--json", from: &options)
            command = .app(CLIRequest.Action(rawValue: first)!, json: json)
        case "history":
            let since = try takeDuration(from: &options) ?? defaultHistory
            let json = take("--json", from: &options)
            let csv = take("--csv", from: &options)
            if json && csv { throw CLIArgumentError(message: "Use --json or --csv, not both.") }
            command = .history(since: since, format: json ? .json : (csv ? .csv : .text))
        case "report":
            command = .report(since: try takeDuration(from: &options) ?? defaultReport)
        default:
            throw CLIArgumentError(message: "Unknown command: \(first)")
        }
        if let extra = options.first {
            throw CLIArgumentError(message: "Unknown option for \(first): \(extra)")
        }
        return command
    }

    private static func take(_ flag: String, from options: inout [String]) -> Bool {
        guard let index = options.firstIndex(of: flag) else { return false }
        options.remove(at: index)
        return true
    }

    private static func takeDuration(from options: inout [String]) throws -> TimeInterval? {
        guard let index = options.firstIndex(of: "--since") else { return nil }
        guard index + 1 < options.count else { throw CLIArgumentError(message: "--since needs a duration, like 24h.") }
        let value = options[index + 1]
        options.removeSubrange(index...index + 1)
        guard let duration = duration(value) else {
            throw CLIArgumentError(message: "Couldn't read \"\(value)\" as a duration. Try 30m, 24h, or 7d.")
        }
        return duration
    }

    /// "90m", "24h", "7d", or combinations like "1h30m".
    public static func duration(_ text: String) -> TimeInterval? {
        let units: [Character: TimeInterval] = ["m": 60, "h": 3600, "d": 86_400]
        var total: TimeInterval = 0
        var number = ""
        for character in text.lowercased() {
            if character.isNumber {
                number.append(character)
            } else if let unit = units[character], let value = Double(number) {
                total += value * unit
                number = ""
            } else {
                return nil
            }
        }
        return number.isEmpty && total > 0 ? total : nil
    }
}
