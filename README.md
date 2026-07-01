# Projeto Tech Challenge - Fiap Cloud Games

Esse projeto foi desenvolvido em uma arquitetura de microsserviços orientada a eventos, utilizando mensageria com RabbitMQ e MassTransit.

## Arquitetura

O projeto consiste nos seguintes elementos:

- **Users.Api (Minimal API)**: autenticação, cadastro e obtenção de dados dos usuários.
- **Catalog.Api (REST API)**: CRUD de jogos e início do processo de adição de jogos no catálogo dos usuários.
- **Catalog.Worker (Worker Service)**: consome o evento `PaymentProcessedEvent` e finaliza o processo de adição de jogos no catálogo dos usuários.
- **Payments.Worker (Worker Service)**: consome o evento `OrderPlacedEvent` e simula o pagamento referente ao pedido, retornando o evento `PaymentProcessedEvent`.
- **Notifications.Worker (Worker Service)**: consome os eventos `UserCreatedEvent` / `PaymentProcessedEvent` e simula o envio de notificação por e-mail.
- **RabbitMQ (Message broker)**: responsável pela comunicação assíncrona dos microsserviços.

## Fluxo de Mensagens

### 1 - Cadastro de novos usuários
1. Usuário administrador já autenticado faz requisição POST no endpoint `/api/users/create` no Users.Api.
2. Users.Api efetua cadastro e cria evento `UserCreatedEvent`.
3. Notifications.Worker consome o evento `UserCreatedEvent` na fila `users-queue` e simula o envido de um e-mail dando boas vindas ao usuário.

### 2 - Aquisição de jogos
1. Usuário autenticado faz requisição POST no endpoint `/catalog` no Catalog.Api.
2. Catalog.Api inicia o processo de aquisição, criando o evento `OrderPlacedEvent`.
3. Payments.Worker consome o evento `OrderPlacedEvent` na fila `orders-placed-queue` e simula processamento do pagamento.
4. Notifications.Worker consome o evento `PaymentProcessedEvent` na fila `payments-queue` e simula o envio de e-mail ao usuário confirmando o pagamento.
5. Catalog.Worker Consome o evento `PaymentProcessedEvent` na fila `payments-queue` e finaliza o processo, efetivamente adicionando o jogo no catálogo do usuário.

## Pré-requisitos

- .NET 10.0 SDK (Preview)
- Docker e Docker Compose

## Como Executar

### Iniciar Serviços e Aplicações

```bash
# Docker Compose
docker-compose up -d
```

## URLs Importantes

- **Users API**: http://localhost:5000
- **Catalog API**: http://localhost:5010
- **RabbitMQ Management UI**: http://localhost:15672

## Testando a Aplicação

### Endpoints Principais:

#### 1. Autenticar e obter token
```bash
POST http://localhost:5000/api/users/auth
Content-Type: application/json
{
  "email": "admin@fiapcloud.com.br",
  "password": "admin"
}
```

#### 2. Criar usuário
```bash
POST http://localhost:5000/api/users/create
Authorization: Bearer (inserir token obtido no passo 1)
Content-Type: application/json
{
  "name": "Usuário Teste",
  "email": "usuario.teste@fiap.com",
  "password": "Teste@1234!",
  "roleId": 2
}
```

#### 3. Cadastrar um novo jogo
```bash
POST http://localhost:5010/game/
Authorization: Bearer (inserir token obtido no passo 1)
Content-Type: application/json
Accept: application/json
{
  "name": "Resident Evil X",
  "description": "A new chapter in the Resident Evil series, combining survival horror with intense action.",
  "genre": "Action",
  "release": "2026-12-01",
  "price": 79.99
}
```

#### 4. Adicionar um jogo ao catálogo de um usuário
```bash
POST http://localhost:5010/catalog/
Authorization: Bearer (inserir token obtido no passo 1)
Content-Type: application/json
Accept: application/json
{
  "userId": 1,
  "gameId": 1,
  "userEmail": "admin@fiapcloud.com.br",
  "price": 79.99
}
```

### RabbitMQ Management UI

Acesse http://localhost:15672 para:
- Visualizar filas e exchanges
- Monitorar mensagens

### Monitoramento - Logs

Os logs das aplicações permitem acompanhamento de todos os fluxos principais, conforme abaixo:
- Catalog.Api: Início do processo de adição de jogo no catálogo do usuário com a publicação do evento `OrderPlacedEvent`.
- Catalog.Worker: Consumo do evento `PaymentProcessedEvent` e efetivação da adição do jogo no catálogo do usuário.
- Notifications.Worker: Consumo do eventos `UserCreatedEvent` / `PaymentProcessedEvent` e simulação do envio de e-mails.
- Users.API: Autenticação, cadastro de novos usuários e publicação do evento `UserCreatedEvent`.
- Payments.Worker: Consumo do evento `OrderPlacedEvent`, simulação do pagamento e publicação do evento `PaymentProcessedEvent`.

## Tecnologias Utilizadas

- **.NET 10.0**: Framework principal
- **MassTransit**: Abstração para messaging
- **RabbmitMQ**: Message broker
- **Docker**: Containerização do Kafka
- **Postgres**: Banco de dados relacional para persistência de jogos e catálogos
- **MySQL**: Banco de dados relacional para persistência de usuários


## Parar Serviços e Aplicações

```bash
docker-compose down
```
