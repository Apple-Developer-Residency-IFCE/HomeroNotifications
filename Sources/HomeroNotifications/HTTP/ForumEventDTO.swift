import Foundation
import Vapor

struct ForumEventDTO: Content, Equatable, Sendable {
  struct Actor: Codable, Equatable, Sendable {
    let userID: UUID
    let name: String

    enum CodingKeys: String, CodingKey {
      case userID = "userId"
      case name
    }
  }

  struct Recipient: Codable, Equatable, Sendable {
    let userID: UUID

    enum CodingKeys: String, CodingKey {
      case userID = "userId"
    }
  }

  struct Target: Codable, Equatable, Sendable {
    let topicID: UUID
    let topicTitle: String

    enum CodingKeys: String, CodingKey {
      case topicID = "topicId"
      case topicTitle
    }
  }

  let eventID: UUID
  let type: ForumNotificationType
  let occurredAt: Date
  let actor: Actor
  let recipient: Recipient
  let target: Target

  enum CodingKeys: String, CodingKey {
    case eventID = "eventId"
    case type
    case occurredAt
    case actor
    case recipient
    case target
  }

  func validate() throws {
    guard !actor.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw Abort(.badRequest, reason: "actor.name must not be empty")
    }

    guard !target.topicTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw Abort(.badRequest, reason: "target.topicTitle must not be empty")
    }
  }
}
