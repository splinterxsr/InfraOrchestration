# Projeto Tech Challenge FIAP - Orquestration

Este repositório centraliza a orquestração, implantação e execução do ecossistema de microsserviços do projeto **Fiap Cloud Games**. A arquitetura foi desenhada seguindo o modelo orientado a eventos, utilizando mensageria assíncrona para garantir alta escalabilidade, desacoplamento e resiliência entre os serviços.

---

## Arquitetura e Componentes do Sistema

O ecossistema é fragmentado em múltiplos repositórios específicos para cada domínio. A tabela abaixo resume o papel de cada componente:

| Componente | Tipo | Repositório de Origem | Descrição / Responsabilidade |
| :--- | :--- | :--- | :--- |
| **`Users.Api`** | Minimal API | [GitHub - Users](https://github.com/AnaFMel/Users.git) | Gerenciamento de usuários, autenticação (JWT), cadastro e obtenção de dados. Persistência em MySQL. |
| **`Catalog.Api`** | REST API | [GitHub - Catalog](https://github.com/splinterxsr/Catalog.git) | Gerenciamento de jogos (CRUD) e inicialização da intenção de compra/aquisição de um jogo. Persistência em PostgreSQL. |
| **`Catalog.Worker`**| Worker | [GitHub - Catalog](https://github.com/splinterxsr/Catalog.git) | Consome a confirmação de pagamento e efetiva a vinculação do jogo ao catálogo do usuário. |
| **`Payments.Worker`**| Worker | [GitHub - Payments](https://github.com/AnaFMel/Payments.git) | Consome as intenções de compra, simula pagamento e emite o resultado. |
| **`Notifications.Worker`**| Worker | [GitHub - Notifications](https://github.com/splinterxsr/Notifications.git) | Consome eventos de sistema (criação de conta, pagamentos) e simula o disparo de e-mails. |
| **`RabbitMQ`** | Broker | *Infraestrutura* | Message Broker responsável por receber, rotear e entregar os eventos utilizando o ecossistema do **MassTransit**. |

---

## Fluxos Orientados a Eventos

A comunicação entre os microsserviços ocorre de forma assíncrona baseada em eventos publicados no RabbitMQ. Abaixo está o mapeamento do comportamento do sistema:

### 1. Fluxo de Cadastro de Novos Usuários
1. **Gatilho Inicial**: Um usuário administrador autenticado envia uma requisição `POST` para o endpoint `/api/users/create` na **Users.Api**.
2. **Persistência e Publicação**: A API efetua o cadastro no banco de dados MySQL e publica o evento `UserCreatedEvent` no broker.
3. **Reação Assíncrona**: O **Notifications.Worker** intercepta esse evento através da fila `users-queue` e realiza a simulação do envio de um e-mail de boas-vindas para o novo usuário.

### 2. Fluxo de Aquisição e Compra de Jogos
1. **Gatilho Inicial**: Um usuário autenticado solicita a compra de um jogo enviando uma requisição `POST` para `/catalog` na **Catalog.Api**.
2. **Início do Processo**: A API registra a intenção e publica o evento `OrderPlacedEvent` na fila `orders-placed-queue`.
3. **Simulação de Pagamento**: O **Payments.Worker** consome o `OrderPlacedEvent`, processa a transação fictícia e devolve para o broker o evento de resultado `PaymentProcessedEvent`.
4. **Reações em Cadeia (Processamento em Paralelo)**:
   * **Notificação**: O **Notifications.Worker** captura o `PaymentProcessedEvent` na fila `payments-queue` e simula o envio do e-mail de confirmação de pagamento ao usuário.
   * **Efetivação**: O **Catalog.Worker** também captura o `PaymentProcessedEvent` na mesma fila, encerra o ciclo transacional e adiciona oficialmente o jogo ao catálogo de propriedade daquele usuário no banco PostgreSQL.

---

## Pré-requisitos

Antes de iniciar, certifique-se de ter instalado em sua máquina:
* [Git](https://git-scm.com/)
* [Docker & Docker Compose](https://www.docker.com/)
* [Kubernetes CLI (kubectl)](https://kubernetes.io/docs/tasks/tools/)

---

## Como Executar o Projeto

Você pode subir o ecossistema completo de duas formas: utilizando **Docker Compose** ou via **Kubernetes/Kubectl**.

### Execução via Docker Compose

Esta opção baixa ou constrói as imagens e sobe toda a infraestrutura (Bancos de dados, RabbitMQ) e as aplicações de forma automatizada com um único comando.

```bash
# Clone este repositório orquestrador
git clone https://github.com/splinterxsr/InfraOrchestration.git
cd InfraOrchestration\

# Inicialize todos os serviços em segundo plano
docker-compose up -d --build
```

### Execução via Kubernetes (Kubectl)
Como os microsserviços estão divididos em diferentes repositórios, o processo via kubectl exige clonar os subprojetos para aplicar os respectivos manifestos YAML de deployment localizados na pasta k8s de cada um.

#### 1. Configurações Compartilhadas
Primeiro, aplique os manifestos globais contidos neste repositório raiz.

```bash
cd k8s/
kubectl apply -f .
cd ..
```

#### 2. Implantação dos Microsserviços

Execute os blocos de comandos abaixo para clonar cada repositório em uma pasta temporária ou paralela e aplicar seus respectivos arquivos:

```bash
# ---- 1. Microsserviço de Usuários ----
git clone https://github.com/AnaFMel/Users.git
cd Users/Users.API/k8s
kubectl apply -f .
cd ../../..
```

```bash
# ---- 2. Microsserviço de Catálogo (API e Worker) ----
git clone https://github.com/splinterxsr/Catalog.git
# Aplicando API
cd Catalog/Catalog.Api/k8s
kubectl apply -f .
cd ../..
# Aplicando Worker
cd Catalog/Catalog.Worker/k8s
kubectl apply -f .
cd ../../..
```

```bash
# ---- 3. Microsserviço de Pagamentos ----
git clone https://github.com/AnaFMel/Payments.git
cd Payments/PaymentsWorker/k8s
kubectl apply -f .
cd ../../..
```

```bash
# ---- 4. Microsserviço de Notificações ----
git clone https://github.com/splinterxsr/Notifications.git
cd Notifications/Notifications.Worker/k8s 
kubectl apply -f .
cd ../../..
```

# Portas e URLs Importantes
Após a inicialização com sucesso, as seguintes URLs estarão disponíveis:
| Serviço | URL Compose | URL Kubernetes | Descrição |
| :--- | :--- | :--- | :--- |
| Users API | http://localhost:5000 | http://localhost:30100 | autenticação e cadastro de usuários |
| Catalog API | http://localhost:5010 | http://localhost:30080 | CRUD de jogos e catálogos |
| RabbitMQ Dashboard | http://localhost:15672 | http://localhost:31672 | Painel de controle do Broker. User/Password: guest / guest |


# Testando a Aplicação (Passo a Passo)
Utilize ferramentas como Postman, Insomnia, a extensão REST Client (VS Code) ou o próprio terminal via curl.

*Obs: abaixo, exemplificamos as requisições utilizando as URL's disponibilizadas pelo docker-compose.*

## Passo 1: Autenticação
Realize a chamada para obter o Bearer Token necessário para as demais requisições.

```bash
curl -X POST http://localhost:5000/api/users/auth \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@fiapcloud.com.br",
    "password": "admin"
  }'
  ```

## Passo 2: Criar um Novo Usuário
Substitua {{TOKEN}} pelo hash copiado no Passo 1.

```bash
curl -X POST http://localhost:5000/api/users/create \
  -H "Authorization: Bearer {{TOKEN}}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Usuário Teste",
    "email": "usuario.teste@fiap.com",
    "password": "Teste@1234!",
    "roleId": 2
  }'
```

## Passo 3: Cadastrar um Novo Jogo no Catálogo Geral
Substitua {{TOKEN}} pelo hash copiado no Passo 1.

```bash
curl -X POST http://localhost:5010/game/ \
  -H "Authorization: Bearer {{TOKEN}}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Resident Evil X",
    "description": "A new chapter in the Resident Evil series, combining survival horror with intense action.",
    "genre": "Action",
    "release": "2026-12-01",
    "price": 79.99
  }'
```

## Passo 4: Adicionar o Jogo ao Catálogo do Usuário (Simulação de Compra)
Substitua {{TOKEN}} pelo hash copiado no Passo 1.

```bash
curl -X POST http://localhost:5010/catalog/ \
  -H "Authorization: Bearer {{TOKEN}}" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": 1,
    "gameId": 1,
    "userEmail": "admin@fiapcloud.com.br",
    "price": 79.99
  }'
  ```

# Monitoramento por Logs
Para validar o comportamento do sistema, monitore os logs dos containers (ou pods) executando os comandos a seguir.

```bash
# Se estiver usando Docker Compose:
docker compose logs -f [nome_do_servico]

# Se estiver usando Kubernetes:
kubectl logs -f deployment/[nome-do-deployment]
```

# Tecnologias e Ferramentas Empregadas
- .NET 10: Framework principal.
- MassTransit: Abstração de alto nível e implementação de patterns de mensageria.
- RabbitMQ: Message Broker.
- PostgreSQL: Banco de dados relacional para persistencia de Jogos e Catálogos.
- MySQL: Banco de dados relacional para persistencia dos Usuários.
- Docker & Kubernetes: Orquestração e conteinerização da infraestrutura.
