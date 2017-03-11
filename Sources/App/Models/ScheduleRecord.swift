//
//  ScheduleRecord.swift
//  SumDUBot
//
//  Created by Yura Voevodin on 25.02.17.
//
//

import Vapor
import HTTP
import Fluent
import Foundation

final class ScheduleRecord: Model {

    // MARK: Properties

    var id: Node?
    var exists: Bool = false

    var objectID: Node?

    var auditorium: String
    var date: String
    var teacher: String
    var name: String?
    var type: String?

    // MARK: - Initialization

    init(node: Node, in context: Context) throws {
        id = try node.extract("id")

        // Properties
        auditorium = try node.extract("auditorium")
        date = try node.extract("date")
        teacher = try node.extract("teacher")
        name = try node.extract("name")
        type = try node.extract("type")

        // Relationships
        objectID = try node.extract("object_id")
    }

    func makeNode(context: Context) throws -> Node {
        return try Node(node: [
            "id": id,
            "auditorium": auditorium,
            "date": date,
            "teacher": teacher,
            "name": name,
            "type": type,
            "object_id": objectID
            ])
    }

    init?(_ object: [String: Polymorphic]) {
        guard let auditorium = object["NAME_AUD"]?.string else {
            return nil
        }
        self.auditorium = auditorium

        guard let date = object["DATE_REG"]?.string else {
            return nil
        }
        self.date = date

        guard let teacher = object["NAME_FIO"]?.string else {
            return nil
        }
        self.teacher = teacher

        self.name = object["ABBR_DIS"]?.string
        self.type = object["NAME_STUD"]?.string
    }
}

// MARK: - Relationships

extension ScheduleRecord {
    func object() throws -> Parent<Object> {
        return try parent(objectID)
    }
}

// MARK: - Preparation

extension ScheduleRecord: Preparation {
    static func prepare(_ database: Database) throws {
        try database.create(entity, closure: { record in
            record.id()
            record.string("auditorium")
            record.string("date")
            record.string("teacher")
            record.string("name", optional: true)
            record.string("type", optional: true)
            record.parent(Object.self, optional: false)
        })
    }

    static func revert(_ database: Database) throws {
        try database.delete(entity)
    }
}

// MARK: - Helpers

extension ScheduleRecord {

    static func findSchedule(by id: Int) throws -> String {
        let currentDate = Date().dateWithTimeFormat

        // Try to find object in database
        guard var object = try Object.find(id) else { throw  ScheduleImportManager.ImportError.missingObject }

        if object.updatedAt != currentDate {
            // Try to import schedule
            try ScheduleImportManager.importSchedule(for: object)

            // Update date in object
            object.updatedAt = currentDate
            try object.save()
        }

        let newLine = "\n"
        let twoLines = "\n\n"
        var schedule = ""
        var dateString = ""

        let records = try ScheduleRecord.query().filter("object_id", .equals, id).all()

        // Name of object
        if let name = records.first?.name {
            schedule = newLine + name + twoLines
        }

        for record in records {
            guard record.auditorium.characters.count > 0 && record.teacher.characters.count > 0 else { continue }

            // Day of week
            if record.date != dateString {
                dateString = record.date
                if let recordDate = Date.serverDate(from: dateString)?.humanReadable {
                    schedule += newLine + recordDate + twoLines
                }
            }

            // Compound record
            if let name = record.name {
                schedule += name + newLine
            }
            if let type = record.type {
                schedule += type + newLine
            }
            schedule += record.auditorium + " - " + record.teacher + newLine
        }
        return schedule
    }
}
