import Foundation
import Testing

@testable import HomeroNotifications

@Suite("Forum Notification Tests")
struct ForumNotificationTests {
  @Test("A new notification starts unread")
  func newNotificationStartsUnread() {
    let notification = makeNotification()

    #expect(notification.readAt == nil)
    #expect(notification.isRead == false)
  }

  @Test("Marking a notification as read is idempotent")
  func markAsReadIsIdempotent() {
    let firstReadAt = Date(timeIntervalSince1970: 1_700_000_000)
    let secondReadAt = Date(timeIntervalSince1970: 1_800_000_000)
    var notification = makeNotification()

    notification.markAsRead(at: firstReadAt)
    notification.markAsRead(at: secondReadAt)

    #expect(notification.isRead)
    #expect(notification.readAt == firstReadAt)
  }

  @Test("A notification supports a Codable round trip")
  func codableRoundTrip() throws {
    let notification = makeNotification()
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let encoded = try encoder.encode(notification)
    let decoded = try decoder.decode(ForumNotification.self, from: encoded)

    #expect(decoded == notification)
  }

  private func makeNotification() -> ForumNotification {
    ForumNotification(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
      organizationID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
      recipientUserID: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
      type: .commentReplied,
      actor: ForumNotificationActor(
        userID: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        name: "João",
        avatarURL: URL(string: "https://example.com/avatar.jpg")
      ),
      target: ForumNotificationTarget(
        courseID: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
        topicID: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
        topicTitle: "Forum topic",
        commentID: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!,
        parentCommentID: UUID(uuidString: "00000000-0000-0000-0000-000000000008")!
      ),
      createdAt: Date(timeIntervalSince1970: 1_600_000_000)
    )
  }
}
