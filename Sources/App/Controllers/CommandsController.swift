//
//  CommandsController.swift
//  SumDUBot
//
//  Created by Yura Voevodin on 04.03.17.
//
//

import Jobs
import HTTP
import Vapor
import Foundation

final class CommandsController {
    
    // MARK: - Properties
    
    let client: ClientFactoryProtocol
    let secret: String
    
    // MARK: - Initialization
    
    init(drop: Droplet) throws {
        // Client
        self.client = try drop.config.resolveClient()
        
        // Read the secret key from Config/secrets/app.json.
        guard let secret = drop.config["app", "secret"]?.string else {
            throw BotError.missingSecretKey
        }
        self.secret = secret
        
        // Add routes
        
        // Setting up the POST request with the secret key.
        // With a secret path to be sure that nobody else knows that URL.
        // https://core.telegram.org/bots/api#setwebhook
        drop.post(secret, handler: index)
    }
    
    // MARK: - Methods
    
    func index(request: Request) throws -> ResponseRepresentable {
        RequestsManager.shared.addRequest()
        
        let chatID = request.data["message", "chat", "id"]?.int ?? 0
        let chat = request.data["message", "chat"]?.object
        
        // Message text from request JSON
        let message = (request.data["message", "text"]?.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var responseText = "🙁 За вашим запитом нічого не знайдено, спробуйте інший"
        
        if let command = BotCommand(rawValue: message) {
            // Command
            Jobs.oneoff {
                // Register user request
                BotUser.registerRequest(for: chat)
                // Response
                if command == .test {
                    
                    let firstTestButton = InlineKeyboardButton(text: "Test 1", callbackData: "test_1")
                    let secondTestButton = InlineKeyboardButton(text: "Test 1", callbackData: "test_1")
                    let testKeyboard = InlineKeyboard(buttonsArray: [[firstTestButton, secondTestButton]])
                    
                    let uri = "https://api.telegram.org/bot\(self.secret)/sendMessage"
                    let request = Request(method: .post, uri: uri)
                    request.formURLEncoded = try Node(node: ["method": "sendMessage", "chat_id": Node(chatID), "reply_markup": testKeyboard.makeNode(in: nil)])
                    request.headers = ["Content-Type": "application/x-www-form-urlencoded"]
                    let _ = try self.client.respond(to: request)
                    
                } else if command == .history {
                    try self.sendResponse(chatID, text: HistoryRecord.history(for: chatID))
                } else {
                    try self.sendResponse(chatID, text: command.response)
                }
            }
        } else if message.hasPrefix(ObjectType.auditorium.prefix) {
            // Auditorium
            Jobs.oneoff {
                let result = try Auditorium.show(for: message, client: self.client, chat: chat)
                if result.isEmpty {
                    try self.sendResponse(chatID, text: responseText)
                } else {
                    for row in result  {
                        try self.sendResponse(chatID, text: row)
                    }
                }
            }
        } else if message.hasPrefix(ObjectType.group.prefix) {
            // Group
            Jobs.oneoff {
                let result = try Group.show(for: message, chat: chat, client: self.client)
                if result.isEmpty {
                    try self.sendResponse(chatID, text: responseText)
                } else {
                    for row in result  {
                        try self.sendResponse(chatID, text: row)
                    }
                }
            }
        } else if message.hasPrefix(ObjectType.teacher.prefix) {
            // Teacher
            Jobs.oneoff {
                let result = try Teacher.show(for: message, chat: chat, client: self.client)
                if result.isEmpty {
                    try self.sendResponse(chatID, text: responseText)
                } else {
                    for row in result  {
                        try self.sendResponse(chatID, text: row)
                    }
                }
            }
        } else {
            // Search
            Jobs.oneoff {
                if message.characters.count <= 3 {
                    responseText = "Мінімальна кількість символів для пошуку рівна 4"
                } else {
                    var searchResults = ""
                    searchResults += try Auditorium.find(by: message)
                    searchResults += try Group.find(by: message)
                    searchResults += try Teacher.find(by: message)
                    if !searchResults.isEmpty {
                        responseText = searchResults
                    }
                }
                // Register user request
                BotUser.registerRequest(for: chat)
                // Response
                try self.sendResponse(chatID, text: responseText)
            }
        }
        // Response with "typing"
        return try JSON(node: ["method": "sendChatAction", "chat_id": chatID, "action": "typing"])
    }
    
    fileprivate func sendResponse(_ chatID: Int, text: String) throws {
        let uri = "https://api.telegram.org/bot\(secret)/sendMessage"
        let request = Request(method: .post, uri: uri)
        request.formURLEncoded = try Node(node: ["method": "sendMessage", "chat_id": chatID, "text": text])
        request.headers = ["Content-Type": "application/x-www-form-urlencoded"]
        let _ = try client.respond(to: request)
    }
}

// MARK: - BotError

extension CommandsController {
    
    /// Bot errors
    enum BotError: Swift.Error {
        /// Missing secret key in Config/secrets/app.json.
        case missingSecretKey
    }
}
