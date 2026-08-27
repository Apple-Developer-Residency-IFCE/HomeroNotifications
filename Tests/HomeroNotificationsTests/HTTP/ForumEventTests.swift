import Fluent
import Foundation
import Testing
import Vapor
import VaporTesting

@testable import HomeroNotifications

@Suite("Forum event endpoint tests")
struct ForumEventTests {
  @Test("A valid TOPIC_LIKED event is mapped and sent")
  func validTopicLikedEventIsSent() async throws {
    let sender = RecordingForumPushSender()

    try await withApp(configure: configure) { app in
      app.forumPushSender = sender
      try await registerDevice(on: app.db)

      try await app.testing().test(.POST, "/events/forum") { request in
        setJSONBody(eventJSON(), on: &request)
      } afterResponse: { response in
        #expect(response.status == .accepted)
      }

      let sends = await sender.recordedSends()
      let send = try #require(sends.first)
      #expect(sends.count == 1)
      #expect(send.deviceToken == defaultDeviceToken)
      #expect(send.message.eventID == eventID)
      #expect(send.message.title == "Homero")
      #expect(send.message.body == "Kaique curtiu seu topico")
      #expect(send.message.type == .topicLiked)
      #expect(send.message.topicID == topicID)
    }
  }

  @Test("A valid TOPIC_COMMENTED event is mapped and sent")
  func validTopicCommentedEventIsSent() async throws {
    let sender = RecordingForumPushSender()

    try await withApp(configure: configure) { app in
      app.forumPushSender = sender
      try await registerDevice(on: app.db)

      try await app.testing().test(.POST, "/events/forum") { request in
        setJSONBody(eventJSON(type: "TOPIC_COMMENTED"), on: &request)
      } afterResponse: { response in
        #expect(response.status == .accepted)
      }

      let send = try #require(await sender.recordedSends().first)
      #expect(send.message.body == "Kaique respondeu seu topico")
      #expect(send.message.type == .topicCommented)
      #expect(send.message.topicID == topicID)
    }
  }

  @Test("A valid COMMENT_REPLIED event is mapped and sent")
  func validCommentRepliedEventIsSent() async throws {
    let sender = RecordingForumPushSender()

    try await withApp(configure: configure) { app in
      app.forumPushSender = sender
      try await registerDevice(on: app.db)

      try await app.testing().test(.POST, "/events/forum") { request in
        setJSONBody(
          eventJSON(
            type: "COMMENT_REPLIED",
            commentID: commentID,
            parentCommentID: parentCommentID
          ),
          on: &request
        )
      } afterResponse: { response in
        #expect(response.status == .accepted)
      }

      let send = try #require(await sender.recordedSends().first)
      #expect(send.message.body == "Kaique respondeu um comentario no seu topico")
      #expect(send.message.type == .commentReplied)
      #expect(send.message.commentID == commentID)
      #expect(send.message.parentCommentID == parentCommentID)
    }
  }

  @Test("COMMENT_REPLIED requires the original comment identifier")
  func commentRepliedRequiresParentCommentID() async throws {
    let sender = RecordingForumPushSender()

    try await withApp(configure: configure) { app in
      app.forumPushSender = sender
      try await registerDevice(on: app.db)

      try await app.testing().test(.POST, "/events/forum") { request in
        setJSONBody(eventJSON(type: "COMMENT_REPLIED"), on: &request)
      } afterResponse: { response in
        #expect(response.status == .badRequest)
      }

      #expect(await sender.recordedSends().isEmpty)
    }
  }

  @Test("An event is sent to every registered device belonging to the recipient")
  func eventIsSentToEveryRecipientDevice() async throws {
    let sender = RecordingForumPushSender()

    try await withApp(configure: configure) { app in
      app.forumPushSender = sender
      try await registerDevice(on: app.db)
      try await registerDevice(on: app.db, deviceToken: secondDeviceToken)

      try await app.testing().test(.POST, "/events/forum") { request in
        setJSONBody(eventJSON(), on: &request)
      } afterResponse: { response in
        #expect(response.status == .accepted)
      }

      let sends = await sender.recordedSends()
      #expect(Set(sends.map(\.deviceToken)) == Set([defaultDeviceToken, secondDeviceToken]))
    }
  }

  @Test("A partial APNs failure is accepted when another device succeeds")
  func partialDeliveryIsAccepted() async throws {
    let sender = RecordingForumPushSender(failingDeviceTokens: [defaultDeviceToken])

    try await withApp(configure: configure) { app in
      app.forumPushSender = sender
      try await registerDevice(on: app.db)
      try await registerDevice(on: app.db, deviceToken: secondDeviceToken)

      try await app.testing().test(.POST, "/events/forum") { request in
        setJSONBody(eventJSON(), on: &request)
      } afterResponse: { response in
        #expect(response.status == .accepted)
      }

      let sends = await sender.recordedSends()
      #expect(sends.count == 2)
    }
  }

  @Test("An event for a recipient without devices is ignored")
  func recipientWithoutDevicesIsIgnored() async throws {
    let sender = RecordingForumPushSender()

    try await withApp(configure: configure) { app in
      app.forumPushSender = sender

      try await app.testing().test(.POST, "/events/forum") { request in
        setJSONBody(eventJSON(), on: &request)
      } afterResponse: { response in
        #expect(response.status == .noContent)
      }

      let sends = await sender.recordedSends()
      #expect(sends.isEmpty)
    }
  }

  @Test("An event whose actor is the recipient is ignored")
  func selfAuthoredEventIsIgnored() async throws {
    let sender = RecordingForumPushSender()

    try await withApp(configure: configure) { app in
      app.forumPushSender = sender

      try await app.testing().test(.POST, "/events/forum") { request in
        setJSONBody(eventJSON(recipientUserID: actorUserID), on: &request)
      } afterResponse: { response in
        #expect(response.status == .noContent)
      }

      let sends = await sender.recordedSends()
      #expect(sends.isEmpty)
    }
  }

  @Test("A known but unsupported event type returns 422 without sending")
  func unsupportedEventIsRejected() async throws {
    let sender = RecordingForumPushSender()

    try await withApp(configure: configure) { app in
      app.forumPushSender = sender

      try await app.testing().test(.POST, "/events/forum") { request in
        setJSONBody(eventJSON(type: "COMMENT_LIKED"), on: &request)
      } afterResponse: { response in
        #expect(response.status == .unprocessableEntity)
      }

      let sends = await sender.recordedSends()
      #expect(sends.isEmpty)
    }
  }

  @Test("Missing event parts return 400 without sending")
  func missingRequiredPartsAreRejected() async throws {
    let sender = RecordingForumPushSender()
    let invalidEvents = [
      eventJSON(includeActor: false),
      eventJSON(includeRecipient: false),
      eventJSON(includeTarget: false),
    ]

    try await withApp(configure: configure) { app in
      app.forumPushSender = sender
      try await registerDevice(on: app.db)

      for json in invalidEvents {
        try await app.testing().test(.POST, "/events/forum") { request in
          setJSONBody(json, on: &request)
        } afterResponse: { response in
          #expect(response.status == .badRequest)
        }
      }

      let sends = await sender.recordedSends()
      #expect(sends.isEmpty)
    }
  }

  @Test("An APNs failure becomes 502")
  func apnsFailureBecomesBadGateway() async throws {
    let sender = RecordingForumPushSender(shouldFail: true)

    try await withApp(configure: configure) { app in
      app.forumPushSender = sender
      try await registerDevice(on: app.db)

      try await app.testing().test(.POST, "/events/forum") { request in
        setJSONBody(eventJSON(), on: &request)
      } afterResponse: { response in
        #expect(response.status == .badGateway)
        #expect(!response.body.string.contains(defaultDeviceToken))
      }
    }
  }

  @Test("The APNs payload contains the visible alert and deep-link data")
  func apnsPayloadMatchesContract() throws {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let event = try decoder.decode(ForumEventDTO.self, from: Data(eventJSON().utf8))
    let notification = ForumPushMessage(event: event).apnsNotification(topic: "com.homero.app")

    let data = try JSONEncoder().encode(notification)
    let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let aps = try #require(root["aps"] as? [String: Any])
    let alert = try #require(aps["alert"] as? [String: Any])

    #expect(alert["title"] as? String == "Homero")
    #expect(alert["body"] as? String == "Kaique curtiu seu topico")
    #expect(aps["sound"] as? String == "default")
    #expect(root["type"] as? String == "TOPIC_LIKED")
    #expect(root["topicId"] as? String == topicID.uuidString.lowercased())
    #expect(!String(decoding: data, as: UTF8.self).contains(defaultDeviceToken))
  }
}

private struct RecordedForumPush: Sendable {
  let message: ForumPushMessage
  let deviceToken: String
}

private actor RecordingForumPushSender: ForumPushSending {
  private let failingDeviceTokens: Set<String>
  private var sends: [RecordedForumPush] = []

  init(shouldFail: Bool = false) {
    self.failingDeviceTokens = shouldFail ? [defaultDeviceToken] : []
  }

  init(failingDeviceTokens: Set<String>) {
    self.failingDeviceTokens = failingDeviceTokens
  }

  func send(
    _ message: ForumPushMessage,
    to deviceToken: String,
    on request: Request
  ) async throws -> ForumPushDeliveryReceipt {
    sends.append(RecordedForumPush(message: message, deviceToken: deviceToken))

    if failingDeviceTokens.contains(deviceToken) {
      throw StubAPNSError()
    }

    return ForumPushDeliveryReceipt(apnsID: message.eventID, apnsUniqueID: nil)
  }

  func recordedSends() -> [RecordedForumPush] {
    sends
  }
}

private struct StubAPNSError: Error {}

private let eventID = UUID(uuidString: "2a8f29c1-3447-4c11-b0ea-fc26950f1384")!
private let actorUserID = UUID(uuidString: "55211d61-078d-4ad9-befc-362c088ddbf9")!
private let defaultRecipientUserID = UUID(uuidString: "9949099d-ab2f-4103-af43-b9954057dbef")!
private let topicID = UUID(uuidString: "373ce888-74c8-437e-8a61-485910713916")!
private let commentID = UUID(uuidString: "473ce888-74c8-437e-8a61-485910713917")!
private let parentCommentID = UUID(uuidString: "573ce888-74c8-437e-8a61-485910713918")!
private let defaultDeviceToken = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
private let secondDeviceToken = "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"

private func eventJSON(
  type: String = "TOPIC_LIKED",
  recipientUserID: UUID = defaultRecipientUserID,
  commentID: UUID? = nil,
  parentCommentID: UUID? = nil,
  includeActor: Bool = true,
  includeRecipient: Bool = true,
  includeTarget: Bool = true
) -> String {
  var fields = [
    "\"eventId\":\"\(eventID.uuidString.lowercased())\"",
    "\"type\":\"\(type)\"",
    "\"occurredAt\":\"2026-08-19T16:08:26Z\"",
  ]

  if includeActor {
    fields.append(
      "\"actor\":{\"userId\":\"\(actorUserID.uuidString.lowercased())\",\"name\":\"Kaique\"}"
    )
  }

  if includeRecipient {
    fields.append(
      "\"recipient\":{\"userId\":\"\(recipientUserID.uuidString.lowercased())\"}"
    )
  }

  if includeTarget {
    var targetFields = [
      "\"topicId\":\"\(topicID.uuidString.lowercased())\"",
      "\"topicTitle\":\"Criando um novo topico\"",
    ]
    if let commentID {
      targetFields.append("\"commentId\":\"\(commentID.uuidString.lowercased())\"")
    }
    if let parentCommentID {
      targetFields.append("\"parentCommentId\":\"\(parentCommentID.uuidString.lowercased())\"")
    }
    fields.append("\"target\":{\(targetFields.joined(separator: ","))}")
  }

  return "{\(fields.joined(separator: ","))}"
}

private func setJSONBody(_ json: String, on request: inout TestingHTTPRequest) {
  request.headers.contentType = .json
  request.body.writeString(json)
}

private func registerDevice(
  on database: any Database,
  deviceToken: String = defaultDeviceToken
) async throws {
  try await RegisteredDevice(
    userID: defaultRecipientUserID,
    deviceToken: deviceToken,
    environment: .sandbox
  ).create(on: database)
}
