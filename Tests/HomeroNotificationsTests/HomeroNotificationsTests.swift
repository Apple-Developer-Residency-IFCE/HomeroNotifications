@testable import HomeroNotifications
import VaporTesting
import Testing

@Test("Health check")
func healthCheck() async throws {
    try await withApp(configure: configure) { app in
        try await app.testing().test(.GET, "health") { response async throws in
            #expect(response.status == .ok)

            let body = try response.content.decode(HealthResponse.self)
            #expect(body.status == "ok")
        }
    }
}


