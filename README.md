# Projeto Tech Challenge FIAP - Orquestration

Este repositório centraliza a orquestração, implantação e execução do ecossistema de microsserviços do projeto **Fiap Cloud Games**. 

A arquitetura foi modernizada para atender a requisitos avançados de escalabilidade, resiliência e observabilidade. O sistema utiliza um **API Gateway** como ponto de entrada único, comunicação orientada a eventos via **Amazon SQS/SNS**, execução **Serverless** para otimização de recursos, e uma stack completa de **Monitoramento e Persistência Poliglota**.

---

## Arquitetura e Componentes do Sistema

O ecossistema é fragmentado em múltiplos repositórios específicos para cada domínio. A tabela abaixo resume o papel de cada componente:

| Componente | Tipo | Descrição / Responsabilidade |
| :--- | :--- | :--- |
| **`Kong API Gateway`** | Gateway | Ponto de entrada unificado. Responsável por rotear as requisições para os microsserviços internos e validar a autenticação (JWT) na borda. |
| **`Users.Api`** | Minimal API | Gerenciamento de usuários, autenticação (JWT) e cadastro. Persistência em **MySQL**. |
| **`Catalog.Api`** | REST API | Gerenciamento de jogos (CRUD) e intenção de compra. Persistência poliglota utilizando **PostgreSQL**, **MongoDB** e Cache distribuído com **Redis**. |
| **`Catalog.Worker`**| Worker | Consome a confirmação de pagamento e efetiva a vinculação do jogo ao catálogo do usuário. |
| **`Payments.Worker`**| Worker | Consome as intenções de compra, simula pagamento e emite o resultado. |
| **`Notifications.Lambda`**| Serverless | Função Serverless (AWS Lambda) acionada sob demanda para disparo simulado de e-mails, otimizando o uso de recursos. |
| **`LocalStack`** | Infra (Cloud) | Emulador local do ecossistema AWS, provendo os serviços de **SQS**, **SNS** e **Lambda**. |
| **`Prometheus & Grafana`**| Observabilidade | Coleta de métricas instrumentadas (OpenTelemetry) das APIs e geração de dashboards em tempo real. |

---

## Fluxos Orientados a Eventos

A comunicação assíncrona entre os microsserviços ocorre através de filas do **Amazon SQS** e tópicos **SNS**, gerenciados pelo **MassTransit**.

### 1. Fluxo de Cadastro de Novos Usuários
1. **Gatilho Inicial**: Uma requisição via Kong API Gateway para `/api/users/create` atinge a **Users.Api**.
2. **Persistência e Publicação**: A API cadastra o usuário no banco de dados MySQL e publica o evento `UserCreatedEvent` no SQS.
3. **Reação Assíncrona**: A função serverless **Notifications.Lambda** é acionada (triggered) consumindo o evento da fila `users-queue` para simular o envio de um e-mail de boas-vindas.

### 2. Fluxo de Aquisição e Compra de Jogos
1. **Gatilho Inicial**: O usuário autenticado solicita a compra enviando requisição para `/catalog` via Kong API Gateway.
2. **Início do Processo**: A **Catalog.Api** registra a intenção e publica `OrderPlacedEvent` na fila `orders-placed-queue`.
3. **Simulação de Pagamento**: O **Payments.Worker** consome o evento, processa a transação e devolve o evento `PaymentProcessedEvent` via mensageria.
4. **Reações em Cadeia (Processamento Paralelo)**:
   * **Notificação**: A função **Notifications.Lambda** captura o evento na fila de pagamentos e simula o e-mail de confirmação.
   * **Efetivação**: O **Catalog.Worker** captura o mesmo evento, encerra o ciclo e adiciona o jogo ao catálogo de propriedade do usuário.

---

## Pré-requisitos

* [Git](https://git-scm.com/)
* [Docker & Docker Compose](https://www.docker.com/)
* [Kubernetes CLI (kubectl)](https://kubernetes.io/docs/tasks/tools/)
* [Node.js & npm](https://nodejs.org/) (Para o Serverless Framework)
* [Serverless Framework](https://www.serverless.com/framework/docs/getting-started) (Instalado globalmente: `npm install -g serverless`)

---

## Como Executar o Projeto

O ecossistema pode ser executado via **Docker Compose** ou via **Kubernetes**. 

*Nota: A Função Lambda requer uma etapa manual de implantação via Serverless Framework após a subida da infraestrutura.*

### Execução via Docker Compose

```bash
# 1. Clone o repositório orquestrador e inicie a infraestrutura
git clone https://github.com/splinterxsr/InfraOrchestration.git
cd InfraOrchestration/
docker-compose up -d --build

# 2. Clone e implante o serviço Serverless (Em uma nova aba/pasta)
git clone https://github.com/splinterxsr/Notifications.git
cd Notifications/Notifications.Lambda/
npm install -D serverless-localstack
serverless deploy --stage local

```

### Execução via Kubernetes (Kubectl)

Como os microsserviços estão divididos, é necessário aplicar os manifestos YAML de cada repositório.

#### 1. Configurações Compartilhadas e Infraestrutura

```bash
git clone https://github.com/splinterxsr/InfraOrchestration.git
cd InfraOrchestration/k8s/
kubectl apply -f .

```

#### 2. Implantação da Função Serverless no K8s

Para fazer o deploy da função no LocalStack que está rodando dentro do Kubernetes, precisamos de um túnel:

```bash
# Abra o túnel em um terminal e mantenha rodando:
kubectl port-forward svc/localstack 4566:4566

# Em outro terminal, faça o deploy:
git clone https://github.com/splinterxsr/Notifications.git
cd Notifications/Notifications.Lambda/
npm install -D serverless-localstack
serverless deploy --stage local

```

#### 3. Implantação das APIs e Workers

Em pastas separadas, clone os microsserviços e aplique seus respectivos manifestos localizados nas pastas `k8s/`:

```bash
# Users API
kubectl apply -f Users/Users.API/k8s

# Catalog API e Worker
kubectl apply -f Catalog/Catalog.Api/k8s
kubectl apply -f Catalog/Catalog.Worker/k8s

# Payments Worker
kubectl apply -f Payments/PaymentsWorker/k8s

```

---

## Portas e URLs Importantes

Com a adoção do **Kong API Gateway**, as requisições diretas às APIs foram abstraídas. Todo o tráfego externo deve passar pela porta `8000`.

| Serviço | URL Compose | Descrição |
| --- | --- | --- |
| **API Gateway (Kong)** | `http://localhost:8000` | Ponto de entrada unificado para rotas `/api/users` e `/catalog` |
| Prometheus | `http://localhost:9090` | Monitoramento e coleta de métricas (OpenTelemetry) |
| Grafana | `http://localhost:3000` | Dashboards (User/Pass: admin / admin) |
| LocalStack | `http://localhost:4566` | Emulador Cloud (SQS, SNS, Lambda) |

---

## Testando a Aplicação (Passo a Passo)

*Lembre-se: Todas as requisições agora são direcionadas à porta 8000.*

### Passo 1: Autenticação

```bash
curl -X POST http://localhost:8000/api/users/auth \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@fiapcloud.com.br",
    "password": "admin"
  }'

```

### Passo 2: Criar um Novo Usuário

Substitua `{{TOKEN}}` pelo token recebido no passo anterior.

```bash
curl -X POST http://localhost:8000/api/users/create \
  -H "Authorization: Bearer {{TOKEN}}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Usuário Teste",
    "email": "usuario.teste@fiap.com",
    "password": "Teste@1234!",
    "roleId": 2
  }'

```

### Passo 3: Cadastrar Jogo no Catálogo

```bash
curl -X POST http://localhost:8000/game/ \
  -H "Authorization: Bearer {{TOKEN}}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Resident Evil X",
    "description": "Survival horror and intense action.",
    "genre": "Action",
    "release": "2026-12-01",
    "price": 79.99
  }'

```

### Passo 4: Simulação de Compra

```bash
curl -X POST http://localhost:8000/catalog/ \
  -H "Authorization: Bearer {{TOKEN}}" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": 1,
    "gameId": 1,
    "userEmail": "admin@fiapcloud.com.br",
    "price": 79.99
  }'

```

---

## Tecnologias Empregadas

* **Backend:** .NET 10, C#
* **Gateway:** Kong API Gateway
* **Serverless:** AWS Lambda (LocalStack), Serverless Framework
* **Mensageria:** MassTransit, Amazon SQS/SNS
* **Persistência e Cache:** PostgreSQL, MongoDB, Redis, MySQL
* **Observabilidade:** OpenTelemetry, Prometheus, Grafana
* **Infraestrutura:** Docker, Kubernetes
