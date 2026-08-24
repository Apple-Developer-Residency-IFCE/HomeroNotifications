import Fluent
import Vapor

struct DeviceController: Sendable {
  func register(_ request: Request) async throws -> RegisteredDeviceDTO {
    let registration = try request.content.decode(DeviceRegistrationDTO.self)
    try registration.validate()

    let token = registration.normalizedDeviceToken
    let device: RegisteredDevice

    if let existingDevice = try await RegisteredDevice.query(on: request.db)
      .filter(\.$deviceToken == token)
      .first()
    {
      existingDevice.userID = registration.userID
      existingDevice.environment = registration.environment
      try await existingDevice.update(on: request.db)
      device = existingDevice
    } else {
      let newDevice = RegisteredDevice(
        userID: registration.userID,
        deviceToken: token,
        environment: registration.environment
      )
      try await newDevice.create(on: request.db)
      device = newDevice
    }

    request.logger.info(
      "Push notification device registered",
      metadata: [
        "user_id": "\(registration.userID)",
        "environment": "\(registration.environment.rawValue)",
      ]
    )
    return RegisteredDeviceDTO(device: device)
  }

  func remove(_ request: Request) async throws -> HTTPStatus {
    let removal = try request.content.decode(DeviceRemovalDTO.self)
    try removal.validate()

    if let device = try await RegisteredDevice.query(on: request.db)
      .filter(\.$userID == removal.userID)
      .filter(\.$deviceToken == removal.normalizedDeviceToken)
      .first()
    {
      try await device.delete(on: request.db)
      request.logger.info(
        "Push notification device removed",
        metadata: ["user_id": "\(removal.userID)"]
      )
    }

    return .noContent
  }
}
