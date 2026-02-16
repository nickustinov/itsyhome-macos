//
//  ActionParser.swift
//  macOSBridge
//
//  Parses string commands into Action + target
//

import Foundation

enum ActionParser {

    // MARK: - Result types

    struct ParsedCommand: Equatable {
        let target: String
        let action: Action
    }

    enum ParseError: Error, Equatable {
        case emptyCommand
        case unknownAction(String)
        case missingTarget
        case invalidValue(String)
    }

    // MARK: - Public API

    /// Parse a command string like:
    /// - "toggle light.bedroom"
    /// - "set brightness 50 bedroom light"
    /// - "turn on all lights"
    /// - "execute scene goodnight"
    /// - "on light.bedroom" (shorthand)
    /// - "off all lights" (shorthand)
    static func parse(_ command: String) -> Result<ParsedCommand, ParseError> {
        let trimmed = command.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else {
            return .failure(.emptyCommand)
        }

        let tokens = trimmed.split(separator: " ").map(String.init)
        guard !tokens.isEmpty else {
            return .failure(.emptyCommand)
        }

        return parseTokens(tokens)
    }

    // MARK: - Token parsing

    private static func parseTokens(_ tokens: [String]) -> Result<ParsedCommand, ParseError> {
        guard let firstToken = tokens.first else {
            return .failure(.emptyCommand)
        }

        switch firstToken {
        case "toggle":
            return parseSimpleAction(tokens: tokens, action: .toggle)

        case "on":
            return parseSimpleAction(tokens: tokens, action: .turnOn)

        case "off":
            return parseSimpleAction(tokens: tokens, action: .turnOff)

        case "turn":
            return parseTurnCommand(tokens: tokens)

        case "set":
            return parseSetCommand(tokens: tokens)

        case "execute", "run", "activate":
            return parseSceneCommand(tokens: tokens)

        case "lock":
            return parseSimpleAction(tokens: tokens, action: .lock)

        case "unlock":
            return parseSimpleAction(tokens: tokens, action: .unlock)

        case "open":
            return parseSimpleAction(tokens: tokens, action: .setPosition(100))

        case "close":
            return parseSimpleAction(tokens: tokens, action: .setPosition(0))

        default:
            // Try interpreting as target with implicit toggle
            let target = tokens.joined(separator: " ")
            return .success(ParsedCommand(target: target, action: .toggle))
        }
    }

    private static func parseSimpleAction(tokens: [String], action: Action) -> Result<ParsedCommand, ParseError> {
        guard tokens.count > 1 else {
            return .failure(.missingTarget)
        }
        let target = tokens.dropFirst().joined(separator: " ")
        return .success(ParsedCommand(target: target, action: action))
    }

    private static func parseTurnCommand(tokens: [String]) -> Result<ParsedCommand, ParseError> {
        // "turn on light.bedroom" or "turn off all lights"
        guard tokens.count >= 3 else {
            return .failure(.missingTarget)
        }

        let onOff = tokens[1]
        let target = tokens.dropFirst(2).joined(separator: " ")

        switch onOff {
        case "on":
            return .success(ParsedCommand(target: target, action: .turnOn))
        case "off":
            return .success(ParsedCommand(target: target, action: .turnOff))
        default:
            return .failure(.unknownAction("turn \(onOff)"))
        }
    }

    private static func parseSetCommand(tokens: [String]) -> Result<ParsedCommand, ParseError> {
        // "set brightness 50 bedroom light"
        // "set position 75 living room blinds"
        // "set temperature 22 thermostat"
        // "set color 120 100 bedroom light" (hue saturation)
        // "set colortemp 300 bedroom light" (mired)
        // "set mode heat thermostat"
        guard tokens.count >= 3 else {
            return .failure(.missingTarget)
        }

        let property = tokens[1]

        switch property {
        case "brightness", "bright", "dim":
            return parseBrightnessCommand(tokens: tokens)

        case "position", "pos":
            return parsePositionCommand(tokens: tokens)

        case "temperature", "temp":
            return parseTemperatureCommand(tokens: tokens)

        case "color", "colour":
            return parseColorCommand(tokens: tokens)

        case "colortemp", "colourtemp", "ct":
            return parseColorTempCommand(tokens: tokens)

        case "mode":
            return parseModeCommand(tokens: tokens)

        case "speed":
            return parseSpeedCommand(tokens: tokens)

        default:
            return .failure(.unknownAction("set \(property)"))
        }
    }

    private static func parseBrightnessCommand(tokens: [String]) -> Result<ParsedCommand, ParseError> {
        // "set brightness 50 bedroom light"
        guard tokens.count >= 4 else {
            return .failure(.missingTarget)
        }

        guard let value = Int(tokens[2]), value >= 0, value <= 100 else {
            return .failure(.invalidValue(tokens[2]))
        }

        let target = tokens.dropFirst(3).joined(separator: " ")
        return .success(ParsedCommand(target: target, action: .setBrightness(value)))
    }

    private static func parsePositionCommand(tokens: [String]) -> Result<ParsedCommand, ParseError> {
        // "set position 75 living room blinds"
        guard tokens.count >= 4 else {
            return .failure(.missingTarget)
        }

        guard let value = Int(tokens[2]), value >= 0, value <= 100 else {
            return .failure(.invalidValue(tokens[2]))
        }

        let target = tokens.dropFirst(3).joined(separator: " ")
        return .success(ParsedCommand(target: target, action: .setPosition(value)))
    }

    private static func parseTemperatureCommand(tokens: [String]) -> Result<ParsedCommand, ParseError> {
        // "set temperature 22 thermostat"
        guard tokens.count >= 4 else {
            return .failure(.missingTarget)
        }

        guard let value = Double(tokens[2]) else {
            return .failure(.invalidValue(tokens[2]))
        }

        let target = tokens.dropFirst(3).joined(separator: " ")
        return .success(ParsedCommand(target: target, action: .setTargetTemp(value)))
    }

    private static func parseColorCommand(tokens: [String]) -> Result<ParsedCommand, ParseError> {
        // "set color 120 100 bedroom light" (hue saturation target)
        guard tokens.count >= 5 else {
            return .failure(.missingTarget)
        }

        guard let hue = Double(tokens[2]), hue >= 0, hue <= 360 else {
            return .failure(.invalidValue(tokens[2]))
        }

        guard let saturation = Double(tokens[3]), saturation >= 0, saturation <= 100 else {
            return .failure(.invalidValue(tokens[3]))
        }

        let target = tokens.dropFirst(4).joined(separator: " ")
        return .success(ParsedCommand(target: target, action: .setColor(hue: hue, saturation: saturation)))
    }

    private static func parseColorTempCommand(tokens: [String]) -> Result<ParsedCommand, ParseError> {
        // "set colortemp 300 bedroom light" (mired)
        guard tokens.count >= 4 else {
            return .failure(.missingTarget)
        }

        guard let value = Int(tokens[2]), value > 0 else {
            return .failure(.invalidValue(tokens[2]))
        }

        let target = tokens.dropFirst(3).joined(separator: " ")
        return .success(ParsedCommand(target: target, action: .setColorTemp(mired: value)))
    }

    private static func parseModeCommand(tokens: [String]) -> Result<ParsedCommand, ParseError> {
        // "set mode heat thermostat"
        guard tokens.count >= 4 else {
            return .failure(.missingTarget)
        }

        let modeName = tokens[2]
        let mode: ThermostatMode

        switch modeName {
        case "off":
            mode = .off
        case "heat", "heating":
            mode = .heat
        case "cool", "cooling":
            mode = .cool
        case "auto", "automatic":
            mode = .auto
        default:
            return .failure(.invalidValue(modeName))
        }

        let target = tokens.dropFirst(3).joined(separator: " ")
        return .success(ParsedCommand(target: target, action: .setMode(mode)))
    }

    private static func parseSpeedCommand(tokens: [String]) -> Result<ParsedCommand, ParseError> {
        // "set speed 50 bedroom fan"
        guard tokens.count >= 4 else {
            return .failure(.missingTarget)
        }

        guard let value = Int(tokens[2]), value >= 0, value <= 100 else {
            return .failure(.invalidValue(tokens[2]))
        }

        let target = tokens.dropFirst(3).joined(separator: " ")
        return .success(ParsedCommand(target: target, action: .setSpeed(value)))
    }

    private static func parseSceneCommand(tokens: [String]) -> Result<ParsedCommand, ParseError> {
        // "execute scene goodnight" or "execute goodnight"
        // "run scene goodnight" or "run goodnight"
        guard tokens.count >= 2 else {
            return .failure(.missingTarget)
        }

        var targetTokens = Array(tokens.dropFirst())

        // Skip optional "scene" keyword
        if targetTokens.first == "scene" {
            targetTokens = Array(targetTokens.dropFirst())
        }

        guard !targetTokens.isEmpty else {
            return .failure(.missingTarget)
        }

        // Prepend "scene." to ensure scene resolution
        let sceneName = targetTokens.joined(separator: " ")
        let target = "scene.\(sceneName)"

        return .success(ParsedCommand(target: target, action: .executeScene))
    }
}
