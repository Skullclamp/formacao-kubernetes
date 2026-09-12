# Manual do Formando

**Módulo 1 — Fundamentos de Containers**  
**Módulo 2 — Fundamentos e Arquitetura Kubernetes**

---

# Índice

1. [Módulo 1 — Fundamentos de Containers](#módulo-1--fundamentos-de-containers)
   - [1. Da máquina física à virtualização](#1-da-máquina-física-à-virtualização)
   - [2. Containers: o modelo de execução](#2-containers-o-modelo-de-execução)
   - [3. Como o isolamento funciona](#3-como-o-isolamento-funciona)
   - [4. Containers vs. máquinas virtuais](#4-containers-vs-máquinas-virtuais)
   - [5. Container runtimes, Docker, Podman, containerd e runc](#5-container-runtimes-docker-podman-containerd-e-runc)
   - [6. OCI e interoperabilidade](#6-oci-e-interoperabilidade)
   - [7. Imagens, layers, tags, digests e registries](#7-imagens-layers-tags-digests-e-registries)
   - [8. Networking de containers](#8-networking-de-containers)
   - [9. Armazenamento, volumes e persistência](#9-armazenamento-volumes-e-persistência)
   - [10. Segurança fundamental de containers](#10-segurança-fundamental-de-containers)
   - [11. Síntese e consolidação do Módulo 1](#11-síntese-e-consolidação-do-módulo-1)
2. [Módulo 2 — Fundamentos e Arquitetura Kubernetes](#módulo-2--fundamentos-e-arquitetura-kubernetes)
   - [12. Porque precisamos de orquestração](#12-porque-precisamos-de-orquestração)
   - [13. Modelo declarativo, estado desejado e reconciliação](#13-modelo-declarativo-estado-desejado-e-reconciliação)
   - [14. Arquitetura de um cluster Kubernetes](#14-arquitetura-de-um-cluster-kubernetes)
   - [15. Control Plane em detalhe](#15-control-plane-em-detalhe)
   - [16. Worker Nodes em detalhe](#16-worker-nodes-em-detalhe)
   - [17. Kubernetes API e percurso de um pedido](#17-kubernetes-api-e-percurso-de-um-pedido)
   - [18. kubectl, kubeconfig e contexts](#18-kubectl-kubeconfig-e-contexts)
   - [19. YAML e manifests Kubernetes](#19-yaml-e-manifests-kubernetes)
   - [20. Objetos, spec, status e metadata](#20-objetos-spec-status-e-metadata)
   - [21. Pods em detalhe](#21-pods-em-detalhe)
   - [22. Namespaces](#22-namespaces)
   - [23. Labels, selectors e annotations](#23-labels-selectors-e-annotations)
   - [24. Mapa dos principais objetos Kubernetes](#24-mapa-dos-principais-objetos-kubernetes)
   - [25. O que acontece num kubectl apply](#25-o-que-acontece-num-kubectl-apply)
   - [26. Síntese e consolidação do Módulo 2](#26-síntese-e-consolidação-do-módulo-2)
3. [27. Exercício integrado](#27-exercício-integrado)
4. [28. Guia rápido Docker e Podman](#28-guia-rápido-docker-e-podman)
5. [29. Guia rápido kubectl](#29-guia-rápido-kubectl)
6. [30. Glossário](#30-glossário)
7. [31. Espaço para notas](#31-espaço-para-notas)
8. [32. Recursos e leituras complementares](#32-recursos-e-leituras-complementares)

---

# Módulo 1 — Fundamentos de Containers

# 1. Da máquina física à virtualização

## 1.1. O modelo tradicional

Num modelo simples, uma aplicação é instalada diretamente sobre o sistema operativo de um servidor:

```text
Hardware
   │
Sistema Operativo
   │
├── Aplicação A
├── Aplicação B
└── Aplicação C
```

Este modelo é perfeitamente válido, mas coloca várias aplicações no mesmo contexto de sistema operativo. Dependências, versões de bibliotecas, portas, utilizadores e configurações podem interferir entre si.

Exemplo: a Aplicação A necessita de uma versão de uma biblioteca incompatível com a versão exigida pela Aplicação B. Se ambas forem instaladas diretamente no mesmo sistema, a equipa tem de gerir o conflito.

## 1.2. Virtualização

A virtualização introduz uma camada de abstração que permite executar várias máquinas virtuais sobre a mesma infraestrutura física.

```text
Aplicações      Aplicações      Aplicações
    │               │               │
Guest OS A      Guest OS B      Guest OS C
    │               │               │
     └────────── Hypervisor ─────────┘
                    │
                 Hardware
```

Cada VM possui, de forma geral:

- CPU virtual;
- memória virtual;
- interfaces de rede virtuais;
- discos virtuais;
- um sistema operativo convidado completo;
- processos e serviços próprios.

### Hipervisores

Conceptualmente, distinguem-se frequentemente:

- **Type 1 / bare-metal** — executa diretamente sobre o hardware ou como camada de virtualização principal;
- **Type 2 / hosted** — executa sobre um sistema operativo anfitrião.

Esta classificação ajuda a distinguir onde se posiciona a camada de virtualização e como se relaciona com o sistema operativo anfitrião e o hardware.

> **Essencial**  
> Uma VM virtualiza um computador suficientemente completo para executar um sistema operativo convidado. Um container isola processos que continuam a utilizar o kernel do sistema onde são executados.

---

# 2. Containers: o modelo de execução

## 2.1. Um container é um processo isolado, não uma VM pequena

Um erro frequente consiste em imaginar um container como uma máquina virtual muito pequena. Esta analogia pode ajudar nos primeiros minutos, mas torna-se rapidamente enganadora.

Num host Linux, uma aplicação containerizada continua, em última análise, a ser executada como um ou mais **processos Linux** pelo kernel do host.

```text
Aplicação no container
        │
        ▼
Processo(s) Linux
        │
        ▼
Isolamento e limites
        │
        ▼
Kernel Linux do host
        │
        ▼
Hardware
```

O container cria a perceção de um ambiente próprio: árvore de processos, filesystem, interfaces de rede, hostname, utilizadores, limites de recursos, etc. Essa perceção é construída usando mecanismos do sistema operativo.

## 2.2. O que existe dentro de uma imagem/container?

Uma imagem de container pode incluir:

- binários da aplicação;
- bibliotecas e dependências;
- ficheiros de configuração base;
- comandos de arranque;
- variáveis e metadados;
- um filesystem de utilizador mínimo.

Mas, num container Linux normal, **não inclui um kernel Linux independente**.

É precisamente por isso que containers Linux dependem das funcionalidades do kernel Linux onde são executados. Em ambientes como Docker Desktop num sistema não Linux, existe normalmente uma camada Linux/VM que fornece esse kernel.

> **Importante**  
> “Imagem contém um sistema operativo” é uma simplificação perigosa. Uma imagem Linux pode conter *user space* de uma distribuição — por exemplo, ferramentas e bibliotecas de Ubuntu ou Alpine — mas não transporta um kernel Linux próprio como uma VM.

---

# 3. Como o isolamento funciona

## 3.1. Namespaces Linux

Namespaces permitem que um conjunto de processos tenha uma visão isolada de determinados recursos do sistema.

Conceptualmente:

```text
Processo do container
       │
       ├── PID namespace      → processos
       ├── network namespace  → interfaces, rotas, portas
       ├── mount namespace    → mounts/filesystem
       ├── UTS namespace      → hostname/domain name
       ├── IPC namespace      → IPC
       └── user namespace     → IDs de utilizador/grupo
```

Isto não significa que cada container tenha obrigatoriamente todos os namespaces configurados da mesma maneira. O runtime decide a configuração de acordo com as opções pedidas.

### Exemplo mental: PID namespace

No host podem existir milhares de processos. Dentro de um container, a aplicação pode ver apenas a árvore de processos pertencente ao seu namespace.

```text
HOST
PID 1    systemd
PID 500  dockerd
PID 900  nginx do container

CONTAINER
PID 1    nginx
```

O mesmo processo pode ter identificadores diferentes conforme o namespace a partir do qual é observado.

## 3.2. cgroups

Namespaces respondem sobretudo à pergunta **“o que consegue este processo ver?”**. Os **control groups (cgroups)** ajudam a responder a **“que quantidade de recursos pode consumir ou como é contabilizado?”**.

Podem ser usados para controlar ou contabilizar recursos como:

- CPU;
- memória;
- I/O;
- número de processos, dependendo da configuração e versão de cgroups.

```text
Container
   │
   ├── CPU limit / weight
   ├── Memory limit
   └── outros controlos
        │
        ▼
     cgroups
        │
        ▼
      kernel
```

> **Por baixo do capô**  
> Namespaces e cgroups resolvem problemas diferentes. Um processo pode estar isolado por namespaces e, mesmo assim, consumir demasiados recursos se não existirem limites adequados.

## 3.3. Capabilities

Tradicionalmente, em Unix/Linux, o utilizador `root` concentra um conjunto muito vasto de privilégios. Linux capabilities dividem parte desses privilégios em unidades menores.

Um runtime pode remover capabilities desnecessárias em vez de conceder um conjunto total de privilégios administrativos.

Isto suporta o princípio de **menor privilégio**.

## 3.4. seccomp, AppArmor e SELinux

Além de namespaces e cgroups, podem existir camadas adicionais de defesa:

- **seccomp** — limita chamadas de sistema permitidas;
- **AppArmor** — aplica perfis de controlo de acesso;
- **SELinux** — aplica políticas de controlo de acesso obrigatório;
- **user namespaces** — permitem mapear identidades do container para identidades menos privilegiadas no host.

O isolamento de containers resulta da combinação de **várias camadas complementares**.

> **Essencial**  
> Container não significa automaticamente “fronteira de segurança equivalente a uma VM”. Containers partilham o kernel e devem ser configurados com uma postura de defesa em profundidade.

---

# 4. Containers vs. máquinas virtuais

| Dimensão | Máquina Virtual | Container |
|---|---|---|
| Kernel | Kernel próprio do Guest OS | Normalmente partilha o kernel do host |
| Unidade principal | Máquina virtual | Processo(s) isolado(s) |
| Arranque | Normalmente mais lento | Normalmente muito rápido |
| Imagem | Inclui SO convidado completo | Inclui aplicação, dependências e user space necessário |
| Overhead | Superior | Inferior em muitos cenários |
| Densidade | Menor | Maior em muitos cenários |
| Isolamento | Forte fronteira baseada em virtualização | Isolamento baseado em mecanismos do kernel |
| Portabilidade | VM depende do formato/plataforma do hypervisor | Imagem depende também de SO/arquitetura e runtime compatível |
| Utilização típica | Workloads que requerem SO/kernel próprio ou forte separação | Aplicações e serviços empacotados de forma reproduzível |

## 4.1. Não são tecnologias mutuamente exclusivas

Um cenário muito comum é:

```text
Servidor físico ou cloud
        │
        ▼
       VMs
        │
        ▼
Linux em cada VM
        │
        ▼
Container runtime
        │
        ▼
Containers / Kubernetes
```

Kubernetes em cloud e em datacenter é frequentemente executado sobre VMs.

## 4.2. Pergunta de decisão

Em vez de perguntar “qual é melhor?”, pergunte:

- preciso de outro kernel ou outro sistema operativo?
- qual é o nível de isolamento requerido?
- o workload deve arrancar rapidamente e ser replicado frequentemente?
- preciso de distribuir o mesmo artefacto por múltiplos ambientes?
- existem dependências legacy difíceis de containerizar?
- existe uma política organizacional que imponha VM, container ou ambos?

### Atividade — VM ou container?

Analise e justifique:

1. sistema que requer kernel diferente do host;
2. API web stateless;
3. microsserviço;
4. aplicação legacy com dependências rígidas;
5. ambiente temporário de testes;
6. workload com forte requisito de isolamento entre clientes.

Não existem respostas absolutas para todos os casos. O objetivo é justificar tecnicamente a decisão.

---

# 5. Container runtimes, Docker, Podman, containerd e runc

## 5.1. O problema da palavra “runtime”

No ecossistema de containers, a palavra **runtime** pode referir-se a camadas diferentes. Para evitar confusão, é útil pensar em níveis.

```text
Experiência do utilizador / gestão
Docker CLI / Podman CLI
        │
        ▼
Gestão de imagens e lifecycle
Docker Engine / Podman / containerd / CRI-O
        │
        ▼
Runtime OCI de baixo nível
runc (exemplo)
        │
        ▼
Kernel
```

As implementações concretas variam. O objetivo do diagrama é mostrar que “executar um container” envolve mais do que um único binário.

## 5.2. Docker

O Docker oferece uma experiência integrada para:

- obter e gerir imagens;
- criar e executar containers;
- gerir redes;
- gerir volumes;
- expor uma API;
- integrar build, distribuição e execução.

### O que acontece conceptualmente num `docker run`?

Num Docker Engine Linux típico:

```text
docker CLI
    │
    ▼
Docker API
    │
    ▼
dockerd
    │
    ▼
containerd
    │
    ▼
containerd-shim
    │
    ▼
runc
    │
    ▼
Linux kernel
    │
    ├── namespaces
    ├── cgroups
    ├── capabilities
    └── filesystem / network
    │
    ▼
processo da aplicação
```

Esta representação é propositadamente conceptual. Versões, plataformas e integrações podem alterar detalhes internos.

### Porque existe `runc`?

`runc` é uma implementação de referência da OCI Runtime Specification. Recebe uma configuração/bundle OCI e cria o ambiente de execução utilizando mecanismos do sistema operativo.

### Porque existe `containerd`?

`containerd` gere funções de lifecycle e gestão de imagens/containers e utiliza runtimes de baixo nível para a criação efetiva do processo isolado.

> **Essencial**  
> Docker não é “o mecanismo de isolamento”. A plataforma coordena ferramentas e pede ao kernel que aplique mecanismos de isolamento e controlo.

## 5.3. Podman

Podman fornece uma CLI muito semelhante à do Docker para muitas operações comuns:

```bash
docker run nginx
podman run nginx
```

Uma diferença arquitetural importante é que Podman não necessita de um **daemon central persistente** para o lifecycle normal dos containers locais. Também foi desenhado com forte suporte para execução **rootless**.

Isto não significa que Docker seja sempre executado como root: Docker também possui modo rootless. Significa apenas que a arquitetura e o modelo operacional das ferramentas são diferentes.

## 5.4. Ciclo de vida básico

```text
Imagem
  │
  ▼
create / run
  │
  ▼
Container criado
  │
  ▼
Processo iniciado
  │
  ▼
running
  │
  ▼
stop
  │
  ▼
stopped
  │
  ▼
remove
```

É importante distinguir:

- **imagem** — artefacto utilizado para criar o container;
- **container** — instância configurada a partir da imagem;
- **processo** — código efetivamente em execução dentro do contexto do container.

## 5.5. Comandos essenciais

```bash
docker run --name web-demo -d nginx
docker ps
docker ps -a
docker logs web-demo
docker inspect web-demo
docker stop web-demo
docker start web-demo
docker rm web-demo
```

Equivalentes básicos com Podman:

```bash
podman run --name web-demo -d nginx
podman ps
podman ps -a
podman logs web-demo
podman inspect web-demo
podman stop web-demo
podman start web-demo
podman rm web-demo
```

### `run` vs. `create` + `start`

Conceptualmente:

```text
docker run
   ≈
docker create
+
docker start
```

`create` prepara o container sem iniciar o processo; `start` inicia um container já criado.

---
# 6. OCI e interoperabilidade

## 6.1. Porque foi necessária a OCI?

À medida que o ecossistema de containers cresceu, tornou-se importante evitar que cada fornecedor utilizasse formatos e mecanismos completamente incompatíveis.

A **Open Container Initiative (OCI)** define standards abertos para permitir interoperabilidade.

Atualmente, três especificações são particularmente relevantes:

| Especificação | Finalidade |
|---|---|
| **OCI Image Specification** | Define como uma imagem OCI é representada |
| **OCI Runtime Specification** | Define configuração, ambiente de execução e lifecycle de um container |
| **OCI Distribution Specification** | Define um protocolo/API para distribuição de conteúdo, incluindo imagens |

## 6.2. Relação conceptual

```text
Sistema de build
      │
      ▼
OCI Image
      │
      ▼
Registry compatível
      │
      ▼
Pull
      │
      ▼
Runtime / engine
      │
      ▼
OCI runtime bundle
      │
      ▼
runc ou outro runtime OCI
      │
      ▼
Container
```

## 6.3. OCI não é Docker

OCI é uma iniciativa de normalização. Docker, Podman, containerd, CRI-O e muitos outros projetos podem utilizar formatos e interfaces compatíveis com estas especificações.

Esta separação ajuda a explicar por que é possível:

```text
Build com Docker
      ↓
Push para registry
      ↓
Pull num cluster Kubernetes
      ↓
Execução com containerd/CRI-O
```

## 6.4. OCI vs. CRI

São conceitos diferentes:

- **OCI** normaliza aspetos de imagens, runtime e distribuição;
- **CRI — Container Runtime Interface** é a interface/protocolo usada por Kubernetes entre `kubelet` e o runtime compatível com CRI.

```text
Kubernetes
   │
 kubelet
   │
   │ CRI
   ▼
containerd / CRI-O
   │
   │ OCI runtime
   ▼
runc / outro
```

> **Aprofundamento**  
> Kubernetes pode disponibilizar diferentes runtimes no mesmo cluster através de `RuntimeClass`, permitindo selecionar uma classe de runtime para workloads com requisitos específicos de isolamento ou execução.

---

# 7. Imagens, layers, tags, digests e registries

## 7.1. O que é uma imagem?

Uma imagem é um artefacto **read-only** que contém os elementos necessários para criar o filesystem e a configuração inicial de um container.

Uma forma útil de pensar:

```text
Container Image
│
├── Manifest / metadados
├── Configuração
└── Filesystem layers
       ├── Layer 1
       ├── Layer 2
       └── Layer 3
```

Dependendo do formato e ferramenta, existem detalhes adicionais, mas este modelo é suficiente para compreender o funcionamento.

## 7.2. Layers

Imagens são normalmente construídas como uma sequência de **layers imutáveis**.

Exemplo conceptual:

```text
Layer 4  aplicação
Layer 3  dependências da aplicação
Layer 2  bibliotecas adicionais
Layer 1  filesystem base
```

O runtime apresenta estas layers como um filesystem coerente ao container.

Quando o container precisa de escrever, é adicionada uma camada gravável associada àquele container:

```text
Container writable layer    ← alterações em runtime
-------------------------
Image layer 4               ← read-only
Image layer 3               ← read-only
Image layer 2               ← read-only
Image layer 1               ← read-only
```

> **Por baixo do capô**  
> Tecnologias de filesystem/driver, como OverlayFS em muitos sistemas Linux, permitem apresentar várias layers como uma vista unificada. O mecanismo concreto depende da plataforma e configuração.

## 7.3. Copy-on-write

Quando um ficheiro existente numa layer read-only precisa de ser alterado, o sistema pode copiar esse ficheiro para uma camada gravável e aplicar aí a alteração. Este princípio é frequentemente descrito como **copy-on-write**.

Isto contribui para reutilização eficiente de layers entre múltiplas imagens e containers.

## 7.4. Imagem vs. container

```text
Imagem
  │
  ├── Container A + writable layer A
  ├── Container B + writable layer B
  └── Container C + writable layer C
```

Os três containers podem partir exatamente da mesma imagem e, ainda assim, ter estado gravável diferente.

## 7.5. Nome, repository, tag e digest

Um nome de imagem pode ser lido por componentes:

```text
registry.example.com/equipa/api:1.4.2
└────── registry ──────┘ └repo┘ └tag┘
```

Consoante a convenção e registry, o caminho do repository pode ter mais segmentos.

### Tag

A tag é uma referência legível:

```text
nginx:1.27
api:2026.09
api:latest
```

Uma tag é uma referência que pode ser alterada para apontar para outro conteúdo.

### Digest

Um digest identifica conteúdo de forma criptográfica, normalmente com SHA-256:

```text
nginx@sha256:abc123...
```

A vantagem conceptual é importante:

```text
tag       → referência mutável

digest    → identidade baseada no conteúdo
```

> **Importante**  
> `latest` é apenas uma tag com um nome convencional. Não significa, por definição, “a versão cronologicamente mais recente” e não fornece imutabilidade.

## 7.6. Image registry

Um registry armazena e distribui imagens e outros artefactos compatíveis.

Fluxo simplificado:

```text
Build
  ↓
Tag
  ↓
Push
  ↓
Registry
  ↓
Pull
  ↓
Host / Node
  ↓
Run
```

Um registry pode ter:

- repositories públicos;
- repositories privados;
- autenticação;
- autorização;
- políticas de retenção;
- scanning;
- assinatura/verificação de artefactos;
- replicação e outras funcionalidades empresariais.

## 7.7. O que acontece num `docker pull`?

De forma conceptual:

1. a CLI/engine resolve o nome da imagem;
2. contacta o registry;
3. obtém metadados/manifest aplicável à plataforma;
4. identifica as layers necessárias;
5. descarrega apenas o conteúdo em falta;
6. verifica digests;
7. guarda a imagem localmente para utilização posterior.

A existência de layers partilhadas significa que várias imagens podem reutilizar conteúdo já presente localmente.

---

# 8. Networking de containers

## 8.1. O problema de rede

Um processo dentro de um container precisa frequentemente de:

- receber pedidos;
- comunicar com outros containers;
- contactar bases de dados ou APIs;
- aceder à Internet;
- ser alcançado a partir do host ou de outras máquinas.

## 8.2. Network namespace

Num host Linux, um container pode receber o seu próprio **network namespace**.

Esse namespace pode conter:

- interfaces;
- endereços IP;
- tabela de routing;
- regras e sockets;
- espaço de portas.

Conceptualmente:

```text
Container
   │
network namespace
   │
  eth0
   │
 virtual ethernet
   │
Linux bridge
   │
Host interface
   │
Rede externa
```

## 8.3. Bridge network

Em Docker, a bridge network é um modelo comum para containers num único host.

Uma rede bridge cria um domínio de rede virtual no host. Containers ligados à mesma rede podem comunicar conforme as regras existentes.

Comandos úteis:

```bash
docker network ls
docker network inspect bridge
```

Criar uma rede própria:

```bash
docker network create rede-demo
```

As redes criadas explicitamente pelo utilizador fornecem, entre outras funcionalidades, resolução de nomes entre containers ligados à mesma rede.

## 8.4. Porta da aplicação vs. porta publicada

Suponha que NGINX escuta na porta `80` dentro do container.

Sem publicação:

```text
Host externo   X   container:80
```

Com:

```bash
docker run -d --name web-demo -p 8080:80 nginx
```

passamos a ter:

```text
Cliente
  │
  ▼
Host:8080
  │
  ▼
regra de encaminhamento/NAT
  │
  ▼
Container:80
  │
  ▼
NGINX
```

A sintaxe é:

```text
-p HOST_PORT:CONTAINER_PORT
```

## 8.5. `EXPOSE` não é o mesmo que publicar

Num Dockerfile, `EXPOSE 80` documenta que a aplicação foi concebida para utilizar determinada porta. **Não publica automaticamente essa porta no host.**

A publicação efetiva pode ser feita com `-p`/`--publish`.

## 8.6. Atenção à superfície de exposição

Por omissão, uma publicação como:

```bash
docker run -p 8080:80 nginx
```

pode ficar acessível através das interfaces do host, dependendo da configuração de rede/firewall.

Quando o objetivo é disponibilizar apenas localmente no host, pode usar-se, por exemplo:

```bash
docker run -p 127.0.0.1:8080:80 nginx
```

> **Importante**  
> Publicar uma porta é uma decisão de exposição de rede, não apenas uma conveniência de desenvolvimento.

## 8.7. Pequena experiência opcional

```bash
docker network create rede-demo

docker run -d --name web-a --network rede-demo nginx
```

Se existir uma imagem cliente HTTP disponível no ambiente, pode testar a resolução por nome dentro da mesma rede.

> **Ligação a Kubernetes**  
> Kubernetes utiliza um modelo de networking próprio e integra implementações de rede através da CNI. Sobre essa base surgem mecanismos como Services, DNS, Ingress/Gateway API e NetworkPolicies.

---

# 9. Armazenamento, volumes e persistência

## 9.1. O filesystem gravável do container não é o lugar certo para dados persistentes

Quando um container escreve no seu filesystem sem um mount dedicado, a alteração fica associada à camada gravável daquele container.

```text
Imagem read-only
      +
camada gravável do Container A
```

Quando o container é removido, essa camada é eliminada com ele.

Isto é diferente de **parar** um container: um container parado continua a existir e a sua camada gravável também, até ser removido.

> **Essencial**  
> `docker stop` não é o mesmo que `docker rm`. O problema de persistência surge quando os dados estão acoplados ao ciclo de vida do container e este é eliminado/substituído.

## 9.2. Volumes

Um Docker volume é armazenamento gerido pelo Docker e montado no container.

```text
Container A
    │
    ▼
  Volume
    ▲
    │
Container B
```

O lifecycle do volume é independente do lifecycle de um container individual.

## 9.3. Bind mounts

Um bind mount liga diretamente um ficheiro ou diretório existente no host a um caminho dentro do container.

```text
Host: /srv/app/config
        │
        ▼
Container: /app/config
```

Exemplo:

```bash
docker run --rm \
  --mount type=bind,source="$PWD",target=/work \
  alpine ls -la /work
```

### Volume vs. bind mount

| Aspeto | Volume | Bind mount |
|---|---|---|
| Localização | Gerida pelo Docker | Caminho explícito do host |
| Portabilidade | Maior | Dependente da estrutura do host |
| Gestão | CLI/API Docker | Gestão direta no filesystem |
| Uso típico | Dados persistentes de containers | Desenvolvimento, configs ou integração com ficheiros do host |
| Risco | Controlado pelo mecanismo de volumes | Pode expor caminhos sensíveis do host |

## 9.4. `tmpfs`

Em Linux, um `tmpfs` pode ser usado para dados temporários mantidos em memória e que não devem persistir no disco como um volume normal.

É útil reconhecer que existem diferentes tipos de armazenamento:

```text
Container writable layer → acoplada ao container
Volume                   → persistência gerida
Bind mount               → caminho do host
Tmpfs                     → dados temporários em memória
```

## 9.5. Exemplo reproduzível de persistência

Criar o volume:

```bash
docker volume create dados-demo
```

Confirmar:

```bash
docker volume ls
```

Criar um container temporário que escreve um ficheiro no volume:

```bash
docker run --rm \
  --mount type=volume,source=dados-demo,target=/dados \
  alpine sh -c 'echo "dados persistentes" > /dados/prova.txt'
```

O container terminou e foi removido por causa de `--rm`.

Agora usar **outro container** para ler o mesmo volume:

```bash
docker run --rm \
  --mount type=volume,source=dados-demo,target=/dados \
  alpine cat /dados/prova.txt
```

Saída esperada:

```text
dados persistentes
```

### O que demonstrámos?

```text
Container A criado
      ↓
escreve no volume
      ↓
Container A removido
      ↓
volume continua a existir
      ↓
Container B criado
      ↓
lê os mesmos dados
```

Isto demonstra a mensagem fundamental:

> **O ciclo de vida do container não deve ser confundido com o ciclo de vida dos dados.**

## 9.6. Inspeção

```bash
docker volume inspect dados-demo
```

O comando permite observar metadados do volume. A localização física concreta deve ser tratada como detalhe de implementação e não como API estável a manipular diretamente.

---

# 10. Segurança fundamental de containers

## 10.1. Modelo mental de segurança

Quando uma aplicação é comprometida, interessa limitar o que o processo comprometido consegue fazer.

```text
Aplicação vulnerável
      │
      ▼
Processo no container
      │
      ├── utilizador efetivo
      ├── capabilities
      ├── syscalls permitidas
      ├── filesystem montado
      ├── dispositivos
      ├── rede
      └── credenciais disponíveis
      │
      ▼
impacto potencial
```

## 10.2. Princípios essenciais

### Usar imagens confiáveis

Preferir fontes conhecidas, imagens oficiais/verificadas quando apropriado e processos internos de aprovação.

### Reduzir a superfície de ataque

Quanto menos software desnecessário existir na imagem, menos componentes existem para manter e potencialmente explorar.

### Evitar execução privilegiada

Não utilizar `--privileged` sem justificação técnica muito forte. Esse modo remove várias fronteiras de isolamento.

### Aplicar menor privilégio

Sempre que possível:

- executar como utilizador não-root;
- remover capabilities desnecessárias;
- limitar mounts;
- limitar portas expostas;
- aplicar perfis seccomp/LSM adequados;
- limitar CPU/memória de forma coerente.

### Não incluir segredos na imagem

Não incorporar passwords, tokens, chaves privadas ou outros segredos em Dockerfiles, layers ou ficheiros versionados.

Também não se deve assumir que uma variável de ambiente escrita diretamente numa linha de comandos constitui uma solução segura. Em ambientes reais devem ser usados mecanismos próprios de gestão de segredos e controlado o acesso a esses valores.

### Atualizar e analisar imagens

Imagens devem integrar atualizações de segurança e ser analisadas quanto a vulnerabilidades conhecidas.

### Verificar proveniência e integridade

Em cadeias de fornecimento mais maduras podem ser utilizados:

- assinatura de artefactos;
- verificação de assinatura;
- SBOM;
- políticas de admissão;
- scanning contínuo.

> **Ligação a Kubernetes**  
> Em Kubernetes, estes princípios materializam-se também através de mecanismos como Security Contexts, Service Accounts, RBAC, NetworkPolicies, políticas de admissão e controlos de segurança da cadeia de fornecimento de imagens.

## 10.3. Rootless

Executar ferramentas e containers em modo rootless pode reduzir impacto potencial ao evitar que o daemon/processos disponham dos privilégios administrativos tradicionais do host.

Isto não elimina a necessidade de outras medidas de segurança. Rootless é uma camada adicional, não uma garantia total.

---

# 11. Síntese e consolidação do Módulo 1

## 11.1. Mapa mental

```text
Container
│
├── processo(s)
├── namespaces       → isolamento de vistas/recursos
├── cgroups          → controlo/contabilização de recursos
├── capabilities     → privilégios granulares
├── filesystem       → imagem read-only + camada gravável
├── network          → namespace + interfaces + regras
└── mounts           → volumes / bind mounts / tmpfs

Execução
│
├── Docker / Podman
├── containerd / CRI-O
└── runc / OCI runtime

Distribuição
│
├── imagem
├── tag
├── digest
└── registry
```

## 11.2. Questões de consolidação

1. Porque é incorreto dizer que um container Linux possui sempre um Linux completo próprio?
2. Que diferença existe entre namespaces e cgroups?
3. Porque é que uma VM tende a fornecer uma fronteira de isolamento diferente da de um container?
4. Qual é a diferença entre Docker, containerd e runc?
5. Que problema resolve a OCI?
6. Qual é a diferença entre OCI e CRI?
7. Porque pode uma imagem construída com Docker ser executada por um cluster que usa containerd?
8. O que é uma layer?
9. Qual é a diferença entre tag e digest?
10. Porque é perigoso depender de `latest` como identidade imutável?
11. Qual é a diferença entre `EXPOSE` e `-p`?
12. O que acontece aos dados da camada gravável quando um container é removido?
13. Qual é a diferença entre volume e bind mount?
14. Porque deve evitar-se `--privileged`?
15. Indique cinco medidas de segurança aplicáveis ao ciclo de vida de containers.

## 11.3. Notas do formando — Módulo 1

........................................................................................................

........................................................................................................

........................................................................................................

........................................................................................................

---

# Módulo 2 — Fundamentos e Arquitetura Kubernetes

# 12. Porque precisamos de orquestração

Executar um ou dois containers num único host é relativamente simples. O problema muda de natureza quando surgem dezenas ou centenas de instâncias distribuídas por vários servidores.

Considere:

```text
Node A → 20 containers
Node B → 35 containers
Node C → 18 containers
Node D → 42 containers
```

A equipa passa a precisar de responder continuamente a perguntas como:

- em que servidor deve executar cada workload?
- o que acontece quando um servidor falha?
- como manter o número pretendido de instâncias?
- como substituir processos que terminam inesperadamente?
- como atualizar uma aplicação sem gerir manualmente cada instância?
- como descobrir onde está cada aplicação?
- como expor serviços de forma estável quando as instâncias mudam?
- como aplicar configuração de forma consistente?
- como gerir recursos CPU/memória?
- como manter uma visão comum do estado de todo o sistema?

É neste contexto que aparece um **orquestrador**.

## 12.1. O que Kubernetes tenta resolver

Kubernetes oferece uma API e um conjunto de control loops para gerir workloads de forma declarativa e automatizada.

Uma visão simplificada:

```text
Definir o que pretendo
        │
        ▼
Kubernetes API
        │
        ▼
Kubernetes observa o cluster
        │
        ▼
Toma ações para aproximar
estado real do estado pretendido
```

Kubernetes não é apenas uma ferramenta para “arrancar containers”. É um sistema distribuído que mantém objetos, estado, regras e control loops.

---

# 13. Modelo declarativo, estado desejado e reconciliação

## 13.1. Imperativo vs. declarativo

### Imperativo

No modelo imperativo descrevemos ações:

```text
criar A
criar B
configurar C
parar D
substituir E
```

### Declarativo

No modelo declarativo descrevemos o resultado pretendido:

```text
Quero que exista:
- esta aplicação
- com esta imagem
- com esta configuração
- neste namespace
- com este número de réplicas
```

Kubernetes fica responsável por determinar muitas das ações necessárias para aproximar a realidade desta descrição.

## 13.2. Estado desejado

O **desired state** é aquilo que pretendemos que exista.

Exemplo conceptual:

```text
Desejado: 3 réplicas
```

## 13.3. Estado observado

O **observed state** é aquilo que o sistema observa naquele momento.

```text
Observado: 2 réplicas
```

## 13.4. Reconciliação

Um controller compara repetidamente estes estados.

```text
Desired = 3
Observed = 2
     │
     ▼
 diferença detetada
     │
     ▼
 controller atua
     │
     ▼
 cria 1
     │
     ▼
Observed = 3
```

Mas o trabalho não termina. Se mais tarde uma instância desaparecer:

```text
Observed = 2
```

o controller volta a atuar.

> **Essencial**  
> Reconciliação é um processo contínuo. Kubernetes não executa apenas uma receita inicial; os controllers continuam a observar e a corrigir divergências.

## 13.5. Porque é importante guardar configuração declarativa

Quando manifests são tratados como código, torna-se possível:

- versionar;
- rever alterações;
- auditar;
- comparar ambientes;
- reproduzir configurações;
- automatizar deployment;
- integrar práticas GitOps.

> **Aprofundamento**  
> Deployments, ReplicaSets e outros controllers aplicam diretamente este modelo: observam continuamente o estado e atuam para aproximar o estado observado do estado desejado. Fluxos GitOps estendem a mesma ideia ao manter a configuração declarativa em controlo de versões.

---

# 14. Arquitetura de um cluster Kubernetes

Um cluster Kubernetes divide responsabilidades entre **Control Plane** e **Worker Nodes**.

```text
                         Kubernetes Cluster
                                │
            ┌───────────────────┴───────────────────┐
            │                                       │
       CONTROL PLANE                           WORKER NODES
            │                                       │
   ┌────────┼──────────┐                  ┌─────────┼──────────┐
   │        │          │                  │         │          │
API Server etcd   Scheduler           kubelet   runtime   kube-proxy*
   │                   │
   └──── Controller Manager
```

`kube-proxy` é um componente tradicional e continua comum, mas é considerado opcional na arquitetura atual porque algumas implementações de rede podem fornecer funcionalidade equivalente por outros mecanismos.

## 14.1. Control Plane

O Control Plane:

- expõe a API;
- guarda o estado do cluster;
- toma decisões de scheduling;
- executa controllers;
- coordena a convergência do sistema para o estado pretendido.

## 14.2. Worker Nodes

Os Worker Nodes:

- executam os Pods;
- alojam o container runtime;
- executam `kubelet`;
- integram networking do cluster;
- reportam estado ao Control Plane.

> **Importante**  
> “Control Plane manda e Worker obedece” é uma simplificação. Na prática, os componentes comunicam através da Kubernetes API e trabalham segundo um modelo orientado a estado e observação contínua.

---

# 15. Control Plane em detalhe

## 15.1. kube-apiserver

O `kube-apiserver` expõe a Kubernetes HTTP API.

Praticamente todas as interações relevantes com o cluster passam pela API:

```text
kubectl
  │
  ▼
kube-apiserver
  │
  ├── utilizadores
  ├── kubelet
  ├── scheduler
  ├── controllers
  └── outros clientes
```

Responsabilidades incluem, de forma simplificada:

- receber pedidos;
- autenticar identidade quando aplicável;
- autorizar operações;
- executar admission control aplicável;
- validar objetos;
- persistir/ler estado através do armazenamento do cluster;
- disponibilizar mecanismos de watch para componentes que observam alterações.

O API Server é o ponto central de coordenação. Outros componentes não devem ser imaginados como a manipular `etcd` diretamente por rotina.

## 15.2. etcd

`etcd` é uma base de dados key-value distribuída, consistente e usada para armazenar os dados da Kubernetes API.

Conceptualmente:

```text
Cliente
  │
  ▼
API Server
  │
  ▼
etcd
```

O estado guardado inclui a representação dos objetos e configuração necessários ao cluster.

> **Importante**  
> `etcd` é crítico para o estado do cluster. A sua proteção, backup, recuperação e consistência são preocupações operacionais centrais na administração de Kubernetes.

## 15.3. kube-scheduler

O scheduler procura Pods que ainda não estejam atribuídos a um Node e seleciona um Node adequado.

```text
Pod sem Node
    │
    ▼
kube-scheduler
    │
    ├── recursos disponíveis
    ├── constraints
    ├── políticas de placement
    └── outros critérios
    │
    ▼
Node selecionado
```

Não confundir:

- **scheduler** decide placement;
- **kubelet** materializa/acompanha a execução no Node selecionado.

> **Aprofundamento**  
> A decisão do scheduler pode ser influenciada por recursos disponíveis, requests/limits, affinity/anti-affinity, taints/tolerations, topology constraints e outras regras de placement.

## 15.4. kube-controller-manager

O `kube-controller-manager` executa vários controllers.

Um controller é, conceptualmente, um loop:

```text
observar estado
     │
     ▼
comparar com desejado
     │
     ▼
atuar se necessário
     │
     └───────────────↺
```

Diferentes controllers tratam diferentes tipos de responsabilidade.

## 15.5. cloud-controller-manager

Em ambientes integrados com cloud providers, pode existir `cloud-controller-manager`, que separa integração específica da cloud de componentes nucleares.

Este componente é particularmente relevante em clusters integrados com fornecedores de cloud, onde separa a lógica específica do fornecedor dos restantes componentes do Control Plane.

---

# 16. Worker Nodes em detalhe

## 16.1. kubelet

`kubelet` é o agente principal de cada Node.

Entre outras responsabilidades, observa Pods atribuídos ao Node e trabalha para garantir que os containers esperados estão em execução.

```text
Kubernetes API
      │
      ▼
    kubelet
      │
      │ CRI
      ▼
container runtime
      │
      ▼
containers
```

O `kubelet` também reporta informação de estado para a API.

## 16.2. Container runtime

Cada Node precisa de um runtime capaz de executar os containers dos Pods.

Exemplos comuns incluem:

- `containerd`;
- `CRI-O`.

Kubernetes utiliza o **Container Runtime Interface (CRI)** como protocolo principal entre `kubelet` e o runtime.

### Relação importante

```text
kubelet
  │
  │ CRI (gRPC)
  ▼
containerd / CRI-O
  │
  ▼
OCI runtime
  │
  ▼
Linux kernel
```

Isto explica porque Kubernetes não precisa do Docker Engine para executar imagens que foram construídas com Docker.

## 16.3. kube-proxy

Em arquiteturas tradicionais, `kube-proxy` mantém regras de rede no Node relacionadas com Services.

Os pontos essenciais são:

- é um componente de Node comum;
- está ligado ao networking de Services;
- existem implementações modernas em que parte desta função pode ser cumprida de outra forma.

## 16.4. CNI

Kubernetes define um modelo de networking, mas a implementação concreta da rede de Pods depende normalmente de um plugin compatível com **Container Network Interface (CNI)**.

```text
Pod
 │
 ▼
Network namespace
 │
 ▼
CNI plugin
 │
 ▼
Pod network
```

> **Ligação ao networking Kubernetes**  
> CNI fornece a integração da rede de Pods; Services e DNS fornecem descoberta e acesso estável; Ingress/Gateway API tratam exposição e encaminhamento de tráfego; NetworkPolicies permitem controlar comunicação entre workloads.

---

# 17. Kubernetes API e percurso de um pedido

## 17.1. Kubernetes é API-driven

Quando usamos `kubectl`, não estamos a “entrar” diretamente nos Nodes para executar comandos administrativos. `kubectl` age como cliente da API.

```text
Utilizador
   │
   ▼
kubectl
   │
   ▼
Kubernetes API
   │
   ▼
objetos / estado / operações
```

## 17.2. Percurso conceptual de um pedido

Suponha:

```bash
kubectl apply -f pod-demo.yaml
```

Conceptualmente:

```text
1. kubectl lê configuração/context
        │
2. determina API endpoint e identidade
        │
3. envia pedido HTTPS
        │
4. API Server autentica
        │
5. API Server autoriza
        │
6. admission/validação aplicável
        │
7. objeto é aceite/rejeitado
        │
8. estado é persistido
        │
9. componentes observam a alteração
```

A ordem exata e os detalhes podem envolver múltiplos passos internos; o diagrama mostra o modelo mental relevante.

## 17.3. Authentication vs. Authorization

- **Authentication** — quem é o cliente?
- **Authorization** — o cliente autenticado pode executar esta ação sobre este recurso?

Exemplo conceptual:

```text
“Sou a utilizadora Ana”       → authentication
“Posso criar Pods em X?”      → authorization
```

> **Aprofundamento**  
> A identidade e autorização em Kubernetes podem envolver certificados, Service Accounts, tokens e RBAC. O API Server avalia a identidade apresentada e verifica se a ação pedida é autorizada antes de aceitar a operação.

## 17.4. Admission

Depois de autenticação/autorização, mecanismos de admission podem validar ou modificar pedidos antes de persistência final, consoante configuração do cluster.

O formando deve reter que a API não é simplesmente um armazenamento passivo: existe uma cadeia de processamento e políticas.

---

# 18. kubectl, kubeconfig e contexts

## 18.1. O que é `kubectl`?

`kubectl` é um cliente de linha de comandos para a Kubernetes API.

É útil pensar em famílias de operações:

| Comando | Finalidade |
|---|---|
| `get` | listar/consultar resumo |
| `describe` | apresentar detalhe e Events relacionados |
| `logs` | obter logs de containers |
| `apply` | criar/atualizar a partir de configuração declarativa |
| `delete` | eliminar recursos |
| `explain` | consultar schema/documentação da API |
| `config` | trabalhar com kubeconfig/contexts |
| `api-resources` | descobrir tipos de recursos disponíveis |
| `api-versions` | consultar versões/grupos de API disponíveis |

## 18.2. kubeconfig

Um kubeconfig contém informação necessária para selecionar endpoints e credenciais/contexto.

Estrutura conceptual:

```yaml
clusters:
  ...
users:
  ...
contexts:
  ...
current-context: ...
```

Um context associa, em termos conceptuais:

```text
Context
├── Cluster
├── User
└── Namespace opcional
```

## 18.3. Porque é útil um context?

Um profissional pode trabalhar com:

```text
dev
staging
production
cluster-lab
cluster-admin
```

Contexts permitem alternar a configuração ativa sem reescrever manualmente endpoint, utilizador e namespace.

Comandos:

```bash
kubectl config current-context
kubectl config get-contexts
kubectl config use-context <contexto>
```

> **Importante**  
> Antes de executar uma operação destrutiva, confirme sempre o context e namespace. Muitos incidentes operacionais começam com um comando correto executado no ambiente errado.

## 18.4. Namespace por contexto

Pode definir uma preferência de namespace num context. Também pode substituir para um comando específico:

```bash
kubectl get pods -n formacao
```

ou:

```bash
kubectl get pods --namespace formacao
```

## 18.5. Saídas úteis

```bash
kubectl get pods
kubectl get pods -o wide
kubectl get pod web-demo -o yaml
kubectl get pod web-demo -o json
```

A saída `-o yaml` é particularmente valiosa porque apresenta a representação do objeto com campos adicionados/defaults e estado observado.

## 18.6. Descoberta da API

```bash
kubectl api-resources
kubectl explain pod
kubectl explain pod.spec
kubectl explain pod.spec.containers
```

Isto ajuda a responder à pergunta:

> “Como sei que campos posso escrever num manifest?”

O `kubectl explain` consulta informação do schema da API disponível no cluster/cliente e é uma ferramenta essencial de aprendizagem e operação.

---

# 19. YAML e manifests Kubernetes

## 19.1. YAML: conceitos mínimos

YAML representa estruturas de dados com uma sintaxe legível.

Três estruturas são particularmente importantes:

### Mapa / objeto

```yaml
metadata:
  name: web-demo
  namespace: formacao
```

### Lista

```yaml
containers:
  - name: web
    image: nginx
```

### Escalar

```yaml
name: web
replicas: 3
enabled: true
```

## 19.2. Indentação

A indentação define hierarquia. Tabs devem ser evitados; use espaços de forma consistente.

Isto:

```yaml
metadata:
  name: web-demo
```

não é equivalente a:

```yaml
metadata:
name: web-demo
```

## 19.3. Um manifest Kubernetes

Exemplo:

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

## 19.4. Os quatro campos que aparecem constantemente

| Campo | Pergunta |
|---|---|
| `apiVersion` | Que grupo/versão da API representa este objeto? |
| `kind` | Que tipo de objeto é? |
| `metadata` | Como é identificado e descrito? |
| `spec` | Qual é a configuração/estado pretendido? |

Nem todos os tipos de objeto apresentam exatamente a mesma estrutura interna, e nem todos usam `spec`/`status` da mesma forma.

## 19.5. `apiVersion`

Exemplos:

```yaml
apiVersion: v1
```

ou:

```yaml
apiVersion: apps/v1
```

O primeiro utiliza o grupo core; o segundo utiliza o grupo `apps` e versão `v1`.

Não deve memorizar todos os grupos. Use:

```bash
kubectl api-resources
kubectl explain <recurso>
```

## 19.6. `kind`

`kind` identifica o tipo de objeto:

```yaml
kind: Pod
```

ou, em utilização avançada:

```yaml
kind: Deployment
kind: Service
kind: ConfigMap
```

---

# 20. Objetos, spec, status e metadata

## 20.1. Objeto Kubernetes

Um objeto Kubernetes representa uma entidade persistida e manipulável através da API.

Um objeto pode incluir:

```text
metadata
spec
status
```

mas a estrutura exata depende do tipo.

## 20.2. metadata

`metadata` contém identificação e informação associada ao objeto.

Exemplo:

```yaml
metadata:
  name: web-demo
  namespace: formacao
  labels:
    app: web
  annotations:
    training.example/owner: equipa-a
```

Quando o objeto é criado, Kubernetes acrescenta outros campos, como UID, timestamps e resourceVersion.

## 20.3. UID

`metadata.uid` identifica unicamente uma instância concreta de um objeto.

Se eliminar um Pod chamado `web-demo` e criar outro Pod com o mesmo nome, o novo objeto terá um UID diferente.

Isto ajuda a perceber uma ideia importante:

```text
mesmo nome
   ≠
mesmo objeto histórico
```

## 20.4. resourceVersion

`resourceVersion` está relacionado com a versão interna do recurso no armazenamento/API e é usado pelo mecanismo de concorrência/watch.

Não deve ser tratado como um número de versão de negócio da aplicação.

## 20.5. spec vs. status

Para objetos que usam estes campos:

```text
spec
  ↓
o que desejo

status
  ↓
o que Kubernetes observa
```

Experiência:

```bash
kubectl get pod web-demo -n formacao -o yaml
```

Procure:

```yaml
spec:
  ...
status:
  ...
```

O ficheiro original contém principalmente a intenção do utilizador. A representação devolvida pela API inclui defaults e estado observado.

> **Essencial**  
> Esta distinção entre intenção e observação é uma das ideias centrais de Kubernetes.

---

# 21. Pods em detalhe

## 21.1. Definição

Um **Pod** é a menor unidade de scheduling/deployment que Kubernetes trata como unidade de execução.

Pode conter um ou mais containers fortemente relacionados.

```text
Pod
│
├── network namespace / IP do Pod
├── volumes associados ao Pod
├── Container A
└── Container B
```

## 21.2. Kubernetes agenda Pods, não containers individuais

O scheduler escolhe um Node para o Pod. Todos os containers normais desse Pod executam no mesmo Node porque partilham o ambiente de execução do Pod.

```text
Pod A
├── ctr-1
└── ctr-2
       │
       ▼
   mesmo Node
```

## 21.3. Networking dentro do Pod

Containers do mesmo Pod partilham a rede do Pod.

Isso significa, conceptualmente:

- mesmo endereço IP do Pod;
- mesmo espaço de portas;
- comunicação entre containers via `localhost`.

Logo, dois containers do mesmo Pod não podem ambos tentar escutar na mesma porta/IP sem conflito.

## 21.4. Quando usar múltiplos containers no mesmo Pod?

Quando os processos são fortemente acoplados e beneficiam de partilhar recursos/lifecycle.

Exemplos conceptuais:

- sidecar;
- helper;
- componente que partilha ficheiros locais com a aplicação principal.

Não se deve colocar aplicações apenas porque “pertencem ao mesmo sistema”. Se precisam de escalar, falhar e evoluir independentemente, normalmente pertencem a Pods diferentes.

## 21.5. Pods são efémeros

Pods não devem ser encarados como servidores com identidade permanente.

Um Pod pode ser eliminado e substituído por outro, com:

- novo UID;
- possivelmente novo IP;
- novo lifecycle.

Esta característica explica por que razão Services e controllers de nível superior são essenciais: fornecem estabilidade lógica apesar da substituição de Pods individuais.

## 21.6. Pod direto vs. controller

Num exemplo simples podemos criar um Pod diretamente para observar a unidade fundamental de execução.

Em ambientes reais, workloads duradouros são normalmente geridos por objetos superiores, como Deployments, StatefulSets ou DaemonSets.

> **Relação entre objetos**  
> Um Deployment gere ReplicaSets e um ReplicaSet gere Pods. Esta cadeia de controllers adiciona funcionalidades como self-healing, escala declarativa e rollouts.

## 21.7. Fases de um Pod

O campo `status.phase` usa um conjunto pequeno de fases de alto nível, como:

- `Pending`;
- `Running`;
- `Succeeded`;
- `Failed`;
- `Unknown`.

A coluna `STATUS` apresentada por `kubectl get pods` pode também mostrar razões/estados úteis como `ContainerCreating`, `ImagePullBackOff` ou `CrashLoopBackOff`. Estes textos não devem ser confundidos automaticamente com o valor de `status.phase`.

## 21.8. Inspeção

```bash
kubectl get pod web-demo -n formacao
kubectl get pod web-demo -n formacao -o wide
kubectl get pod web-demo -n formacao -o yaml
kubectl describe pod web-demo -n formacao
```

Cada comando responde a uma pergunta diferente:

```text
get          → está lá? qual o resumo?
get -o wide  → onde está? IP? Node?
get -o yaml  → qual o objeto completo?
describe     → detalhe legível + Events
```

---
# 22. Namespaces

## 22.1. O que resolvem?

Namespaces permitem criar scopes lógicos dentro do mesmo cluster.

```text
Cluster
│
├── Namespace: equipa-a
│   ├── Pod
│   ├── Service
│   └── ConfigMap
│
└── Namespace: equipa-b
    ├── Pod
    └── Service
```

O mesmo nome pode existir em namespaces diferentes:

```text
equipa-a / web
equipa-b / web
```

## 22.2. Nem todos os recursos são namespaced

Alguns recursos pertencem a um namespace; outros são cluster-scoped.

Exemplos típicos:

| Namespaced | Cluster-scoped |
|---|---|
| Pod | Node |
| Deployment | Namespace |
| Service | PersistentVolume |
| ConfigMap | StorageClass |
| Secret | alguns recursos de cluster |

Confirme no cluster:

```bash
kubectl api-resources
```

A coluna `NAMESPACED` indica o scope.

## 22.3. Namespaces não são automaticamente uma fronteira de segurança forte

Um namespace por si só não equivale a uma VM, conta isolada ou cluster separado.

Pode ser combinado com:

- RBAC;
- ResourceQuota;
- LimitRange;
- NetworkPolicies;
- Pod Security;
- políticas de admission;

para criar separações operacionais mais fortes.

> **Importante**  
> Namespace é um mecanismo de organização e scope. Segurança multi-tenant forte exige controlos adicionais e, em alguns cenários, clusters separados.

## 22.4. Namespaces iniciais

Um cluster Kubernetes normal inicia com namespaces como:

- `default` — utilizado quando nenhum namespace é especificado;
- `kube-system` — recursos do sistema Kubernetes;
- `kube-public` — namespace reservado para determinados recursos potencialmente públicos;
- `kube-node-lease` — Lease objects associados aos Nodes e heartbeats.

Evite criar namespaces com prefixo `kube-`, reservado ao sistema.

## 22.5. Operações

```bash
kubectl get namespaces
kubectl create namespace formacao
kubectl get pods -n formacao
kubectl describe namespace formacao
```

Eliminar um namespace:

```bash
kubectl delete namespace formacao
```

Atenção: eliminar um namespace desencadeia a eliminação dos recursos namespaced nele contidos. Esta operação deve ser usada com especial cuidado em ambientes partilhados e de produção.

---

# 23. Labels, selectors e annotations

## 23.1. Labels

Labels são pares chave/valor associados a objetos para os **identificar, organizar e selecionar**.

```yaml
metadata:
  labels:
    app: loja
    component: frontend
    environment: production
    version: v2
```

Labels não são meramente comentários. São um mecanismo funcional muito importante em Kubernetes.

## 23.2. Porque são tão importantes?

Muitos relacionamentos Kubernetes são construídos usando labels e selectors:

```text
ReplicaSet  --selector--> Pods
Service     --selector--> Pods
utilizador  --selector--> conjunto de objetos
```

Labels são também usadas em mecanismos de scheduling, seleção de workloads e aplicação de políticas.

## 23.3. Regras de sintaxe essenciais

Uma label key pode ter:

```text
[prefixo DNS opcional/]nome
```

Exemplo:

```text
app.kubernetes.io/name
example.com/owner
app
```

O nome da key tem limite de 63 caracteres e o prefixo, quando usado, segue regras de subdomínio DNS. Os prefixos `kubernetes.io/` e `k8s.io/` são reservados a componentes Kubernetes.

Os valores têm limite de 63 caracteres, podendo ser vazios, e seguem regras de caracteres próprios para labels.

As regras de validação existem para manter labels adequadas à identificação e seleção eficiente de objetos; labels não foram concebidas para armazenar texto arbitrário.

## 23.4. Equality-based selectors

```bash
kubectl get pods -n formacao -l app=web
```

Também pode combinar condições:

```bash
kubectl get pods -l app=loja,environment=production
```

## 23.5. Set-based selectors

Exemplo:

```bash
kubectl get pods -l 'environment in (dev,test)'
```

Estes operadores tornam selectors mais expressivos.

## 23.6. Visualizar labels

```bash
kubectl get pods --show-labels
```

Ou criar uma coluna com uma label:

```bash
kubectl get pods -L app
```

## 23.7. Alterar labels

```bash
kubectl label pod web-demo owner=equipa-a -n formacao
```

Substituir uma label existente pode exigir `--overwrite`:

```bash
kubectl label pod web-demo owner=equipa-b --overwrite -n formacao
```

Remover uma label usa sufixo `-` na key:

```bash
kubectl label pod web-demo owner- -n formacao
```

## 23.8. Annotations

Annotations são também pares chave/valor em `metadata`, mas destinam-se a informação **não usada para seleção por label selectors**.

Exemplo:

```yaml
metadata:
  annotations:
    training.example/owner: "Equipa de Plataforma"
    training.example/ticket: "INC-1234"
```

### Label ou annotation?

Pergunta útil:

> “Preciso de selecionar/agrupar objetos com este valor?”

Se sim, é candidato a label. Se é informação descritiva para pessoas/ferramentas, pode ser annotation.

```text
Label       → identidade, agrupamento, seleção
Annotation  → metadata adicional, contexto, integração
```

> **Importante**  
> Não use annotations como base de seleção de objetos; label selectors operam sobre labels.

---

# 24. Mapa dos principais objetos Kubernetes

Os objetos seguintes formam um mapa de referência do ecossistema Kubernetes.

| Objeto | Papel resumido |
|---|---|
| **Pod** | Unidade de execução/scheduling que contém um ou mais containers |
| **ReplicaSet** | Mantém determinado número de Pods compatíveis com um selector |
| **Deployment** | Gere ReplicaSets e rollouts de aplicações stateless |
| **Service** | Fornece acesso estável a um conjunto de Pods |
| **ConfigMap** | Armazena configuração não sensível |
| **Secret** | Armazena dados sensíveis destinados a consumo por workloads, exigindo políticas adequadas de proteção |
| **PersistentVolume (PV)** | Representa armazenamento disponibilizado ao cluster |
| **PersistentVolumeClaim (PVC)** | Pedido de armazenamento feito por um workload/utilizador |
| **Job** | Executa trabalho até conclusão |
| **CronJob** | Cria Jobs segundo um calendário |
| **Node** | Representa um nó do cluster |
| **Namespace** | Define scope lógico para muitos recursos |

> **Referência**  
> A relação entre estes objetos é mais importante do que a memorização isolada dos nomes: controllers gerem workloads, Services fornecem acesso estável, objetos de configuração fornecem dados e objetos de storage representam persistência.

---

# 25. O que acontece num `kubectl apply`

Esta secção liga todos os conceitos anteriores.

Considere:

```bash
kubectl apply -f pod-demo.yaml
```

## 25.1. Passo a passo conceptual

### Passo 1 — `kubectl` lê o ficheiro

O cliente interpreta o YAML e identifica:

```text
apiVersion
kind
metadata
spec
```

### Passo 2 — `kubectl` lê o kubeconfig

Determina:

- cluster/API endpoint;
- context ativo;
- identidade/credenciais aplicáveis;
- namespace quando aplicável.

### Passo 3 — pedido HTTPS para o API Server

```text
kubectl
   │ HTTPS
   ▼
kube-apiserver
```

### Passo 4 — autenticação

A API tenta determinar a identidade do cliente.

### Passo 5 — autorização

É verificado se essa identidade pode executar a ação solicitada.

### Passo 6 — admission e validação

Políticas/plugins aplicáveis podem validar ou modificar o pedido. O objeto deve também respeitar o schema e regras da API.

### Passo 7 — persistência

O objeto aceite passa a fazer parte do estado do cluster e é persistido através do mecanismo de armazenamento do Control Plane.

```text
API Server
    │
    ▼
   etcd
```

### Passo 8 — scheduler observa Pod sem Node

Se o Pod ainda não estiver atribuído a um Node:

```text
Pod
 │
 ▼
kube-scheduler
 │
 ▼
Node escolhido
```

### Passo 9 — decisão de scheduling é registada

O Pod passa a estar associado ao Node selecionado.

### Passo 10 — kubelet observa o Pod atribuído

O `kubelet` do Node vê que deve garantir a execução desse Pod.

### Passo 11 — kubelet comunica com o runtime através de CRI

```text
kubelet
  │
  │ CRI
  ▼
containerd / CRI-O
```

### Passo 12 — imagem é obtida se necessário

O runtime verifica se a imagem necessária está localmente disponível e faz pull de acordo com a política aplicável.

### Passo 13 — containers são criados/iniciados

O runtime utiliza mecanismos de baixo nível/OCI para criar o ambiente e iniciar os processos.

### Passo 14 — estado é reportado

O `kubelet` reporta informação à API.

```text
Container
   │
   ▼
kubelet
   │
   ▼
API Server
   │
   ▼
status observado
```

### Passo 15 — `kubectl get` mostra a realidade observada

```bash
kubectl get pods -n formacao
```

O valor apresentado pode evoluir:

```text
Pending
ContainerCreating
Running
```

ou revelar um problema, como falha de pull ou crash.

## 25.2. O ponto principal

```text
YAML não “cria diretamente” o container.

YAML declara intenção
      ↓
API guarda estado
      ↓
componentes observam
      ↓
controllers/scheduler/kubelet atuam
      ↓
runtime materializa
      ↓
status regressa à API
```

Este é o modelo mental que deve acompanhar o formando durante todo o curso.

---

# 26. Síntese e consolidação do Módulo 2

## 26.1. Mapa mental

```text
Utilizador
   │
 kubectl
   │
 kubeconfig/context
   │
   ▼
API Server
   │
   ├── autenticação
   ├── autorização
   ├── admission/validação
   └── persistência
          │
          ▼
         etcd

Pod sem Node
   │
   ▼
Scheduler
   │
   ▼
Node
   │
   ▼
kubelet
   │ CRI
   ▼
runtime
   │
   ▼
container

Controllers
   │
   └── observed state ↔ desired state
```

## 26.2. Questões de consolidação

1. Que problema adicional surge quando passamos de um container para centenas de containers distribuídos?
2. Qual é a diferença entre modelo imperativo e declarativo?
3. Defina desired state, observed state e reconciliation.
4. Qual é a função principal do API Server?
5. Porque `etcd` é crítico para o cluster?
6. Qual é a função do scheduler?
7. Qual é a função do kubelet?
8. O que é CRI?
9. Porque um cluster Kubernetes moderno não necessita do Docker Engine para executar uma imagem construída com Docker?
10. O que representa um context no kubeconfig?
11. Qual é a diferença entre `spec` e `status`?
12. Porque o objeto devolvido por `kubectl get -o yaml` é maior do que o manifest original?
13. Porque um Pod não deve ser tratado como um servidor com identidade permanente?
14. Que recursos partilham containers dentro do mesmo Pod?
15. Namespace é uma fronteira de segurança forte por si só? Justifique.
16. Porque labels são mais do que simples metadata descritiva?
17. Qual é a diferença entre label e annotation?
18. O que acontece conceptualmente depois de `kubectl apply -f pod.yaml`?

## 26.3. Notas do formando — Módulo 2

........................................................................................................

........................................................................................................

........................................................................................................

........................................................................................................

---

# 27. Exercício integrado

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
    version: v1
  annotations:
    training.example/owner: "equipa-dev"
spec:
  containers:
    - name: api
      image: nginx:1.27
```

Responda sem executar:

1. Que tipo de recurso será criado?
2. Qual é o nome e namespace?
3. Que labels existem?
4. Qual é a annotation?
5. Que imagem está referenciada?
6. `1.27` é uma tag ou digest?
7. A tag garante identidade imutável da imagem?
8. Que parte do manifest representa a intenção do utilizador?
9. Onde espera encontrar estado observado depois da criação?
10. Que selector devolve este Pod pelo valor `app`?
11. Que selector combina `app` e `environment`?
12. Que comando aplica o ficheiro?
13. Que comando mostra o Pod com Node e IP?
14. Que comando mostra a representação completa em YAML?
15. Que comando mostra Events relacionados com o Pod de forma legível?
16. Que componente do Control Plane recebe inicialmente o pedido?
17. Que componente decide em que Node o Pod deverá executar?
18. Que componente no Worker Node acompanha a execução?
19. Que interface liga o kubelet ao container runtime?
20. Porque o Pod poderá ter um IP diferente se for eliminado e recriado?

### Desafio adicional

Depois de executar, corra:

```bash
kubectl get pod api-demo -n formacao -o yaml
```

Compare o resultado com o ficheiro original e crie uma tabela com três colunas:

| Campo | Estava no manifest? | Quem/que processo o terá acrescentado ou atualizado? |
|---|---|---|
| `metadata.uid` | | |
| `metadata.resourceVersion` | | |
| `spec.nodeName` | | |
| `status.phase` | | |
| `status.podIP` | | |

O objetivo é consolidar a distinção entre **configuração fornecida**, **defaults/metadata do sistema** e **estado observado**.

---

# 28. Guia rápido Docker e Podman

## 28.1. Containers

| Objetivo | Docker | Podman |
|---|---|---|
| Executar | `docker run ...` | `podman run ...` |
| Listar ativos | `docker ps` | `podman ps` |
| Listar todos | `docker ps -a` | `podman ps -a` |
| Logs | `docker logs NAME` | `podman logs NAME` |
| Inspecionar | `docker inspect NAME` | `podman inspect NAME` |
| Parar | `docker stop NAME` | `podman stop NAME` |
| Iniciar | `docker start NAME` | `podman start NAME` |
| Remover | `docker rm NAME` | `podman rm NAME` |

## 28.2. Imagens

```bash
docker images
docker pull nginx
docker image inspect nginx
docker image rm nginx
```

## 28.3. Volumes

```bash
docker volume create dados-demo
docker volume ls
docker volume inspect dados-demo
docker volume rm dados-demo
```

## 28.4. Redes

```bash
docker network ls
docker network create rede-demo
docker network inspect rede-demo
docker network rm rede-demo
```

## 28.5. Perguntas de diagnóstico

Quando um container não funciona, pergunte:

1. a imagem existe/pode ser obtida?
2. o container foi criado?
3. está `running` ou `exited`?
4. que exit code tem?
5. que mostram os logs?
6. a porta foi publicada?
7. o processo está realmente a escutar?
8. existe volume/mount esperado?
9. permissões impedem acesso?
10. existem limites ou políticas de segurança a bloquear a operação?

---

# 29. Guia rápido kubectl

## 29.1. Contexto e cluster

```bash
kubectl cluster-info
kubectl get nodes
kubectl config current-context
kubectl config get-contexts
kubectl config use-context <contexto>
```

## 29.2. Descoberta

```bash
kubectl api-resources
kubectl api-versions
kubectl explain pod
kubectl explain pod.spec
```

## 29.3. Consulta

```bash
kubectl get pods
kubectl get pods -A
kubectl get pods -n formacao
kubectl get pods -o wide
kubectl get pod web-demo -o yaml
kubectl describe pod web-demo
```

## 29.4. Criação/aplicação

```bash
kubectl apply -f recurso.yaml
```

## 29.5. Labels

```bash
kubectl get pods --show-labels
kubectl get pods -l app=web
kubectl label pod web-demo owner=equipa-a
```

## 29.6. Logs

```bash
kubectl logs web-demo
kubectl logs web-demo -c <container>
```

## 29.7. Eventos

```bash
kubectl get events
kubectl get events -n formacao
```

## 29.8. Eliminação

```bash
kubectl delete -f recurso.yaml
kubectl delete pod web-demo
kubectl delete namespace formacao
```

## 29.9. Método de observação recomendado

Quando não compreende o que se passa:

```text
1. get
2. get -o wide
3. describe
4. events
5. logs
6. get -o yaml
7. explain / api-resources
```

Não significa que esta ordem resolva todos os problemas, mas obriga a recolher evidências antes de alterar o sistema.

---

# 30. Glossário

**Annotation** — metadata chave/valor usada para informação adicional associada a um objeto; não é usada por label selectors.

**API Group** — agrupamento lógico de tipos de recursos na Kubernetes API, por exemplo `apps`.

**API Server** — componente do Control Plane que expõe a Kubernetes API.

**Bind mount** — mount de um caminho real do host dentro de um container.

**Capability** — unidade granular de privilégio Linux que permite dividir poderes tradicionalmente associados a root.

**cgroup** — mecanismo Linux para controlo/contabilização de recursos de processos.

**Cloud-native** — conjunto de práticas/arquiteturas orientadas a automação, APIs, resiliência, elasticidade e operação em ambientes dinâmicos; não significa obrigatoriamente “executar apenas em cloud pública”.

**Container** — ambiente de execução isolado para um ou mais processos, criado com mecanismos do sistema operativo e configuração fornecida por um runtime.

**Container runtime** — software que participa na gestão e/ou execução de containers; o termo pode referir-se a diferentes camadas, por isso deve ser contextualizado.

**containerd** — runtime/daemon de alto nível amplamente utilizado para lifecycle e gestão de containers e imagens, incluindo integração CRI.

**Context** — entrada de kubeconfig que associa cluster, user e opcionalmente namespace.

**Control Plane** — conjunto de componentes que expõe API, mantém estado e coordena decisões/controlo do cluster.

**Controller** — processo/control loop que observa estado e atua para aproximar observed state do desired state.

**CRI** — Container Runtime Interface; protocolo principal de comunicação entre kubelet e container runtime em Kubernetes.

**Desired state** — configuração/estado que se pretende que o sistema mantenha.

**Digest** — identificador criptográfico baseado no conteúdo de um artefacto, como uma imagem/manifest.

**etcd** — base key-value distribuída usada pelo Control Plane para dados da Kubernetes API.

**Image** — artefacto read-only contendo filesystem layers, configuração e metadados necessários para criar containers.

**Image registry** — serviço que armazena/distribui imagens e outros artefactos.

**kube-apiserver** — implementação do servidor da Kubernetes API.

**kube-controller-manager** — componente que executa controllers do Control Plane.

**kube-proxy** — componente tradicional de Node que mantém regras de rede para Services; pode ser opcional consoante arquitetura.

**kube-scheduler** — componente que seleciona Nodes para Pods ainda não atribuídos.

**kubeconfig** — ficheiro/estrutura de configuração usada por clientes como `kubectl` para clusters, users, contexts e current context.

**kubelet** — agente de Node que acompanha Pods atribuídos e interage com o runtime.

**kubectl** — cliente CLI da Kubernetes API.

**Label** — atributo chave/valor destinado a identificar, organizar e selecionar objetos.

**Layer** — conjunto imutável de alterações de filesystem que participa na composição de uma imagem.

**Manifest** — representação declarativa de um objeto Kubernetes, frequentemente escrita em YAML.

**Namespace** — scope lógico dentro de um cluster para muitos tipos de recurso.

**Namespace Linux** — mecanismo do kernel que fornece uma vista isolada de determinado conjunto de recursos.

**Node** — máquina física ou virtual que participa no cluster; normalmente um Worker Node executa workloads.

**Observed state** — estado atual observado pelo sistema.

**OCI** — Open Container Initiative; projeto de standards abertos para formatos/runtime/distribuição de containers.

**Pod** — menor unidade de scheduling/deployment de Kubernetes; contém um ou mais containers que partilham contexto de execução.

**Reconciliation** — processo contínuo de aproximar observed state de desired state.

**Registry** — ver Image registry.

**Repository** — coleção lógica de imagens/artefactos sob um nome num registry.

**Rootless** — modo de execução em que daemon/processos de container funcionam sem privilégios root tradicionais no host, dentro das limitações aplicáveis.

**runc** — implementação de referência de runtime compatível com OCI usada para criar/executar containers de baixo nível.

**Selector** — expressão usada para selecionar objetos, frequentemente com base em labels.

**spec** — secção de muitos objetos que descreve configuração/intenção pretendida.

**status** — secção gerida pelo sistema em muitos objetos para representar estado observado.

**Tag** — referência legível associada a uma imagem; pode ser alterada para apontar para conteúdo diferente.

**Volume** — armazenamento montado num container com lifecycle independente do container individual, quando gerido como volume.

**Worker Node** — Node onde são executados Pods/workloads.

**YAML** — linguagem/formato de serialização legível usado frequentemente para manifests Kubernetes.

---

# 31. Espaço para notas

## Conceitos que quero rever

........................................................................................................

........................................................................................................

........................................................................................................

## Comandos que quero memorizar

........................................................................................................

........................................................................................................

........................................................................................................

## Dúvidas para colocar ao formador

........................................................................................................

........................................................................................................

........................................................................................................

## Ligações ao meu contexto profissional

........................................................................................................

........................................................................................................

........................................................................................................

---

# 32. Recursos e leituras complementares

## 32.1. Livros de referência utilizados no projeto

O desenvolvimento e aprofundamento deste manual teve como base conceptual os seguintes livros disponíveis nas fontes do projeto:

- **Docker Deep Dive** — arquitetura Docker, imagens, layers, networking, armazenamento e segurança.
- **Kubernetes in Action** — arquitetura, API, Pods, namespaces, labels, selectors e runtime/containerização.
- **Kubernetes: Up and Running** — modelo declarativo, Pods, labels, controllers e práticas operacionais.
- **The Kubernetes Book** — princípios de operação, desired/observed state, componentes, Pods e segurança.
- **Ultimate Docker Container Book** — imagens, registries, persistência, segurança e práticas modernas de supply chain.

Este manual sintetiza e reorganiza estes conceitos como referência técnica estruturada. As obras indicadas permitem aprofundar fundamentos, exemplos e decisões de arquitetura.

## 32.2. Documentação oficial Kubernetes

- Kubernetes Components: https://kubernetes.io/docs/concepts/overview/components/
- Container Runtime Interface: https://kubernetes.io/docs/concepts/containers/cri/
- Container Runtimes: https://kubernetes.io/docs/setup/production-environment/container-runtimes/
- Pods: https://kubernetes.io/docs/concepts/workloads/pods/
- Namespaces: https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/
- Labels and Selectors: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/
- Annotations: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/
- kubectl reference: https://kubernetes.io/docs/reference/kubectl/

## 32.3. Open Container Initiative

- OCI overview: https://opencontainers.org/about/overview/
- OCI specifications: https://specs.opencontainers.org/

## 32.4. Docker documentation

- Docker Engine security: https://docs.docker.com/engine/security/
- Networking: https://docs.docker.com/engine/network/
- Volumes: https://docs.docker.com/engine/storage/volumes/
- Bind mounts: https://docs.docker.com/engine/storage/bind-mounts/
- Rootless mode: https://docs.docker.com/engine/security/rootless/

> **Nota de atualização**  
> Kubernetes, Docker, OCI e o ecossistema cloud-native evoluem rapidamente. Para opções de CLI, versões suportadas e comportamentos dependentes de versão, confirme sempre a documentação oficial da versão utilizada no ambiente real.
