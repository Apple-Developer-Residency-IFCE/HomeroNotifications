import APNS
import APNSCore
import Foundation
import Fluent
import FluentSQLiteDriver
import Vapor
import VaporAPNS

/// configures your application
func configure(_ app: Application) async throws {
    if app.environment == .testing {
        app.databases.use(.sqlite(.memory), as: .sqlite)
    } else {
        let databasePath = Environment.get("DATABASE_PATH") ?? "homero-notifications.sqlite"
        app.databases.use(.sqlite(.file(databasePath)), as: .sqlite)
    }
    app.migrations.add(CreateRegisteredDevice())
    try await app.autoMigrate()

    app.forumPushSender = try await makeForumPushSender(for: app)

    try routes(app)
}

private func makeForumPushSender(for app: Application) async throws -> any ForumPushSending {
    guard app.environment != .testing else {
        return UnconfiguredForumPushSender()
    }

    guard let settings = try APNSSettings.loadFromEnvironment() else {
        app.logger.warning(
            "APNs is not configured; POST /events/forum will return 502 until credentials are provided"
        )
        return UnconfiguredForumPushSender()
    }

    let keyData: Data
    do {
        keyData = try Data(contentsOf: URL(fileURLWithPath: settings.privateKeyPath))
    } catch {
        throw APNSSettingsError.unreadablePrivateKey
    }

    let configuration = APNSClientConfiguration(
        authenticationMethod: .jwt(
            privateKey: try .loadFrom(string: String(decoding: keyData, as: UTF8.self)),
            keyIdentifier: settings.keyID,
            teamIdentifier: settings.teamID
        ),
        environment: settings.environment.apnsEnvironment
    )

    await app.apns.containers.use(
        configuration,
        eventLoopGroupProvider: .shared(app.eventLoopGroup),
        responseDecoder: JSONDecoder(),
        requestEncoder: JSONEncoder(),
        as: .default
    )

    app.logger.info(
        "APNs client configured",
        metadata: ["environment": "\(settings.environment.rawValue)"]
    )
    return APNSForumPushSender(bundleID: settings.bundleID)
}

private struct APNSSettings: Sendable {
    enum PushEnvironment: String, Sendable {
        case sandbox
        case production

        var apnsEnvironment: APNSEnvironment {
            switch self {
            case .sandbox: .development
            case .production: .production
            }
        }
    }

    let keyID: String
    let teamID: String
    let bundleID: String
    let privateKeyPath: String
    let environment: PushEnvironment

    static func loadFromEnvironment() throws -> APNSSettings? {
        let requiredKeys = [
            "APNS_KEY_ID",
            "APNS_TEAM_ID",
            "APNS_BUNDLE_ID",
            "APNS_PRIVATE_KEY_PATH",
        ]
        let suppliedValues = requiredKeys.compactMap { key in
            Environment.get(key).flatMap { value in
                value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : (key, value)
            }
        }

        guard !suppliedValues.isEmpty else {
            return nil
        }

        let suppliedKeys = Set(suppliedValues.map(\.0))
        let missingKeys = requiredKeys.filter { !suppliedKeys.contains($0) }
        guard missingKeys.isEmpty else {
            throw APNSSettingsError.missingEnvironmentVariables(missingKeys)
        }

        let environmentName = (Environment.get("APNS_ENVIRONMENT") ?? "sandbox")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let environment = PushEnvironment(rawValue: environmentName.lowercased()) else {
            throw APNSSettingsError.invalidEnvironment
        }

        return APNSSettings(
            keyID: Environment.get("APNS_KEY_ID")!,
            teamID: Environment.get("APNS_TEAM_ID")!,
            bundleID: Environment.get("APNS_BUNDLE_ID")!,
            privateKeyPath: Environment.get("APNS_PRIVATE_KEY_PATH")!,
            environment: environment
        )
    }
}

private enum APNSSettingsError: Error, CustomStringConvertible {
    case missingEnvironmentVariables([String])
    case invalidEnvironment
    case unreadablePrivateKey

    var description: String {
        switch self {
        case .missingEnvironmentVariables(let keys):
            "Missing APNs environment variables: \(keys.joined(separator: ", "))"
        case .invalidEnvironment:
            "APNS_ENVIRONMENT must be either sandbox or production"
        case .unreadablePrivateKey:
            "The APNs private key file could not be read"
        }
    }
}
