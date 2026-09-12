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
    participant SQS as AWS SQS (MassTransit)
    
    %% Workers e Serviços de Fundo
    participant NotifWorker as Notifications.Lambda
    participant PayWorker as Payments.Worker
    participant CatWorker as Catalog.Worker
    participant Email as Serviço de E-mail

    title Fluxos do Sistema (Cadastro de Usuário e Aquisição de Jogos)

    %% ==========================================
    %% FLUXO 1: CADASTRO DE USUÁRIO
    %% ==========================================
    Note over User, Email: FLUXO 1: AUTENTICAÇÃO, CADASTRO E NOTIFICAÇÃO DE USUÁRIO

    User->>UsersAPI: POST /users/auth (Credenciais)
    activate UsersAPI
    UsersAPI->>UsersAPI: Valida credenciais e gera JWT
    UsersAPI-->>User: Retorna Token JWT (200 OK)
    deactivate UsersAPI

    User->>UsersAPI: POST /users/create (Dados + Bearer Token)
    activate UsersAPI
    UsersAPI->>US: Chame UserService.Add(user)
    activate US
    US->>US: Salva usuário no Banco de Dados
    US->>SQS: Publica UserCreatedEvent
    activate SQS
    US-->>UsersAPI: Retorna Sucesso
    deactivate US
    UsersAPI-->>User: Retorna Status 200 OK
    deactivate UsersAPI

    SQS-)NotifWorker: Consome UserCreatedEvent
    deactivate SQS
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

    User->>UsersAPI: POST /users/auth (Credenciais)
    activate UsersAPI
    UsersAPI-->>User: Retorna Token JWT (200 OK)
    deactivate UsersAPI

    User->>CatAPI: POST /catalog (UserID, GameID, UserEmail, Price + Token)
    activate CatAPI
    CatAPI->>CS: CatalogService.AddToCatalogAsync()
    activate CS
    CS->>SQS: Publica OrderPlacedEvent
    activate SQS
    CS-->>CatAPI: Confirma recebimento da ordem
    deactivate CS
    CatAPI-->>User: Pedido Recebido / Processando (200 OK)
    deactivate CatAPI

    %% Processamento do Pagamento
    SQS-)PayWorker: Consome OrderPlacedEvent
    deactivate SQS
    activate PayWorker
    PayWorker->>PayWorker: PaymentService.SimulatePayment()
    
    alt Pagamento Aprovado
        PayWorker->>SQS: Publica PaymentProcessedEvent com status Approved
        activate SQS
    else Pagamento Recusado
        PayWorker->>SQS:  Publica PaymentProcessedEvent com status Rejected
    end
    deactivate PayWorker

    %% Consumidores em paralelo do PaymentProcessedEvent
    par Atualização do Catálogo
        SQS-)CatWorker: Consome PaymentProcessedEvent
        activate CatWorker
        CatWorker->>CatWorker: Adiciona o jogo ao catálogo do usuário
        deactivate CatWorker
    and Notificação por E-mail
        SQS-)NotifWorker: Consome PaymentProcessedEvent
        deactivate SQS
        activate NotifWorker
        NotifWorker->>Email: Envia e-mail de confirmação de compra
        activate Email
        Email-->>NotifWorker: E-mail enviado
        deactivate Email
        deactivate NotifWorker
    end
