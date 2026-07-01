# Projeto Tech Challenge - Fiap Cloud Games

Esse projeto foi construído numa arquitetura de microsserviços orientado a eventos utilizando mensageria através da biblitoeca RabbitMQ com MassTransit.

## Arquitetura

O projeto consiste em:

- **Catalog.Api**: API REST responsável pelo CRUD de jogos e inicia o processo de adição de jogos no catálogo dos usuários
- **Catalog.Worker**: Worker Service que consome eventos do RabbitMQ e adiciona jogos no catálogo dos usuários
- **Users.Api**: API REST responsável por geração de Token de autenticação e CRUD completo de usuários
- **Payments.Worker**: Worker Service que consome eventos do RabbitMQ e processa o pagamento de pedidos de jogos
- **Notifications.Worker**: Worker Service que consome eventos do RabbitMQ e envia notificações por e-mail
- **RabbitMQ**: Message broker para comunicação assíncrona

## Fluxo de Mensagens

# 1 - Aquisição de jogos
1. Usuário faz POST para `/catalog` no Catalog.Api
2. Catalog.Api cria evento `OrderPlacedEvent`
3. Payments.Worker consome o evento `OrderPlacedEvent` na fila `orders-placed-queue` e processa o pagamento
4. Notifications.Worker consome o evento `PaymentProcessedEvent` na fila `payments-queue` e envia e-mail ao usuário com confirmação de pagamento
5. Catalog.Worker Consome o evento `PaymentProcessedEvent` na fila `payments-queue` e adiciona o jogo no catálogo do usuário

# 2 - Cadastro de novos usuários
1. Usuário ADMIN faz post para `/api/users/create` no Users.Api
2. Users.Api cria evento `UserCreatedEvent`
3. Notifications.Worker consome o evento `UserCreatedEvent` na fila `users-queue` e envia um e-mail de boas vindas ao usuário

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

### Usando arquivo HTTP

Use os arquivos `Users.API.http` e `Catalog.Api.http` com extensões como REST Client no VS Code.

## Monitoramento

### Logs das Aplicações

Os logs mostram o fluxo completo:
- Catalog.Api: Adição de novo pedido de jogo e publicação de eventos
- Catalog.Worker: Consumo de eventos de pagamento e adição de jogo no catalogo
- Notifications.Worker: Consumo de eventos e envio de e-mails
- Users.API: Autenticação e cadastro de jogos e publicação de eventos
- Payments.Worker: Consumo de eventos de pedidos de jogo e processamento do pagamento

### RabbitMQ UI

Acesse http://localhost:15672 para:
- Visualizar filas e exchanges
- Monitorar mensagens

## Tecnologias Utilizadas

- **.NET 10.0**: Framework principal
- **MassTransit**: Abstração para messaging
- **RabbmitMQ**: Message broker
- **Docker**: Containerização do Kafka
- **Postgres**: Banco de dados relacional para persistência de jogos e catálogo
- **MySQL**: Banco de dados relacional para persistência de usuários


## Parar os Serviços

```bash
docker-compose down
```