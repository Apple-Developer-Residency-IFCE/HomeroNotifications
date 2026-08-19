import Foundation

enum ForumNotificationType: String, Codable, CaseIterable, Sendable {
  case topicLiked = "TOPIC_LIKED"
  case topicCommented = "TOPIC_COMMENTED"
  case commentReplied = "COMMENT_REPLIED"
  case commentLiked = "COMMENT_LIKED"
}

struct ForumNotificationActor: Codable, Equatable, Sendable {
  /// The Homero User ID represented by `authorUser.id`.
  let userID: UUID
  let name: String
  let avatarURL: URL?
}

struct ForumNotificationTarget: Codable, Equatable, Sendable {
  let courseID: UUID
  let topicID: UUID
  let topicTitle: String

  /// The comment that was created, replied to, or liked.
  let commentID: UUID?

  /// The original comment when this target represents a reply.
  let parentCommentID: UUID?
}

struct ForumNotification: Codable, Equatable, Identifiable, Sendable {
  let id: UUID
  let organizationID: UUID
  let recipientUserID: UUID
  let type: ForumNotificationType
  let actor: ForumNotificationActor
  let target: ForumNotificationTarget
  let createdAt: Date

  private(set) var readAt: Date?

  var isRead: Bool {
    readAt != nil
  }

  init(
    id: UUID = UUID(),
    organizationID: UUID,
    recipientUserID: UUID,
    type: ForumNotificationType,
    actor: ForumNotificationActor,
    target: ForumNotificationTarget,
    createdAt: Date = .now,
    readAt: Date? = nil
  ) {
    self.id = id
    self.organizationID = organizationID
    self.recipientUserID = recipientUserID
    self.type = type
    self.actor = actor
    self.target = target
    self.createdAt = createdAt
    self.readAt = readAt
  }

  mutating func markAsRead(at date: Date = .now) {
    guard readAt == nil else {
      return
    }

    readAt = date
  }
}
