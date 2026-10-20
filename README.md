# Projeto Tech Challenge FIAP - Orquestration

Este repositório centraliza a orquestração, implantação e execução do ecossistema de microsserviços do projeto **Fiap Cloud Games**. 

A arquitetura foi modernizada para atender a requisitos avançados de escalabilidade, resiliência e observabilidade. O sistema utiliza um **API Gateway** como ponto de entrada único, comunicação orientada a eventos via **Azure Service Bus**, execução **Serverless** para otimização de recursos, e uma stack completa de **Monitoramento e Persistência Poliglota**.

O projeto também conta com pipelines `CI/CD` automatizados via **Github Actions**.

---

## Arquitetura e Componentes do Sistema

O ecossistema é fragmentado em múltiplos repositórios específicos para cada domínio. A tabela abaixo resume o papel de cada componente:

| Componente | Tipo | Descrição / Responsabilidade |
| :--- | :--- | :--- |
| **`Kong API Gateway`** | Gateway | Ponto de entrada unificado. Responsável por rotear as requisições para os microsserviços internos e validar a autenticação (JWT) na borda. |
| **`Users.Api`** | Minimal API | Gerenciamento de usuários, autenticação (JWT) e cadastro. Persistência em **SQL Server**. |
| **`Catalog.Api`** | REST API | Gerenciamento de jogos (CRUD) e intenção de compra. Persistência poliglota utilizando **MongoDB** e Cache distribuído com **Redis**, além de busca avançada de jogos com **Elasticsearch**. |
| **`Catalog.Worker`**| Worker | Consome a confirmação de pagamento e efetiva a vinculação do jogo ao catálogo do usuário. |
| **`Payments.Worker`**| Worker | Consome as intenções de compra, simula pagamento e emite o resultado. |
| **`Notifications.Function`**| Serverless | Função Serverless (Azure Functions) acionada sob demanda para disparo simulado de e-mails, otimizando o uso de recursos. |
| **`Microsoft Azure`** | Infra (Cloud) | Provê os serviços de **Service Bus**, **Key Vault**, **AKS**, **ACR**, **DocumentDB (Mongo)**, **SQL Server** e **Functions**. |
| **`Prometheus & Grafana`**| Observabilidade | Coleta de métricas instrumentadas (OpenTelemetry) das APIs e geração de dashboards em tempo real. |

---

## Fluxos Orientados a Eventos

A comunicação assíncrona entre os microsserviços ocorre através de tópicos do **Azure Service Bus**, gerenciados pelo **MassTransit**.

### 1. Fluxo de Cadastro de Novos Usuários
1. **Gatilho Inicial**: Uma requisição via Kong API Gateway para `/user/create` atinge a **Users.Api**.
2. **Persistência e Publicação**: A API cadastra o usuário no banco de dados SQL Server e publica o evento `UserCreatedEvent` no Service Bus.
3. **Reação Assíncrona**: A função serverless **Notifications.Function** é acionada (triggered) consumindo o evento do tópico `users-topic` para simular o envio de um e-mail de boas-vindas.

### 2. Fluxo de Aquisição e Compra de Jogos
1. **Gatilho Inicial**: O usuário autenticado solicita a compra enviando requisição para `/catalog` via Kong API Gateway.
2. **Início do Processo**: A **Catalog.Api** registra a intenção e publica `OrderPlacedEvent` no tópico `orders-topic`.
3. **Simulação de Pagamento**: O **Payments.Worker** consome o evento, processa a transação e devolve o evento `PaymentProcessedEvent` via mensageria.
4. **Reações em Cadeia (Processamento Paralelo)**:
   * **Notificação**: A função **Notifications.Function** captura o evento na fila de pagamentos e simula o e-mail de confirmação.
   * **Efetivação**: O **Catalog.Worker** captura o mesmo evento, encerra o ciclo e adiciona o jogo ao catálogo de propriedade do usuário.

---

## Tecnologias Empregadas
* **Backend:** .NET 10, C#
* **Gateway:** Kong API Gateway
* **Serverless:** Azure Functions
* **Mensageria:** MassTransit, Azure Service Bus
* **Persistência, Cache e busca avançada:** DocumentDB(Mongo), Redis, SQL Server e Elasticsearch
* **Observabilidade:** Prometheus, Grafana
* **Registry**: Azure Container Registries (ACR)
* **Cluster Kubernetes:** Azure Kubernetes Service (AKS)
* **Cofre de chaves:** Azure Key Vault
* **Cloud:** Microsoft Azure
* **Pipeline CI/CD:** Github Actions
