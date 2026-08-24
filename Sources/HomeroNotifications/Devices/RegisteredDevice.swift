import Fluent
import Foundation

enum PushEnvironment: String, Codable, CaseIterable, Sendable {
  case sandbox
  case production
}

final class RegisteredDevice: Model, @unchecked Sendable {
  static let schema = "registered_devices"

  @ID(key: .id)
  var id: UUID?

  @Field(key: "user_id")
  var userID: UUID

  @Field(key: "device_token")
  var deviceToken: String

  @Enum(key: "environment")
  var environment: PushEnvironment

  @Timestamp(key: "created_at", on: .create)
  var createdAt: Date?

  @Timestamp(key: "updated_at", on: .update)
  var updatedAt: Date?

  init() {}

  init(
    id: UUID? = nil,
    userID: UUID,
    deviceToken: String,
    environment: PushEnvironment
  ) {
    self.id = id
    self.userID = userID
    self.deviceToken = deviceToken
    self.environment = environment
  }
}

struct CreateRegisteredDevice: AsyncMigration {
  func prepare(on database: any Database) async throws {
    try await database.schema(RegisteredDevice.schema)
      .id()
      .field("user_id", .uuid, .required)
      .field("device_token", .string, .required)
      .field("environment", .string, .required)
      .field("created_at", .datetime)
      .field("updated_at", .datetime)
      .unique(on: "device_token")
      .create()
  }

  func revert(on database: any Database) async throws {
    try await database.schema(RegisteredDevice.schema).delete()
  }
}
