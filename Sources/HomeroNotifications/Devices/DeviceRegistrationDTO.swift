import Foundation
import Vapor

struct DeviceRegistrationDTO: Content, Equatable, Sendable {
  let userID: UUID
  let deviceToken: String
  let environment: PushEnvironment

  enum CodingKeys: String, CodingKey {
    case userID = "userId"
    case deviceToken
    case environment
  }

  var normalizedDeviceToken: String {
    deviceToken.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  func validate() throws {
    try validateAPNSDeviceToken(normalizedDeviceToken)
  }
}

struct DeviceRemovalDTO: Content, Equatable, Sendable {
  let userID: UUID
  let deviceToken: String

  enum CodingKeys: String, CodingKey {
    case userID = "userId"
    case deviceToken
  }

  var normalizedDeviceToken: String {
    deviceToken.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  func validate() throws {
    try validateAPNSDeviceToken(normalizedDeviceToken)
  }
}

struct RegisteredDeviceDTO: Content, Equatable, Sendable {
  let userID: UUID
  let environment: PushEnvironment
  let createdAt: Date?
  let updatedAt: Date?

  enum CodingKeys: String, CodingKey {
    case userID = "userId"
    case environment
    case createdAt
    case updatedAt
  }

  init(device: RegisteredDevice) {
    self.userID = device.userID
    self.environment = device.environment
    self.createdAt = device.createdAt
    self.updatedAt = device.updatedAt
  }
}

private func validateAPNSDeviceToken(_ token: String) throws {
  guard !token.isEmpty else {
    throw Abort(.badRequest, reason: "deviceToken must not be empty")
  }

  guard token.allSatisfy(\.isHexDigit) else {
    throw Abort(.badRequest, reason: "deviceToken must be hexadecimal")
  }
}
