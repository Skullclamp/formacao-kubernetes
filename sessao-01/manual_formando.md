# Manual do Formando
## Sessão 1 — Fundamentos de Containers e Kubernetes

Esta versão separa explicitamente os dois módulos que constituem a Sessão 1:

- **Módulo 1 — Fundamentos de Containers**
- **Módulo 2 — Fundamentos e Arquitetura Kubernetes**

A sessão tem a duração total de 4 horas e destina-se a formandos de nível intermédio.

---

# Introdução à Sessão 1

Antes de trabalhar com Kubernetes é essencial compreender a tecnologia que está na sua base: os **containers**.

Nesta sessão, o percurso inicia-se na virtualização tradicional, evolui para containers e termina com a criação dos primeiros recursos Kubernetes.

A progressão será:

```text
Virtualização
      ↓
Containers
      ↓
Imagens / Runtimes / Networking / Volumes
      ↓
Necessidade de Orquestração
      ↓
Kubernetes
      ↓
Cluster
      ↓
Kubernetes API
      ↑
   kubectl
      ↑
 kubeconfig
      ↓
Manifest YAML
      ↓
Namespaces / Pods / Labels / Selectors
```

---

# Objetivos da Sessão

No final desta sessão, o formando deverá conseguir:

- explicar os conceitos fundamentais de virtualização e containerização;
- distinguir containers de máquinas virtuais;
- compreender o papel dos container runtimes;
- enquadrar Docker, Podman e OCI;
- distinguir imagens de containers;
- compreender registries, networking e volumes;
- executar operações básicas sobre containers;
- reconhecer princípios elementares de segurança;
- explicar a necessidade de orquestração;
- compreender a arquitetura geral de Kubernetes;
- identificar Control Plane e Worker Nodes;
- compreender o papel da Kubernetes API;
- utilizar `kubectl`;
- compreender contextos e `kubeconfig`;
- interpretar manifests YAML simples;
- compreender Pods e Namespaces;
- utilizar labels e selectors;
- criar recursos Kubernetes básicos.

---

# Módulo 1 — Fundamentos de Containers

O primeiro módulo estabelece as bases necessárias para compreender o funcionamento dos containers e, posteriormente, a necessidade de uma plataforma de orquestração.

Os conteúdos abrangem virtualização, containers, runtimes, Docker, Podman, OCI, imagens, registries, ciclo de vida, networking, volumes e princípios básicos de segurança.

---

## 1. Virtualização

Durante muitos anos, uma aplicação era normalmente instalada diretamente num servidor físico.

```text
Servidor físico
│
├── Sistema Operativo
├── Aplicação A
├── Aplicação B
└── Aplicação C
```

Este modelo pode criar problemas de utilização dos recursos, dependências entre aplicações e dificuldades na criação de ambientes isolados.

A **virtualização** permite abstrair os recursos físicos de uma máquina e criar diferentes ambientes virtuais independentes.

---

## 2. Máquinas Virtuais

Uma **máquina virtual**, normalmente designada por **VM — Virtual Machine**, representa um sistema computacional virtualizado.

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

Cada VM dispõe do seu próprio ambiente de sistema operativo.

Uma representação simplificada é:

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

---

## 3. Containers

Um **container** permite executar uma aplicação num ambiente isolado relativamente a outras aplicações.

Ao contrário de uma máquina virtual, um container não necessita normalmente de transportar um sistema operativo convidado completo.

Os containers partilham o kernel do sistema anfitrião, mantendo isolamento entre os processos executados.

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

---

## 4. Containers vs. Máquinas Virtuais

| Máquina Virtual | Container |
|---|---|
| Inclui sistema operativo convidado | Partilha o kernel do host |
| Maior consumo de recursos | Menor overhead |
| Arranque normalmente mais demorado | Arranque normalmente rápido |
| Isolamento ao nível da VM | Isolamento ao nível dos processos |
| Imagens tendencialmente maiores | Imagens tendencialmente menores |

### Ideia fundamental

Containers e máquinas virtuais não são necessariamente tecnologias concorrentes.

É perfeitamente possível executar plataformas de containers em máquinas virtuais, situação muito comum em ambientes empresariais e cloud.

---

## 5. Container Runtime

Um **container runtime** é um dos componentes responsáveis pela execução dos containers.

Conceptualmente:

```text
Imagem
   │
   ▼
Container Runtime
   │
   ▼
Container
```

Nesta sessão o objetivo é compreender a função do runtime e a sua posição no ecossistema de containers, sem aprofundar os seus componentes internos.

---

## 6. Docker

Docker disponibiliza ferramentas para trabalhar com imagens e containers.

### Executar um container

```bash
docker run --name web-demo -d nginx
```

### Consultar containers em execução

```bash
docker ps
```

### Consultar os logs

```bash
docker logs web-demo
```

### Parar o container

```bash
docker stop web-demo
```

### Remover o container

```bash
docker rm web-demo
```

A sequência básica pode ser representada por:

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

## 7. Podman

Podman é outra ferramenta do ecossistema de containers.

Os mesmos exemplos básicos podem ser executados através de:

```bash
podman run --name web-demo -d nginx
podman ps
podman logs web-demo
podman stop web-demo
podman rm web-demo
```

Nesta sessão não se pretende realizar um estudo aprofundado ou uma comparação exaustiva entre Docker e Podman.

O objetivo é perceber que ambos permitem trabalhar com containers e que fazem parte do ecossistema abordado na formação.

### Nota prática — Docker e Podman

Em configurações típicas:

- o **Docker** utiliza uma arquitetura cliente/servidor, em que a linha de comandos comunica com um daemon;
- o **Podman** é *daemonless* e foi concebido para facilitar a execução de containers em modo **rootless**, isto é, sem privilégios administrativos permanentes.

Esta distinção pode originar pequenas diferenças de comportamento em laboratórios mistos. O objetivo nesta sessão é apenas reconhecer essa diferença. Existem também configurações *rootless* para Docker, pelo que não se deve assumir que Docker implica sempre execução privilegiada.

---

## 8. OCI

**OCI — Open Container Initiative** surge neste módulo para enquadrar a existência de especificações comuns no ecossistema de containers.

De forma conceptual:

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

Nesta sessão é suficiente compreender este enquadramento.

---

## 9. Imagens e Containers

Uma distinção fundamental é:

> **Uma imagem não é um container.**

A imagem representa a base utilizada para criar uma ou várias instâncias de containers.

```text
             Imagem
               │
        ┌──────┼──────┐
        ▼      ▼      ▼
   Container Container Container
       A         B        C
```

Uma mesma imagem pode, portanto, originar vários containers independentes.

---

## 10. Tags

As imagens podem ser identificadas através de **tags**.

Conceptualmente:

```text
nginx
nginx:1.27
nginx:latest
```

As tags permitem identificar diferentes referências de uma imagem.

O seu aprofundamento, incluindo versionamento de imagens, será realizado posteriormente na formação.

---

## 11. Image Registries

Um **image registry** permite armazenar e disponibilizar imagens de containers.

O fluxo conceptual é:

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

---

## 12. Networking de Containers

Uma aplicação executada num container pode necessitar de comunicar:

- com outros containers;
- com outros sistemas;
- com serviços externos;
- com utilizadores.

Nesta sessão é introduzido apenas o conceito básico de networking e exposição de portas.

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

A gestão avançada de networking não faz parte dos objetivos desta primeira sessão.

---

## 13. Armazenamento Efémero

Os containers devem ser encarados como componentes que podem ser criados, destruídos e substituídos.

Isto levanta uma questão importante:

**O que acontece aos dados quando o container desaparece?**

Nem todos os dados de uma aplicação devem ter o mesmo ciclo de vida do container.

---

## 14. Volumes

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

A mensagem fundamental é:

> **O ciclo de vida do container não deve ser confundido com o ciclo de vida dos dados.**

### Criar um volume

```bash
docker volume create dados-demo
```

### Consultar volumes

```bash
docker volume ls
```

Durante a componente prática deverá ser validado que os dados podem permanecer disponíveis após a recriação de um container.

---

## 15. Princípios Básicos de Segurança

Nesta primeira abordagem devem ser retidos alguns princípios:

- utilizar imagens de origem confiável;
- minimizar componentes desnecessários;
- evitar privilégios superiores aos necessários;
- manter as imagens atualizadas;
- não incluir credenciais nas imagens;
- limitar a exposição desnecessária de serviços.

A segurança será aprofundada nas sessões posteriores.

### Exemplo de má prática

Evite introduzir credenciais diretamente num comando, num ficheiro de imagem ou numa configuração que possa ficar exposta:

```bash
docker run -e DB_PASSWORD=secret123 nginx
```

Neste exemplo, a credencial foi escrita explicitamente no comando. Em ambientes reais, os segredos devem ser fornecidos através de mecanismos apropriados de gestão de credenciais e configuração segura. Em Kubernetes, os **Secrets** serão abordados numa sessão posterior.

---

# Síntese do Módulo 1

No final deste módulo deverá conseguir estabelecer a seguinte relação:

```text
Imagem
   ↓
Container Runtime
   ↓
Container
   ↓
Aplicação
```

e compreender que:

```text
Container ≠ Imagem

Container ≠ Máquina Virtual

Dados ≠ Ciclo de vida do Container
```

---

# Exercício de Consolidação — Módulo 1

Responda às seguintes questões:

1. Qual é a principal diferença arquitetural entre uma VM e um container?
2. O que distingue uma imagem de um container?
3. Qual é a função de um container runtime?
4. Para que serve um image registry?
5. Porque podem ser necessários volumes?
6. Que problema existe em guardar dados importantes exclusivamente dentro do container?
7. Indique dois princípios básicos de segurança associados à utilização de containers.

---

# Transição do Módulo 1 para o Módulo 2

Até aqui trabalhámos sobretudo com **containers isolados** e com as ferramentas necessárias para os executar.

Quando o número de containers aumenta para dezenas ou centenas, distribuídos por vários servidores, surgem novos desafios: decidir onde executar cada workload, manter réplicas, substituir instâncias que falham, expor serviços, gerir alterações e preservar o estado pretendido.

É esta necessidade de **gestão coordenada em escala** que conduz ao conceito de **orquestração** e, nesta formação, ao Kubernetes.

---

# Módulo 2 — Fundamentos e Arquitetura Kubernetes

O segundo módulo introduz Kubernetes e estabelece a ligação entre a execução de containers individuais e a necessidade de gerir aplicações distribuídas.

Abrange Kubernetes, princípios cloud-native, arquitetura do cluster, Control Plane, Worker Nodes, API, `kubectl`, contextos, `kubeconfig`, YAML, manifests, Namespaces, Pods, labels, selectors, annotations e principais objetos Kubernetes.

---

## 16. Da Containerização à Orquestração

Até este momento trabalhámos essencialmente com containers individuais.

Considere agora um ambiente com vários servidores:

```text
Servidor 1 → 20 containers
Servidor 2 → 30 containers
Servidor 3 → 25 containers
Servidor 4 → 40 containers
```

Começam a surgir novas questões:

- onde deverá ser executada cada aplicação?
- como manter várias instâncias?
- o que acontece se um servidor falhar?
- como substituir containers que deixam de funcionar?
- como disponibilizar as aplicações?
- como gerir alterações?
- como controlar centenas ou milhares de recursos?

A questão orientadora é:

> **Já conseguimos executar containers. Como gerimos dezenas ou centenas de containers distribuídos por vários servidores?**

É neste contexto que surge a **orquestração**.

---

## 17. Kubernetes

Kubernetes é a plataforma de orquestração utilizada ao longo desta formação.

Nesta introdução devem ser compreendidos quatro conceitos particularmente importantes:

### Automatização

Determinadas tarefas de gestão podem ser realizadas automaticamente pela plataforma.

### Configuração declarativa

O utilizador descreve o estado que pretende obter.

### Estado desejado

Representa a configuração que deverá existir no cluster.

### Reconciliação

Kubernetes procura continuamente aproximar o estado real do estado pretendido.

---

## 18. Arquitetura Geral de Kubernetes

Um cluster pode ser inicialmente compreendido através de dois grandes conjuntos:

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

## 19. Control Plane

O **Control Plane** representa a área de controlo do cluster.

Nesta primeira sessão interessa compreender que é responsável pelas funções relacionadas com a gestão global e controlo do estado do ambiente Kubernetes.

Os componentes internos serão aprofundados noutras fases da formação.

---

## 20. Worker Nodes

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

---

## 21. Kubernetes API

A interação com o cluster é realizada através da **Kubernetes API**.

Nesta fase, o fluxo mais importante é:

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

O formando não deverá tentar memorizar todos os componentes internos nesta sessão. O objetivo é compreender este fluxo de interação.

---

## 22. kubectl

`kubectl` é a ferramenta de linha de comandos que será utilizada ao longo da formação para interagir com Kubernetes.

### Consultar informação do cluster

```bash
kubectl cluster-info
```

### Consultar nodes

```bash
kubectl get nodes
```

### Consultar o contexto atual

```bash
kubectl config current-context
```

### Consultar os contextos disponíveis

```bash
kubectl config get-contexts
```

### Alterar o contexto

Quando aplicável:

```bash
kubectl config use-context <contexto>
```

---

## 23. kubeconfig

Para que `kubectl` consiga saber com que ambiente Kubernetes deverá comunicar é utilizada informação presente no **kubeconfig**.

Conceptualmente:

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

Nesta sessão pretende-se apenas compreender a finalidade desta configuração.

Autenticação e autorização serão aprofundadas posteriormente.

---

## 24. Contextos

Um **contexto** permite definir a combinação de informações utilizada pelo `kubectl` para trabalhar com determinado ambiente.

O comando:

```bash
kubectl config current-context
```

permite verificar qual está atualmente selecionado.

Para consultar todos:

```bash
kubectl config get-contexts
```

---

## 25. YAML

Kubernetes utiliza frequentemente documentos escritos em **YAML** para descrever recursos.

Um exemplo simples:

```yaml
nome: exemplo
tipo: demonstracao
```

A indentação é relevante em YAML e representa a estrutura dos dados.

Nesta sessão é necessária apenas a compreensão suficiente para interpretar manifests Kubernetes simples.

---

## 26. Manifests Kubernetes

Um **manifest** descreve declarativamente um recurso que pretendemos criar ou configurar no cluster.

É frequente encontrar campos como:

```yaml
apiVersion:
kind:
metadata:
spec:
```

| Campo | Significado introdutório |
|---|---|
| `apiVersion` | Versão da API utilizada |
| `kind` | Tipo de recurso |
| `metadata` | Identificação e metadados |
| `spec` | Estado ou configuração pretendida |

---

## 27. Exemplo de Manifest

O manifest de referência da sessão é:

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

### Leitura guiada do manifest

| Campo | Exemplo | Pergunta orientadora |
|---|---|---|
| `apiVersion` | `v1` | Que versão da API estou a utilizar? |
| `kind` | `Pod` | Que tipo de recurso estou a criar? |
| `metadata.name` | `web-demo` | Qual é o nome do recurso? |
| `metadata.namespace` | `formacao` | Em que Namespace será criado? |
| `metadata.labels` | `app: web` | Como posso identificar e selecionar este recurso? |
| `spec.containers` | `name: web` | Que container será executado? |
| `spec.containers[].image` | `nginx` | Que imagem será utilizada? |

Ao analisar este manifest deverá conseguir responder:

1. Que recurso está a ser criado?
2. Qual é o nome do recurso?
3. Em que Namespace será criado?
4. Qual é a imagem utilizada?
5. Que labels possui?
6. Onde se encontra definido o estado pretendido?

---

## 28. Pods

O **Pod** é um dos objetos fundamentais de Kubernetes.

Nesta sessão basta compreender o Pod como a unidade onde são executados containers.

```text
Pod
│
└── Container
       │
       └── Aplicação
```

O conceito será aprofundado posteriormente.

---

## 29. Namespaces

Um **Namespace** permite organizar recursos dentro de um cluster.

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

### Criar um Namespace

```bash
kubectl create namespace formacao
```

### Consultar Namespaces

```bash
kubectl get ns
```

---

## 30. Labels

As **labels** são pares chave/valor associados aos recursos.

Exemplo:

```yaml
labels:
  app: web
  environment: formacao
```

Podem ser utilizadas para identificar e organizar recursos.

---

## 31. Selectors

Os **selectors** permitem selecionar recursos através das labels.

Por exemplo:

```bash
kubectl get pods -n formacao -l app=web
```

A relação é:

```text
Recurso
   │
   └── Label: app=web
             ▲
             │
          Selector
```

---

## 32. Annotations

As **annotations** permitem também associar metadados aos recursos.

Nesta sessão pretende-se apenas introduzir o conceito.

O seu aprofundamento não está previsto para esta fase inicial.

---

## 33. Principais Objetos Kubernetes

Ao longo da formação serão utilizados vários objetos.

Nesta sessão devem ser apresentados apenas como um **mapa de navegação**:

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

---

# Laboratório — Módulo 2

## Objetivo

Consultar o ambiente Kubernetes, identificar o contexto ativo, criar recursos básicos através de YAML e utilizar labels e selectors.

## Pré-requisitos

Antes de iniciar o laboratório, confirme que:

- `kubectl` está instalado e configurado;
- existe acesso a um cluster Kubernetes funcional;
- o contexto ativo é o contexto previsto para a formação;
- o utilizador tem permissões para consultar nodes e criar Namespaces e Pods;
- a imagem utilizada no exercício está acessível a partir do cluster.

Valide inicialmente:

```bash
kubectl get nodes
kubectl config current-context
```

O primeiro comando deverá devolver pelo menos um node acessível e o segundo deverá apresentar o contexto esperado.

---

## Tarefa 1 — Consultar o Cluster

```bash
kubectl get nodes
kubectl get namespaces
kubectl config current-context
```

Identifique:

- os nodes existentes;
- os Namespaces;
- o contexto ativo.

---

## Tarefa 2 — Criar um Namespace

```bash
kubectl create namespace formacao
```

Confirmar:

```bash
kubectl get ns
```

---

## Tarefa 3 — Criar um Pod através de YAML

Crie o ficheiro:

```text
pod-demo.yaml
```

com:

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

---

## Tarefa 4 — Consultar Labels

```bash
kubectl get pods -n formacao --show-labels
```

---

## Tarefa 5 — Utilizar um Selector

```bash
kubectl get pods -n formacao -l app=web
```

---

## Tarefa 6 — Limpeza do Ambiente

```bash
kubectl delete namespace formacao
```

---

# Checklist de Validação da Sessão

| Competência | Evidência esperada | Critério de sucesso |
|---|---|---|
| Executar um container | Container em execução | `docker ps` apresenta o container `web-demo` com estado de execução |
| Consultar logs | Logs identificados | `docker logs web-demo` devolve saída sem erro de acesso ao container |
| Criar volume | Volume visível | `docker volume ls` apresenta `dados-demo` |
| Validar persistência | Dados mantidos | Os dados continuam disponíveis depois de remover e recriar o container que utiliza o volume |
| Consultar cluster | Nodes e Namespaces identificados | `kubectl get nodes` e `kubectl get namespaces` devolvem os recursos esperados |
| Identificar contexto | Contexto atual reconhecido | `kubectl config current-context` apresenta o contexto previsto |
| Criar Namespace | Namespace visível | `kubectl get ns` apresenta `formacao` |
| Criar Pod por YAML | Pod no estado esperado | `kubectl get pods -n formacao` apresenta `web-demo` com `STATUS=Running` |
| Consultar labels | Labels apresentadas | `kubectl get pods -n formacao --show-labels` apresenta `app=web` e `environment=formacao` |
| Utilizar selector | Recurso corretamente filtrado | `kubectl get pods -n formacao -l app=web` devolve apenas o Pod correspondente |

---

# Resumo do Módulo 1

O formando deverá reter:

- uma VM e um container possuem arquiteturas diferentes;
- containers partilham o kernel do host;
- uma imagem serve de base à criação de containers;
- o runtime participa na execução dos containers;
- Docker e Podman são ferramentas do ecossistema;
- registries permitem armazenar e disponibilizar imagens;
- containers podem comunicar através de redes;
- volumes permitem desacoplar os dados do ciclo de vida do container;
- devem ser aplicados princípios básicos de segurança.

---

# Resumo do Módulo 2

O formando deverá reter:

- Kubernetes permite gerir containers em escala;
- um cluster possui Control Plane e Worker Nodes;
- a Kubernetes API constitui o ponto central de interação;
- `kubectl` permite interagir com essa API;
- `kubeconfig` contém informação necessária à configuração de acesso;
- contextos permitem selecionar ambientes;
- manifests YAML descrevem recursos;
- Pods são unidades fundamentais de execução;
- Namespaces organizam recursos;
- labels identificam recursos;
- selectors permitem selecioná-los.

---

# Exercício Final de Consolidação

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
6. Qual seria o selector para selecionar apenas recursos com `app=api`?
7. Que comando utilizaria para aplicar este manifest?
8. Que comando utilizaria para consultar o Pod?
9. Como apresentaria as labels?
10. Qual seria uma forma de remover todos os recursos criados neste Namespace?
11. **Bónus:** execute `kubectl describe pod api-demo -n formacao` e identifique uma secção que apresente o estado atual do container.

Depois de responder, valide as soluções no ambiente Kubernetes.

A questão bónus permite começar a distinguir, de forma introdutória, o **estado desejado** descrito no manifest do **estado observado** no cluster.

---

# Questões de Revisão da Sessão 1

## Módulo 1

1. Qual é a principal diferença arquitetural entre uma VM e um container?
2. Qual é a diferença entre imagem e container?
3. Qual é a função de um container runtime?
4. Para que serve um registry?
5. Para que serve um volume?
6. Porque não devemos incluir credenciais dentro das imagens?

## Módulo 2

7. Porque é necessário um orquestrador?
8. Qual é o papel geral do Control Plane?
9. Onde são executados os workloads?
10. Para que serve `kubectl`?
11. Para que serve o `kubeconfig`?
12. O que representa `kind` num manifest?
13. Para que serve um Namespace?
14. Qual é a relação entre uma label e um selector?

---

# Conceitos-Chave

## Módulo 1

```text
Virtualização
Máquina Virtual
Hipervisor
Container
Container Runtime
Docker
Podman
OCI
Imagem
Tag
Image Registry
Networking
Volume
Persistência
```

## Módulo 2

```text
Orquestração
Kubernetes
Cluster
Control Plane
Worker Node
Kubernetes API
kubectl
kubeconfig
Context
YAML
Manifest
Namespace
Pod
Label
Selector
Annotation
```

---

# Continuidade da Formação

Com esta organização, a separação pedagógica fica clara:

```text
SESSÃO 1
│
├── MÓDULO 1
│   Fundamentos de Containers
│
│   Virtualização
│        ↓
│   Containers
│        ↓
│   Runtimes
│        ↓
│   Imagens
│        ↓
│   Networking / Volumes
│
└── MÓDULO 2
    Fundamentos e Arquitetura Kubernetes

    Necessidade de Orquestração
             ↓
         Kubernetes
             ↓
          Cluster
             ↓
      Control Plane / Workers
             ↓
        API / kubectl
             ↓
        YAML / Manifests
             ↓
    Pods / Namespaces / Labels
```

A Sessão 1 tem sobretudo o objetivo de **compreender** os fundamentos de Containers e Kubernetes, preparando a progressão para a Sessão 2, dedicada à construção, containerização e configuração de aplicações.
