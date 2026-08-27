import Vapor

struct HealthResponse: Content {
    let status: String
}

func routes(_ app: Application) throws {
    let documentation = APIDocumentationController()

    app.get { _ async in
        "It works!"
    }

    app.get("hello") { _ async -> String in
        "Hello, world!"
    }

    app.get("health") { _ async -> HealthResponse in
        HealthResponse(status: "ok")
    }

    app.get("swagger", use: documentation.swaggerUI)

    app.post("events", "forum") { request async throws -> Response in
        try await ForumEventController().handle(request)
    }

    app.put("devices") { request async throws -> RegisteredDeviceDTO in
        try await DeviceController().register(request)
    }

    app.delete("devices") { request async throws -> HTTPStatus in
        try await DeviceController().remove(request)
    }
}
