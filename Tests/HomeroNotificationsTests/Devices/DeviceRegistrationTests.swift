import Fluent
import Foundation
import Testing
import Vapor
import VaporTesting

@testable import HomeroNotifications

@Suite("Device registration endpoint tests")
struct DeviceRegistrationTests {
  @Test("A device can be registered")
  func deviceCanBeRegistered() async throws {
    try await withApp(configure: configure) { app in
      try await app.testing().test(.PUT, "/devices") { request in
        try request.content.encode(registration())
      } afterResponse: { response async throws in
        #expect(response.status == .ok)
        #expect(!response.body.string.contains(deviceToken))

        let result = try response.content.decode(RegisteredDeviceDTO.self)
        #expect(result.userID == firstUserID)
        #expect(result.environment == .sandbox)
      }

      let devices = try await RegisteredDevice.query(on: app.db).all()
      let device = try #require(devices.first)
      #expect(devices.count == 1)
      #expect(device.userID == firstUserID)
      #expect(device.deviceToken == deviceToken)
      #expect(device.environment == .sandbox)
    }
  }

  @Test("Registering the same token updates its owner without creating a duplicate")
  func registrationIsIdempotent() async throws {
    try await withApp(configure: configure) { app in
      for registration in [
        registration(),
        registration(userID: secondUserID, environment: .production),
      ] {
        try await app.testing().test(.PUT, "/devices") { request in
          try request.content.encode(registration)
        } afterResponse: { response in
          #expect(response.status == .ok)
        }
      }

      let devices = try await RegisteredDevice.query(on: app.db).all()
      let device = try #require(devices.first)
      #expect(devices.count == 1)
      #expect(device.userID == secondUserID)
      #expect(device.environment == .production)
    }
  }

  @Test("A user can register more than one device")
  func userCanRegisterMultipleDevices() async throws {
    try await withApp(configure: configure) { app in
      for token in [deviceToken, secondDeviceToken] {
        try await app.testing().test(.PUT, "/devices") { request in
          try request.content.encode(registration(deviceToken: token))
        } afterResponse: { response in
          #expect(response.status == .ok)
        }
      }

      let devices = try await RegisteredDevice.query(on: app.db).all()
      #expect(devices.count == 2)
    }
  }

  @Test("Removing a device is idempotent and scoped to its owner")
  func deviceCanBeRemovedByItsOwner() async throws {
    try await withApp(configure: configure) { app in
      try await app.testing().test(.PUT, "/devices") { request in
        try request.content.encode(registration())
      } afterResponse: { response in
        #expect(response.status == .ok)
      }

      try await app.testing().test(.DELETE, "/devices") { request in
        try request.content.encode(removal(userID: secondUserID))
      } afterResponse: { response in
        #expect(response.status == .noContent)
      }
      #expect(try await RegisteredDevice.query(on: app.db).count() == 1)

      for _ in 0..<2 {
        try await app.testing().test(.DELETE, "/devices") { request in
          try request.content.encode(removal())
        } afterResponse: { response in
          #expect(response.status == .noContent)
        }
      }
      #expect(try await RegisteredDevice.query(on: app.db).count() == 0)
    }
  }

  @Test("Empty and non-hexadecimal tokens are rejected")
  func invalidTokensAreRejected() async throws {
    try await withApp(configure: configure) { app in
      for token in ["   ", "not-an-apns-token"] {
        try await app.testing().test(.PUT, "/devices") { request in
          try request.content.encode(registration(deviceToken: token))
        } afterResponse: { response in
          #expect(response.status == .badRequest)
        }
      }

      #expect(try await RegisteredDevice.query(on: app.db).count() == 0)
    }
  }
}

private let firstUserID = UUID(uuidString: "9949099d-ab2f-4103-af43-b9954057dbef")!
private let secondUserID = UUID(uuidString: "55211d61-078d-4ad9-befc-362c088ddbf9")!
private let deviceToken = String(repeating: "ab", count: 32)
private let secondDeviceToken = String(repeating: "cd", count: 32)

private func registration(
  userID: UUID = firstUserID,
  deviceToken: String = deviceToken,
  environment: PushEnvironment = .sandbox
) -> DeviceRegistrationDTO {
  DeviceRegistrationDTO(
    userID: userID,
    deviceToken: deviceToken,
    environment: environment
  )
}

private func removal(
  userID: UUID = firstUserID,
  deviceToken: String = deviceToken
) -> DeviceRemovalDTO {
  DeviceRemovalDTO(userID: userID, deviceToken: deviceToken)
}
