### Diagramas de Sequência do Projeto

```mermaid
sequenceDiagram
    autonumber
    actor User as Usuário / Client
    
    %% Participantes das APIs e Serviços
    participant UsersAPI as Users.API (Port 5000)
    participant CatAPI as Catalog.API (Port 5010)
    participant US as UserService
    participant CS as CatalogService
    
    %% Mensageria
    participant RMQ as RabbitMQ (MassTransit)
    
    %% Workers e Serviços de Fundo
    participant NotifWorker as Notifications.Worker
    participant PayWorker as Payments.Worker
    participant CatWorker as Catalog.Worker
    participant Email as Serviço de E-mail

    title Fluxos do Sistema (Cadastro de Usuário e Aquisição de Jogos)

    %% ==========================================
    %% FLUXO 1: CADASTRO DE USUÁRIO
    %% ==========================================
    Note over User, Email: FLUXO 1: AUTENTICAÇÃO, CADASTRO E NOTIFICAÇÃO DE USUÁRIO

    User->>UsersAPI: POST /api/users/auth (Credenciais)
    activate UsersAPI
    UsersAPI->>UsersAPI: Valida credenciais e gera JWT
    UsersAPI-->>User: Retorna Token JWT (200 OK)
    deactivate UsersAPI

    User->>UsersAPI: POST /api/users/create (Dados + Bearer Token)
    activate UsersAPI
    UsersAPI->>US: Chame UserService.Add(user)
    activate US
    US->>US: Salva usuário no Banco de Dados
    US->>RMQ: Publica UserCreatedEvent
    activate RMQ
    US-->>UsersAPI: Retorna Sucesso
    deactivate US
    UsersAPI-->>User: Retorna Usuário Criado (201 Created)
    deactivate UsersAPI

    RMQ-)NotifWorker: Consome UserCreatedEvent
    deactivate RMQ
    activate NotifWorker
    NotifWorker->>Email: Envia e-mail de boas-vindas
    activate Email
    Email-->>NotifWorker: E-mail enviado
    deactivate Email
    deactivate NotifWorker

    %% Espaçador visual no diagrama
    Note over User, Email: =================================================================================

    %% ==========================================
    %% FLUXO 2: AQUISIÇÃO DE JOGOS
    %% ==========================================
    Note over User, Email: FLUXO 2: AQUISIÇÃO DE JOGOS E PROCESSAMENTO DE PAGAMENTO

    User->>UsersAPI: POST /api/users/auth (Credenciais)
    activate UsersAPI
    UsersAPI-->>User: Retorna Token JWT (200 OK)
    deactivate UsersAPI

    User->>CatAPI: POST /catalog (UserID, GameID, UserEmail, Price + Token)
    activate CatAPI
    CatAPI->>CS: CatalogService.AddToCatalogAsync()
    activate CS
    CS->>RMQ: Publica OrderPlacedEvent
    activate RMQ
    CS-->>CatAPI: Confirma recebimento da ordem
    deactivate CS
    CatAPI-->>User: Pedido Recebido / Processando (202 Accepted)
    deactivate CatAPI

    %% Processamento do Pagamento
    RMQ-)PayWorker: Consome OrderPlacedEvent
    deactivate RMQ
    activate PayWorker
    PayWorker->>PayWorker: PaymentService.SimulatePayment()
    
    alt Pagamento Aprovado
        PayWorker->>RMQ: Publica PaymentProcessedEvent
        activate RMQ
    else Pagamento Recusado
        PayWorker->>RMQ: [Opcional] Publica PaymentFailedEvent
    end
    deactivate PayWorker

    %% Consumidores em paralelo do PaymentProcessedEvent
    par Atualização do Catálogo
        RMQ-)CatWorker: Consome PaymentProcessedEvent
        activate CatWorker
        CatWorker->>CatWorker: Adiciona o jogo ao catálogo do usuário
        deactivate CatWorker
    and Notificação por E-mail
        RMQ-)NotifWorker: Consome PaymentProcessedEvent
        deactivate RMQ
        activate NotifWorker
        NotifWorker->>Email: Envia e-mail de confirmação de compra
        activate Email
        Email-->>NotifWorker: E-mail enviado
        deactivate Email
        deactivate NotifWorker
    end