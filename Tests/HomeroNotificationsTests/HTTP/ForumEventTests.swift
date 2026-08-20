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
        setJSONBody(eventJSON(type: "TOPIC_COMMENTED"), on: &request)
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
      eventJSON(deviceToken: nil),
      eventJSON(includeTarget: false),
    ]

    try await withApp(configure: configure) { app in
      app.forumPushSender = sender

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
  private let shouldFail: Bool
  private var sends: [RecordedForumPush] = []

  init(shouldFail: Bool = false) {
    self.shouldFail = shouldFail
  }

  func send(
    _ message: ForumPushMessage,
    to deviceToken: String,
    on request: Request
  ) async throws -> ForumPushDeliveryReceipt {
    sends.append(RecordedForumPush(message: message, deviceToken: deviceToken))

    if shouldFail {
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
private let defaultDeviceToken = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

private func eventJSON(
  type: String = "TOPIC_LIKED",
  recipientUserID: UUID = defaultRecipientUserID,
  deviceToken: String? = defaultDeviceToken,
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
    var recipientFields = [
      "\"userId\":\"\(recipientUserID.uuidString.lowercased())\""
    ]
    if let deviceToken {
      recipientFields.append("\"deviceToken\":\"\(deviceToken)\"")
    }
    fields.append("\"recipient\":{\(recipientFields.joined(separator: ","))}")
  }

  if includeTarget {
    fields.append(
      "\"target\":{\"topicId\":\"\(topicID.uuidString.lowercased())\",\"topicTitle\":\"Criando um novo topico\"}"
    )
  }

  return "{\(fields.joined(separator: ","))}"
}

private func setJSONBody(_ json: String, on request: inout TestingHTTPRequest) {
  request.headers.contentType = .json
  request.body.writeString(json)
}
