import APNS
import APNSCore
import Foundation
import Vapor
import VaporAPNS

struct ForumPushMessage: Equatable, Sendable {
  let eventID: UUID
  let title: String
  let body: String
  let type: ForumNotificationType
  let topicID: UUID
  let commentID: UUID?
  let parentCommentID: UUID?

  init(event: ForumEventDTO) {
    self.eventID = event.eventID
    self.title = "Homero"
    self.body = switch event.type {
    case .topicLiked:
      "\(event.actor.name) curtiu seu topico"
    case .topicCommented:
      "\(event.actor.name) respondeu seu topico"
    case .commentReplied:
      "\(event.actor.name) respondeu um comentario no seu topico"
    case .commentLiked:
      ""
    }
    self.type = event.type
    self.topicID = event.target.topicID
    self.commentID = event.target.commentID
    self.parentCommentID = event.target.parentCommentID
  }

  func apnsNotification(topic: String) -> APNSAlertNotification<ForumPushPayload> {
    APNSAlertNotification(
      alert: .init(
        title: .raw(title),
        body: .raw(body)
      ),
      expiration: .immediately,
      priority: .immediately,
      topic: topic,
      payload: ForumPushPayload(
        type: type,
        topicID: topicID.uuidString.lowercased(),
        commentID: commentID?.uuidString.lowercased(),
        parentCommentID: parentCommentID?.uuidString.lowercased()
      ),
      sound: .default,
      apnsID: eventID
    )
  }
}

struct ForumPushPayload: Codable, Equatable, Sendable {
  let type: ForumNotificationType
  let topicID: String
  let commentID: String?
  let parentCommentID: String?

  enum CodingKeys: String, CodingKey {
    case type
    case topicID = "topicId"
    case commentID = "commentId"
    case parentCommentID = "parentCommentId"
  }
}

struct ForumPushDeliveryReceipt: Equatable, Sendable {
  let apnsID: UUID?
  let apnsUniqueID: UUID?
}

protocol ForumPushSending: Sendable {
  func send(
    _ message: ForumPushMessage,
    to deviceToken: String,
    on request: Request
  ) async throws -> ForumPushDeliveryReceipt
}

struct APNSForumPushSender: ForumPushSending {
  let bundleID: String

  func send(
    _ message: ForumPushMessage,
    to deviceToken: String,
    on request: Request
  ) async throws -> ForumPushDeliveryReceipt {
    let client = await request.apns.client
    let response = try await client.sendAlertNotification(
      message.apnsNotification(topic: bundleID),
      deviceToken: deviceToken
    )

    return ForumPushDeliveryReceipt(
      apnsID: response.apnsID,
      apnsUniqueID: response.apnsUniqueID
    )
  }
}

enum ForumPushSenderError: Error {
  case notConfigured
}

struct UnconfiguredForumPushSender: ForumPushSending {
  func send(
    _ message: ForumPushMessage,
    to deviceToken: String,
    on request: Request
  ) async throws -> ForumPushDeliveryReceipt {
    throw ForumPushSenderError.notConfigured
  }
}

private struct ForumPushSenderKey: StorageKey {
  typealias Value = any ForumPushSending
}

extension Application {
  var forumPushSender: any ForumPushSending {
    get {
      storage[ForumPushSenderKey.self] ?? UnconfiguredForumPushSender()
    }
    set {
      storage[ForumPushSenderKey.self] = newValue
    }
  }
}
