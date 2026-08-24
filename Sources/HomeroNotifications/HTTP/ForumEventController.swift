import APNSCore
import Fluent
import Foundation
import Vapor

struct ForumEventController: Sendable {
  func handle(_ request: Request) async throws -> Response {
    let event = try request.content.decode(ForumEventDTO.self)
    try event.validate()

    request.logger.info(
      "Forum event received",
      metadata: [
        "event_id": "\(event.eventID)",
        "type": "\(event.type.rawValue)",
      ]
    )

    guard event.type == .topicLiked else {
      request.logger.notice(
        "Unsupported forum event ignored",
        metadata: [
          "event_id": "\(event.eventID)",
          "type": "\(event.type.rawValue)",
        ]
      )
      throw Abort(.unprocessableEntity, reason: "Forum event type is not supported yet")
    }

    guard event.actor.userID != event.recipient.userID else {
      request.logger.info(
        "Self-authored forum event ignored",
        metadata: ["event_id": "\(event.eventID)"]
      )
      return Response(status: .noContent)
    }

    let devices = try await RegisteredDevice.query(on: request.db)
      .filter(\.$userID == event.recipient.userID)
      .all()

    guard !devices.isEmpty else {
      request.logger.info(
        "Forum event recipient has no registered devices",
        metadata: ["event_id": "\(event.eventID)"]
      )
      return Response(status: .noContent)
    }

    let message = ForumPushMessage(event: event)
    var acceptedDeliveries = 0

    for device in devices {
      do {
        let receipt = try await request.application.forumPushSender.send(
          message,
          to: device.deviceToken,
          on: request
        )
        acceptedDeliveries += 1

        request.logger.info(
          "Forum push accepted by APNs",
          metadata: [
            "event_id": "\(event.eventID)",
            "apns_id": "\(receipt.apnsID?.uuidString.lowercased() ?? "unavailable")",
          ]
        )
      } catch let error as APNSError {
        request.logger.error(
          "APNs delivery failed",
          metadata: [
            "event_id": "\(event.eventID)",
            "error_type": "\(String(reflecting: type(of: error)))",
            "apns_status": "\(error.responseStatus)",
            "apns_reason": "\(error.reason?.reason ?? "unavailable")",
          ]
        )
      } catch {
        request.logger.error(
          "APNs delivery failed",
          metadata: [
            "event_id": "\(event.eventID)",
            "error_type": "\(String(reflecting: type(of: error)))",
          ]
        )
      }
    }

    guard acceptedDeliveries > 0 else {
      throw Abort(.badGateway, reason: "Unable to deliver the notification to APNs")
    }

    return Response(status: .accepted)
  }
}
