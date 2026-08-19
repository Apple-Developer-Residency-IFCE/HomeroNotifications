import Vapor

struct HealthResponse: Content {
    let status: String
}

func routes(_ app: Application) throws {
    app.get { _ async in
        "It works!"
    }

    app.get("hello") { _ async -> String in
        "Hello, world!"
    }

    app.get("health") { _ async -> HealthResponse in
        HealthResponse(status: "ok")
    }
}