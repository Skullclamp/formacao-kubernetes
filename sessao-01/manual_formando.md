# Manual do Formando — Sessão 1
## Fundamentos de Containers e Kubernetes

# 1. Virtualização

A virtualização permite abstrair os recursos físicos de uma máquina e criar ambientes virtuais independentes.

Num modelo tradicional, várias aplicações podem ser instaladas diretamente no mesmo servidor físico, partilhando o sistema operativo e os respetivos recursos:

```text
Servidor físico
│
├── Sistema Operativo
├── Aplicação A
├── Aplicação B
└── Aplicação C
```

A utilização de ambientes virtualizados permite separar cargas de trabalho e atribuir recursos de forma mais controlada.

---

# 2. Máquinas Virtuais

Uma **máquina virtual**, ou **VM — Virtual Machine**, representa um sistema computacional virtualizado.

```text
Servidor físico
      │
      ▼
  Hipervisor
      │
 ┌────┼────┐
 ▼    ▼    ▼
VM1  VM2  VM3
```

Cada VM dispõe do seu próprio ambiente de sistema operativo convidado.

```text
+---------------------------+
| Aplicação                 |
+---------------------------+
| Sistema Operativo Guest   |
+---------------------------+
| Máquina Virtual           |
+---------------------------+
| Hipervisor                |
+---------------------------+
| Hardware                  |
+---------------------------+
```

O **hipervisor** é a camada responsável por criar e gerir as máquinas virtuais sobre os recursos físicos disponíveis.

---

# 3. Containers

Um **container** permite executar uma aplicação num ambiente isolado relativamente às restantes aplicações do sistema.

Ao contrário de uma máquina virtual, um container não necessita normalmente de transportar um sistema operativo convidado completo. Os containers executados no mesmo host partilham o kernel do sistema operativo anfitrião, mantendo isolamento entre processos e recursos.

```text
+-----------+ +-----------+ +-----------+
| App A     | | App B     | | App C     |
+-----------+ +-----------+ +-----------+
|Container A| |Container B| |Container C|
+-----------+ +-----------+ +-----------+
          Container Runtime
                 │
          Sistema Operativo
                 │
                Host
```

Esta arquitetura reduz o overhead associado a um sistema operativo completo por aplicação e permite, em muitos cenários, criar e iniciar ambientes com maior rapidez.

---

# 4. Containers vs. Máquinas Virtuais

| Máquina Virtual | Container |
|---|---|
| Inclui sistema operativo convidado | Partilha o kernel do host |
| Maior consumo de recursos | Menor overhead |
| Arranque normalmente mais demorado | Arranque normalmente rápido |
| Isolamento ao nível da VM | Isolamento ao nível dos processos |
| Imagens tendencialmente maiores | Imagens tendencialmente menores |

Containers e máquinas virtuais não são tecnologias mutuamente exclusivas. É comum executar plataformas de containers sobre máquinas virtuais, tanto em datacenters como em ambientes cloud.

---

# 5. Container Runtime

Um **container runtime** é um dos componentes responsáveis pela execução dos containers.

```text
Imagem
   │
   ▼
Container Runtime
   │
   ▼
Container
```

O runtime participa na criação e execução do ambiente isolado descrito pela imagem e na gestão do ciclo de vida do container.

---

# 6. Docker

Docker disponibiliza ferramentas para trabalhar com imagens e containers.

## Executar um container

```bash
docker run --name web-demo -d nginx
```

Este comando cria e inicia um container denominado `web-demo` a partir da imagem `nginx`.

## Consultar containers em execução

```bash
docker ps
```

## Consultar logs

```bash
docker logs web-demo
```

## Parar o container

```bash
docker stop web-demo
```

## Remover o container

```bash
docker rm web-demo
```

O ciclo básico pode ser representado por:

```text
Imagem
   ↓
  run
   ↓
Container
   ↓
running
   ↓
 stop
   ↓
stopped
   ↓
remove
```

---

# 7. Podman

Podman é outra ferramenta do ecossistema de containers e disponibiliza comandos semelhantes para operações básicas:

```bash
podman run --name web-demo -d nginx
podman ps
podman logs web-demo
podman stop web-demo
podman rm web-demo
```

Em configurações típicas:

- o **Docker** utiliza uma arquitetura cliente/servidor em que a linha de comandos comunica com um daemon;
- o **Podman** é *daemonless* e foi concebido para facilitar a execução de containers em modo **rootless**.

Docker também pode ser configurado em modo *rootless*. Por isso, a existência de privilégios administrativos não deve ser inferida apenas a partir da ferramenta utilizada.

---

# 8. OCI

**OCI — Open Container Initiative** define especificações comuns para o ecossistema de containers.

```text
Ecossistema de Containers
           │
           ▼
          OCI
     especificações
           │
           ▼
Ferramentas e runtimes
```

Estas especificações contribuem para a interoperabilidade entre imagens, runtimes e ferramentas que implementam os padrões definidos.

---

# 9. Imagens e Containers

Uma imagem e um container representam conceitos diferentes:

> **Uma imagem não é um container.**

A **imagem** representa a base utilizada para criar uma ou várias instâncias de containers.

```text
             Imagem
               │
        ┌──────┼──────┐
        ▼      ▼      ▼
   Container Container Container
       A         B        C
```

Uma mesma imagem pode originar vários containers independentes.

---

# 10. Tags

As imagens podem ser identificadas através de **tags**.

```text
nginx
nginx:1.27
nginx:latest
```

Uma tag permite distinguir referências associadas a uma imagem. Em ambientes controlados, a utilização de versões explícitas facilita a identificação da referência que está efetivamente a ser executada.

---

# 11. Image Registries

Um **image registry** armazena e disponibiliza imagens de containers.

```text
Construir imagem
       ↓
Atribuir tag
       ↓
Image Registry
       ↓
      Pull
       ↓
Executar container
```

O registry funciona como ponto de distribuição das imagens utilizadas por developers, sistemas de CI/CD e plataformas de execução.

---

# 12. Networking de Containers

Uma aplicação num container pode necessitar de comunicar:

- com outros containers;
- com outros sistemas;
- com serviços externos;
- com utilizadores.

Uma representação simples da exposição de uma aplicação é:

```text
Utilizador
     │
     ▼
Host : Porta
     │
     ▼
Container : Porta
     │
     ▼
Aplicação
```

A porta publicada no host permite encaminhar tráfego para a porta em que a aplicação está a escutar dentro do container.

---

# 13. Armazenamento Efémero

Os containers podem ser criados, destruídos e substituídos. Dados guardados exclusivamente no sistema de ficheiros gravável do container ficam associados ao seu ciclo de vida.

Isto conduz a uma questão essencial:

> **O que acontece aos dados quando o container desaparece?**

Dados que necessitam de sobreviver à substituição de um container devem ser armazenados fora desse ciclo de vida.

---

# 14. Volumes

Um **volume** permite separar os dados do ciclo de vida do container que os utiliza.

```text
Container A
     │
     ▼
   Volume
     ▲
     │
Container B
```

> **O ciclo de vida do container não deve ser confundido com o ciclo de vida dos dados.**

## Criar um volume

```bash
docker volume create dados-demo
```

## Consultar volumes

```bash
docker volume ls
```

Um volume pode continuar disponível mesmo depois de o container que o utilizava ser removido, permitindo que outro container volte a montar os mesmos dados.

---

# 15. Princípios Básicos de Segurança

Alguns princípios fundamentais na utilização de containers são:

- utilizar imagens de origem confiável;
- minimizar componentes desnecessários;
- evitar privilégios superiores aos necessários;
- manter as imagens atualizadas;
- não incluir credenciais nas imagens;
- limitar a exposição desnecessária de serviços.

## Exemplo de má prática

```bash
docker run -e DB_PASSWORD=secret123 nginx
```

Neste exemplo, a credencial fica explicitamente presente no comando e pode ser exposta através de histórico, processos ou outros mecanismos de observação do sistema. Segredos devem ser fornecidos através de mecanismos apropriados de gestão de credenciais.

---

# 16. Da Containerização à Orquestração

Executar alguns containers num único servidor é relativamente simples. Quando o número de containers e servidores aumenta, surgem novos problemas operacionais.

```text
Servidor 1 → 20 containers
Servidor 2 → 30 containers
Servidor 3 → 25 containers
Servidor 4 → 40 containers
```

É necessário responder a questões como:

- onde deverá ser executada cada aplicação?
- como manter várias instâncias?
- o que acontece se um servidor falhar?
- como substituir containers que deixam de funcionar?
- como disponibilizar as aplicações?
- como gerir alterações?
- como manter o estado pretendido?

A **orquestração** coordena estas tarefas num conjunto de sistemas e workloads.

---

# 17. Kubernetes

**Kubernetes** é uma plataforma de orquestração de aplicações containerizadas.

Quatro conceitos ajudam a compreender o seu funcionamento:

## Automatização

Tarefas de gestão podem ser executadas automaticamente pela plataforma.

## Configuração declarativa

O utilizador descreve o estado que pretende obter, em vez de definir apenas uma sequência de operações manuais.

## Estado desejado

Representa a configuração que deverá existir no cluster.

## Reconciliação

Kubernetes observa o estado real e procura continuamente aproximá-lo do estado desejado.

Exemplo conceptual:

```text
Desejado: 3 Pods
      │
      ▼
Estado atual: 2 Pods
      │
      ▼
Kubernetes reconcilia
      │
      ▼
Estado atual: 3 Pods
```

---

# 18. Arquitetura Geral de Kubernetes

Um cluster Kubernetes pode ser compreendido através de dois grandes conjuntos: **Control Plane** e **Worker Nodes**.

```text
             Kubernetes Cluster
                    │
          ┌─────────┴──────────┐
          │                    │
          ▼                    ▼
    Control Plane         Worker Nodes
                               │
                         ┌─────┴─────┐
                         ▼           ▼
                        Pod         Pod
```

---

# 19. Control Plane

O **Control Plane** é responsável pela gestão global e controlo do estado do cluster.

Recebe pedidos através da API, mantém a visão do estado pretendido e coordena decisões necessárias para aproximar o estado real do estado declarado.

---

# 20. Worker Nodes

Os **Worker Nodes** são os nodes onde são executados os workloads.

```text
Control Plane
      │
      │ gere
      ▼
 Worker Node
 ├── Pod A
 ├── Pod B
 └── Pod C
```

O Control Plane coordena o cluster; os Worker Nodes disponibilizam capacidade para executar as aplicações.

---

# 21. Kubernetes API

A **Kubernetes API** constitui o ponto central de interação com o cluster.

```text
Utilizador
    ↓
 kubectl
    ↓
Kubernetes API
    ↓
 Cluster
    ↓
Workloads
```

Ferramentas como `kubectl` enviam pedidos à API para consultar ou alterar recursos.

---

# 22. kubectl

`kubectl` é a ferramenta de linha de comandos utilizada para interagir com Kubernetes.

## Consultar informação do cluster

```bash
kubectl cluster-info
```

## Consultar nodes

```bash
kubectl get nodes
```

## Consultar Namespaces

```bash
kubectl get namespaces
```

## Consultar o contexto atual

```bash
kubectl config current-context
```

## Consultar contextos disponíveis

```bash
kubectl config get-contexts
```

## Alterar o contexto

```bash
kubectl config use-context <contexto>
```

---

# 23. kubeconfig e Contextos

O **kubeconfig** contém informação utilizada pelo `kubectl` para determinar como aceder a um ou mais clusters Kubernetes.

```text
kubectl
   │
   ▼
kubeconfig
   │
   ▼
Context
   │
   ▼
Cluster / User / Namespace
```

Um **contexto** associa uma configuração de cluster, uma identidade de utilizador e, opcionalmente, um Namespace predefinido.

O contexto atual pode ser consultado com:

```bash
kubectl config current-context
```

Todos os contextos podem ser listados com:

```bash
kubectl config get-contexts
```

---

# 24. YAML

**YAML** é um formato textual utilizado para representar dados estruturados. Kubernetes utiliza frequentemente YAML para descrever recursos.

Exemplo simples:

```yaml
nome: exemplo
tipo: demonstracao
```

A indentação representa a hierarquia dos dados e deve ser mantida de forma consistente.

---

# 25. Manifests Kubernetes

Um **manifest** descreve declarativamente um recurso que pretendemos criar ou configurar no cluster.

É frequente encontrar campos como:

```yaml
apiVersion:
kind:
metadata:
spec:
```

| Campo | Significado |
|---|---|
| `apiVersion` | Versão da API utilizada |
| `kind` | Tipo de recurso |
| `metadata` | Identificação e metadados |
| `spec` | Estado ou configuração pretendida |

## Exemplo de manifest

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-demo
  namespace: formacao
  labels:
    app: web
    environment: formacao
spec:
  containers:
    - name: web
      image: nginx
```

### Leitura do manifest

| Campo | Exemplo | Significado |
|---|---|---|
| `apiVersion` | `v1` | Versão da API utilizada |
| `kind` | `Pod` | Tipo de recurso |
| `metadata.name` | `web-demo` | Nome do recurso |
| `metadata.namespace` | `formacao` | Namespace onde será criado |
| `metadata.labels` | `app: web` | Metadados utilizados para identificação e seleção |
| `spec.containers` | `name: web` | Container definido no Pod |
| `spec.containers[].image` | `nginx` | Imagem utilizada pelo container |

---

# 26. Pods

Um **Pod** é a unidade básica onde Kubernetes executa containers.

```text
Pod
│
└── Container
       │
       └── Aplicação
```

Um Pod contém a definição dos containers que devem ser executados em conjunto e dos recursos associados a essa execução.

---

# 27. Namespaces

Um **Namespace** permite organizar logicamente recursos dentro de um cluster.

```text
Cluster
│
├── Namespace: formacao
│      ├── Pod A
│      └── Pod B
│
└── Namespace: outro
       └── Pod C
```

## Criar um Namespace

```bash
kubectl create namespace formacao
```

## Consultar Namespaces

```bash
kubectl get ns
```

---

# 28. Labels, Selectors e Annotations

## Labels

As **labels** são pares chave/valor associados aos recursos.

```yaml
labels:
  app: web
  environment: formacao
```

Permitem identificar, organizar e agrupar recursos.

## Selectors

Os **selectors** selecionam recursos através das labels.

```bash
kubectl get pods -n formacao -l app=web
```

```text
Recurso
   │
   └── Label: app=web
             ▲
             │
          Selector
```

## Annotations

As **annotations** são metadados adicionais associados aos recursos. Ao contrário das labels, não são normalmente utilizadas para selecionar conjuntos de objetos.

---

# 29. Principais Objetos Kubernetes

Kubernetes disponibiliza diferentes tipos de objetos para representar workloads, configuração, rede, armazenamento e tarefas.

```text
Kubernetes Objects
│
├── Pod
├── ReplicaSet
├── Deployment
├── Service
├── ConfigMap
├── Secret
├── PersistentVolume
├── PersistentVolumeClaim
├── Job
└── CronJob
```

O **Pod** é o objeto trabalhado diretamente nesta sessão; os restantes surgem aqui como referência para a estrutura global da plataforma.

---

# 30. Prática — Containers

## Executar e consultar um container

```bash
docker run --name web-demo -d nginx
docker ps
docker logs web-demo
```

## Parar e remover

```bash
docker stop web-demo
docker rm web-demo
```

## Criar e consultar um volume

```bash
docker volume create dados-demo
docker volume ls
```

Valide que os dados armazenados no volume podem permanecer disponíveis após a substituição do container que o utiliza.

---

# 31. Prática — Kubernetes

## 31.1. Consultar o ambiente

```bash
kubectl get nodes
kubectl get namespaces
kubectl config current-context
```

Identifique os nodes disponíveis, os Namespaces existentes e o contexto ativo.

## 31.2. Criar um Namespace

```bash
kubectl create namespace formacao
kubectl get ns
```

## 31.3. Criar um Pod através de YAML

Crie `pod-demo.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-demo
  namespace: formacao
  labels:
    app: web
    environment: formacao
spec:
  containers:
    - name: web
      image: nginx
```

Aplicar:

```bash
kubectl apply -f pod-demo.yaml
```

Consultar:

```bash
kubectl get pods -n formacao
```

## 31.4. Consultar labels

```bash
kubectl get pods -n formacao --show-labels
```

## 31.5. Utilizar um selector

```bash
kubectl get pods -n formacao -l app=web
```

## 31.6. Limpar o ambiente

```bash
kubectl delete namespace formacao
```

---

# 32. Checklist de Validação

| Competência | Evidência esperada |
|---|---|
| Executar um container | `docker ps` apresenta `web-demo` em execução |
| Consultar logs | `docker logs web-demo` devolve saída do container |
| Criar volume | `docker volume ls` apresenta `dados-demo` |
| Validar persistência | Os dados mantêm-se após substituir o container que utiliza o volume |
| Consultar cluster | `kubectl get nodes` e `kubectl get namespaces` devolvem recursos |
| Identificar contexto | `kubectl config current-context` apresenta o contexto esperado |
| Criar Namespace | `kubectl get ns` apresenta `formacao` |
| Criar Pod por YAML | `kubectl get pods -n formacao` apresenta `web-demo` |
| Consultar labels | São apresentadas `app=web` e `environment=formacao` |
| Utilizar selector | `-l app=web` devolve o Pod correspondente |

---

# 33. Resumo da Sessão

```text
Virtualização
      ↓
Máquinas Virtuais
      ↓
Containers
      ↓
Imagem + Runtime
      ↓
Networking + Volumes
      ↓
Orquestração
      ↓
Kubernetes
      ↓
Control Plane + Worker Nodes
      ↓
Kubernetes API
      ↑
   kubectl
      ↑
 kubeconfig
      ↓
YAML / Manifest
      ↓
Pod + Namespace + Labels + Selectors
```

Ideias essenciais:

- uma VM inclui um sistema operativo convidado; um container partilha o kernel do host;
- uma imagem é a base utilizada para criar containers;
- o runtime participa na execução dos containers;
- um registry armazena e distribui imagens;
- volumes permitem separar dados do ciclo de vida do container;
- Kubernetes coordena aplicações containerizadas em escala;
- o Control Plane gere o cluster e os Worker Nodes executam workloads;
- `kubectl` comunica com a Kubernetes API;
- `kubeconfig` e contextos determinam como `kubectl` acede aos clusters;
- manifests YAML descrevem recursos e o estado pretendido;
- Pods executam containers e Namespaces organizam recursos;
- labels identificam recursos e selectors permitem selecioná-los.

---

# 34. Exercício Final de Consolidação

Analise o seguinte manifest:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: api-demo
  namespace: formacao
  labels:
    app: api
    environment: dev
spec:
  containers:
    - name: api
      image: nginx
```

Responda:

1. Qual é o tipo de recurso?
2. Qual é o seu nome?
3. Em que Namespace será criado?
4. Que imagem será utilizada?
5. Que labels estão definidas?
6. Qual é o selector que seleciona recursos com `app=api`?
7. Que comando aplica este manifest?
8. Que comando consulta o Pod no Namespace `formacao`?
9. Como pode apresentar as labels do Pod?
10. Como pode remover todos os recursos criados no Namespace `formacao`?
11. Execute `kubectl describe pod api-demo -n formacao` e identifique informação sobre o estado atual do container.

Compare depois o estado declarado no manifest com o estado observado no cluster.
