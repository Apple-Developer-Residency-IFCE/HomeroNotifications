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

@Test("Swagger UI embeds the API documentation")
func swaggerUI() async throws {
    try await withApp(configure: configure) { app in
        try await app.testing().test(.GET, "swagger") { response async throws in
            #expect(response.status == .ok)
            #expect(response.headers.contentType?.description == "text/html; charset=utf-8")
            #expect(response.body.string.contains("SwaggerUIBundle"))
            #expect(response.body.string.contains("/devices:"))
            #expect(response.body.string.contains("/events/forum:"))
            #expect(response.body.string.contains("COMMENT_REPLIED"))
        }
    }
}
