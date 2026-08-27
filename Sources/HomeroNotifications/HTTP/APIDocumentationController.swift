import Vapor

struct APIDocumentationController: Sendable {
  func swaggerUI(_ request: Request) -> Response {
    Response(
      status: .ok,
      headers: ["Content-Type": "text/html; charset=utf-8"],
      body: .init(string: Self.swaggerHTML)
    )
  }

  private static var swaggerHTML: String {
    """
    <!doctype html>
    <html lang="pt-BR">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>HomeroNotifications API</title>
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui.css">
      </head>
      <body>
        <div id="swagger-ui"></div>
        <script id="openapi-document" type="text/plain">\(OpenAPIDocument.contents)</script>
        <script src="https://cdn.jsdelivr.net/npm/js-yaml@4/dist/js-yaml.min.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
        <script>
          SwaggerUIBundle({
            spec: jsyaml.load(document.getElementById("openapi-document").textContent),
            dom_id: "#swagger-ui",
            deepLinking: true,
            displayRequestDuration: true
          });
        </script>
      </body>
    </html>
    """
  }
}

private enum OpenAPIDocument {
  static let contents = """
    openapi: 3.1.0
    info:
      title: HomeroNotifications API
      version: 1.0.0
      description: Prova de conceito para registro de dispositivos e notificacoes push do Forum Homero.
    servers:
      - url: http://127.0.0.1:8080
        description: Ambiente local
    tags:
      - name: Health
      - name: Devices
      - name: Forum events
    paths:
      /health:
        get:
          tags: [Health]
          summary: Verifica a disponibilidade do servico
          operationId: healthCheck
          responses:
            '200':
              description: Servico disponivel
              content:
                application/json:
                  schema:
                    $ref: '#/components/schemas/HealthResponse'
      /devices:
        put:
          tags: [Devices]
          summary: Registra ou atualiza um dispositivo APNs
          operationId: registerDevice
          requestBody:
            required: true
            content:
              application/json:
                schema:
                  $ref: '#/components/schemas/DeviceRegistration'
          responses:
            '200':
              description: Dispositivo registrado
              content:
                application/json:
                  schema:
                    $ref: '#/components/schemas/RegisteredDevice'
            '400':
              $ref: '#/components/responses/BadRequest'
        delete:
          tags: [Devices]
          summary: Remove o registro de um dispositivo APNs
          operationId: removeDevice
          requestBody:
            required: true
            content:
              application/json:
                schema:
                  $ref: '#/components/schemas/DeviceRemoval'
          responses:
            '204':
              description: Registro removido ou inexistente
            '400':
              $ref: '#/components/responses/BadRequest'
      /events/forum:
        post:
          tags: [Forum events]
          summary: Entrega uma notificacao de evento do forum
          operationId: publishForumEvent
          description: O recipient deve ser sempre o autor do topico. Eventos cujo ator seja o destinatario sao ignorados.
          requestBody:
            required: true
            content:
              application/json:
                schema:
                  $ref: '#/components/schemas/ForumEvent'
          responses:
            '202':
              description: Notificacao aceita pelo APNs em pelo menos um dispositivo
            '204':
              description: Auto-notificacao ignorada ou destinatario sem dispositivos
            '400':
              $ref: '#/components/responses/BadRequest'
            '502':
              description: Nenhum envio foi aceito pelo APNs
              content:
                application/json:
                  schema:
                    $ref: '#/components/schemas/ErrorResponse'
    components:
      responses:
        BadRequest:
          description: Corpo ou campo obrigatorio invalido
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
      schemas:
        HealthResponse:
          type: object
          required: [status]
          properties:
            status:
              type: string
              example: ok
        DeviceEnvironment:
          type: string
          enum: [sandbox, production]
        DeviceRegistration:
          type: object
          required: [userId, deviceToken, environment]
          properties:
            userId:
              type: string
              format: uuid
            deviceToken:
              type: string
              description: Token hexadecimal fornecido pelo APNs.
            environment:
              $ref: '#/components/schemas/DeviceEnvironment'
        DeviceRemoval:
          type: object
          required: [userId, deviceToken]
          properties:
            userId:
              type: string
              format: uuid
            deviceToken:
              type: string
        RegisteredDevice:
          type: object
          required: [userId, environment, createdAt, updatedAt]
          properties:
            userId:
              type: string
              format: uuid
            environment:
              $ref: '#/components/schemas/DeviceEnvironment'
            createdAt:
              type: string
              format: date-time
            updatedAt:
              type: string
              format: date-time
        ForumNotificationType:
          type: string
          enum:
            - TOPIC_LIKED
            - TOPIC_COMMENTED
            - COMMENT_REPLIED
            - COMMENT_LIKED
        ForumEvent:
          type: object
          required: [eventId, type, occurredAt, actor, recipient, target]
          properties:
            eventId:
              type: string
              format: uuid
            type:
              $ref: '#/components/schemas/ForumNotificationType'
            occurredAt:
              type: string
              format: date-time
            actor:
              $ref: '#/components/schemas/ForumActor'
            recipient:
              $ref: '#/components/schemas/ForumRecipient'
            target:
              $ref: '#/components/schemas/ForumTarget'
        ForumActor:
          type: object
          required: [userId, name]
          properties:
            userId:
              type: string
              format: uuid
            name:
              type: string
              minLength: 1
        ForumRecipient:
          type: object
          required: [userId]
          properties:
            userId:
              type: string
              format: uuid
        ForumTarget:
          type: object
          required: [topicId, topicTitle]
          properties:
            topicId:
              type: string
              format: uuid
            topicTitle:
              type: string
              minLength: 1
            commentId:
              type: string
              format: uuid
              description: Obrigatorio para COMMENT_LIKED.
            parentCommentId:
              type: string
              format: uuid
              description: Obrigatorio para COMMENT_REPLIED.
        ErrorResponse:
          type: object
          required: [error, reason]
          properties:
            error:
              type: boolean
              example: true
            reason:
              type: string
    """
}
