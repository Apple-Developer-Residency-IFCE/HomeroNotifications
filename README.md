# HomeroNotifications

Prova de conceito em Vapor para receber eventos do Forum Homero e entregar notificacoes push pelo Apple Push Notification service (APNs).

## Requisitos

- Swift 6.3.3 (registrado em `.swift-version`).
- Push Notifications habilitado no aplicativo Homero.
- Uma chave APNs `.p8`, Key ID e Team ID do Apple Developer.
- O Bundle ID e um token APNs do aplicativo instalado no dispositivo.

## Configuracao do APNs

Crie a configuracao local a partir do exemplo:

```bash
cp .env.example .env
```

Preencha as variaveis abaixo. O Vapor carrega `.env` ao iniciar, e o arquivo e ignorado pelo Git.

```dotenv
APNS_KEY_ID=ABC123DEFG
APNS_TEAM_ID=TEAM123456
APNS_BUNDLE_ID=br.com.homero.app
APNS_PRIVATE_KEY_PATH=/caminho/absoluto/AuthKey_ABC123DEFG.p8
APNS_ENVIRONMENT=sandbox
```

Use `sandbox` para builds locais instalados pelo Xcode. Use `production` para builds distribuidos pelo TestFlight ou App Store. Nunca copie a chave `.p8` para o repositorio.

Se nenhuma credencial for fornecida, o servico ainda inicia para permitir health checks, mas `POST /events/forum` responde `502`. Se apenas parte da configuracao for fornecida, a inicializacao falha informando os nomes das variaveis ausentes.

## Executar

```bash
swift run
```

O servidor inicia por padrao em `http://127.0.0.1:8080`. Verifique-o com:

```bash
curl -i http://127.0.0.1:8080/health
```

## Enviar um evento de teste

Tipos de evento atualmente aceitos:

- `TOPIC_LIKED`: o topico recebeu uma curtida.
- `TOPIC_COMMENTED`: o topico recebeu uma resposta.
- `COMMENT_REPLIED`: um comentario do topico recebeu uma resposta.
- `COMMENT_LIKED`: um comentario do topico recebeu uma curtida.

Substitua `APNS_DEVICE_TOKEN` pelo token hexadecimal registrado pelo aplicativo:

```bash
curl -i \
  -X POST http://127.0.0.1:8080/events/forum \
  -H 'Content-Type: application/json' \
  -d '{
    "eventId": "2a8f29c1-3447-4c11-b0ea-fc26950f1384",
    "type": "TOPIC_LIKED",
    "occurredAt": "2026-08-19T16:08:26Z",
    "actor": {
      "userId": "55211d61-078d-4ad9-befc-362c088ddbf9",
      "name": "Kaique"
    },
    "recipient": {
      "userId": "9949099d-ab2f-4103-af43-b9954057dbef"
    },
    "target": {
      "topicId": "373ce888-74c8-437e-8a61-485910713916",
      "topicTitle": "Criando um novo topico"
    }
  }'
```

Resultados esperados:

- `202 Accepted`: o APNs aceitou a solicitacao.
- `204 No Content`: ator e destinatario sao o mesmo Homero User ID ou o destinatario nao possui dispositivos registrados.
- `400 Bad Request`: o JSON ou um campo obrigatorio e invalido.
- `502 Bad Gateway`: o cliente nao esta configurado ou o envio ao APNs falhou.

O servico resolve todos os aparelhos do destinatario pelo `recipient.userId` e tenta entregar a notificacao a cada um deles. Os logs incluem o `eventId`, o tipo do evento e o identificador de resposta do APNs. Eles nao incluem o token do dispositivo, a chave privada ou outras credenciais.

## Registro de dispositivos

O servico mantem os dispositivos em SQLite. Por padrao, o banco fica em
`homero-notifications.sqlite`; defina `DATABASE_PATH` para usar outro caminho.

Registre ou atualize um dispositivo com:

```bash
curl -i \
  -X PUT http://127.0.0.1:8080/devices \
  -H 'Content-Type: application/json' \
  -d '{
    "userId": "9949099d-ab2f-4103-af43-b9954057dbef",
    "deviceToken": "APNS_DEVICE_TOKEN",
    "environment": "sandbox"
  }'
```

O mesmo token pertence a apenas um usuario. Repetir o registro atualiza o
usuario e o ambiente sem criar uma duplicata. Um usuario pode possuir varios
tokens.

Remova a associacao no logout com:

```bash
curl -i \
  -X DELETE http://127.0.0.1:8080/devices \
  -H 'Content-Type: application/json' \
  -d '{
    "userId": "9949099d-ab2f-4103-af43-b9954057dbef",
    "deviceToken": "APNS_DEVICE_TOKEN"
  }'
```

O token do dispositivo nunca e retornado pela API nem incluido nos logs.

## Testes

```bash
swift test
```

Os testes usam um emissor em memoria e nao acessam o APNs.
