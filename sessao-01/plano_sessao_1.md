# Plano da Sessão 1 — Fundamentos de Containers e Kubernetes

## 1. Identificação da Sessão

- **Formação:** Mini MBA em Orquestração de Containers com Kubernetes
- **Sessão:** 1
- **Parte:** I — Fundamentos Comuns
- **Módulos abrangidos:**
  - Módulo 1 — Fundamentos de Containers
  - Módulo 2 — Fundamentos e Arquitetura Kubernetes
- **Duração:** 4 horas (240 minutos)
- **Nível de referência:** Intermédio
- **Número estimado de formandos:** Até 5
- **Metodologia:** Expositiva e ativa, com forte componente prática

---

# 2. Objetivos Específicos

No final da sessão, os formandos deverão ser capazes de:

1. Explicar os conceitos fundamentais de virtualização e containerização.
2. Distinguir containers de máquinas virtuais.
3. Explicar o papel de um container runtime.
4. Enquadrar Docker, Podman e OCI no ecossistema de containers.
5. Distinguir uma imagem de um container.
6. Explicar a função de um image registry.
7. Executar e consultar um container.
8. Consultar os logs de um container.
9. Compreender o funcionamento básico de networking de containers.
10. Criar e utilizar um volume básico e validar a persistência de dados.
11. Identificar princípios básicos de segurança de containers.
12. Explicar a necessidade de orquestração e o papel do Kubernetes.
13. Explicar a arquitetura geral de um cluster Kubernetes.
14. Identificar os componentes do Control Plane e dos Worker Nodes.
15. Explicar o papel da Kubernetes API.
16. Utilizar `kubectl` para consultar o cluster.
17. Utilizar contextos e compreender a finalidade do `kubeconfig`.
18. Interpretar manifests YAML simples.
19. Explicar os conceitos de Pod e Namespace.
20. Utilizar labels, selectors e annotations a nível introdutório.
21. Criar e consultar recursos Kubernetes básicos.

---

# 3. Conteúdos

## 3.1. Fundamentos de Containers

- Conceitos de virtualização e containerização.
- Containers vs. máquinas virtuais.
- Container runtimes.
- Docker.
- Podman.
- OCI.
- Imagens de containers.
- Image registries.
- Ciclo de vida dos containers.
- Networking de containers.
- Volumes.
- Princípios básicos de segurança.

## 3.2. Fundamentos Kubernetes

- Kubernetes e princípios cloud-native.
- Arquitetura de um cluster Kubernetes.
- Control Plane.
- Worker Nodes.
- Kubernetes API.
- Utilização do `kubectl`.
- Contextos.
- `kubeconfig`.
- YAML.
- Manifests Kubernetes.
- Namespaces.
- Pods.
- Labels.
- Selectors.
- Annotations.
- Principais objetos Kubernetes.

## 3.3. Componente Prática

- Executar um container.
- Consultar containers em execução.
- Consultar logs.
- Parar e remover containers.
- Criar e utilizar um volume.
- Validar persistência de dados.
- Consultar nodes, namespaces e contextos Kubernetes.
- Criar um Namespace.
- Criar um Pod através de YAML.
- Aplicar labels.
- Utilizar selectors.
- Remover os recursos criados.

---

# 4. Distribuição Temporal Revista

| Tempo | Conteúdo / Atividade |
|---:|---|
| 40 min | Virtualização, containers e máquinas virtuais |
| 35 min | Runtimes, Docker, Podman e OCI |
| 35 min | Imagens, registries, networking, volumes e segurança |
| 15 min | **Intervalo** |
| 35 min | Kubernetes, cloud-native e arquitetura |
| 30 min | API, `kubectl`, contextos e `kubeconfig` |
| 25 min | YAML, Pods, namespaces, labels, selectors e annotations |
| 25 min | Laboratório Kubernetes |
| **240 min** | **Total** |

---

# 5. Planeamento Detalhado

## Bloco 1 — Virtualização, Containers e Máquinas Virtuais

**Duração:** 40 minutos

### Conteúdos

- Conceito de virtualização.
- Máquina física.
- Hipervisor.
- Máquinas virtuais.
- Sistemas operativos convidados.
- Conceito de container.
- Isolamento de aplicações.
- Relação container/host.
- Containers vs. máquinas virtuais.

### Comparação de referência

| Máquina Virtual | Container |
|---|---|
| Inclui sistema operativo convidado | Partilha o kernel do host |
| Maior consumo de recursos | Menor overhead |
| Arranque normalmente mais demorado | Arranque normalmente rápido |
| Isolamento ao nível da VM | Isolamento ao nível dos processos |
| Imagens tendencialmente maiores | Imagens tendencialmente menores |

### Metodologia

- Exposição dialogada.
- Recuperação de conhecimentos prévios.
- Utilização de esquemas comparativos.
- Discussão orientada.

### Atividade

Apresentar cenários e pedir aos formandos que justifiquem a utilização predominante de VM ou container, por exemplo:

- sistema operativo diferente do host;
- API web;
- microsserviço;
- aplicação legacy;
- ambiente temporário de testes.

---

## Bloco 2 — Runtimes, Docker, Podman e OCI

**Duração:** 35 minutos

### Conteúdos

- Conceito de container runtime.
- Papel do runtime.
- Docker.
- Podman.
- OCI.
- Ciclo de vida básico do container.

### Demonstração / Prática

Exemplo com Docker:

```bash
docker run --name web-demo -d nginx
docker ps
docker logs web-demo
docker stop web-demo
docker rm web-demo
```

Alternativa com Podman:

```bash
podman run --name web-demo -d nginx
podman ps
podman logs web-demo
podman stop web-demo
podman rm web-demo
```

### Sequência conceptual

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

### Nota pedagógica

O objetivo não é aprofundar Docker ou Podman nesta sessão, mas garantir que os formandos compreendem o papel destas ferramentas no ecossistema de containers.

---

## Bloco 3 — Imagens, Registries, Networking, Volumes e Segurança

**Duração:** 35 minutos

### Conteúdos

- Imagens.
- Layers, apenas conceptualmente.
- Tags.
- Image registries.
- Relação imagem → container.
- Networking básico.
- Exposição de portas.
- Armazenamento efémero.
- Volumes.
- Persistência.
- Princípios básicos de segurança.

### Fluxo de imagem

```text
Construir imagem
      ↓
Atribuir tag
      ↓
Registry
      ↓
Pull
      ↓
Executar container
```

### Prática com volume

```bash
docker volume create dados-demo
docker volume ls
```

Executar um container utilizando o volume e validar a persistência.

### Conceito fundamental

```text
Container A
    |
    v
  Volume
    ^
    |
Container B
```

Mensagem-chave:

> O ciclo de vida do container não deve ser confundido com o ciclo de vida dos dados.

### Segurança básica

- Utilizar imagens de origem confiável.
- Minimizar componentes desnecessários.
- Evitar privilégios superiores aos necessários.
- Manter imagens atualizadas.
- Evitar credenciais embutidas nas imagens.
- Limitar a exposição de serviços.

---

## Intervalo

**Duração:** 15 minutos

---

## Bloco 4 — Kubernetes, Cloud-Native e Arquitetura

**Duração:** 35 minutos

### Transição Pedagógica

Questão orientadora:

> Já conseguimos executar containers. Como gerimos dezenas ou centenas de containers distribuídos por vários servidores?

### Conteúdos

- Necessidade de orquestração.
- Kubernetes.
- Princípios cloud-native.
- Automatização.
- Configuração declarativa.
- Estado desejado.
- Reconciliação.
- Arquitetura do cluster.
- Control Plane.
- Worker Nodes.
- Kubernetes API.

### Diagrama Simplificado

```text
                 kubectl
                    |
                    v
              Kubernetes API
                    |
           +--------+--------+
           |                 |
     CONTROL PLANE       WORKER NODES
                              |
                       +------+------+
                       |             |
                      Pod           Pod
```

### Mensagem-chave

O objetivo nesta sessão não é memorizar todos os componentes internos, mas compreender o fluxo:

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

---

## Bloco 5 — API, `kubectl`, Contextos e `kubeconfig`

**Duração:** 30 minutos

### Conteúdos

- Kubernetes API.
- `kubectl`.
- Cluster.
- Contextos.
- `kubeconfig`.

### Demonstração

```bash
kubectl cluster-info
kubectl get nodes
kubectl config current-context
kubectl config get-contexts
```

Quando aplicável:

```bash
kubectl config use-context <contexto>
```

### Relação conceptual

```text
kubectl
   |
   v
kubeconfig
   |
   v
Context
   |
   v
Cluster / User / Namespace
```

### Nota pedagógica

Autenticação e autorização são apenas enquadradas nesta sessão e serão aprofundadas posteriormente.

---

## Bloco 6 — YAML, Pods, Namespaces, Labels, Selectors e Annotations

**Duração:** 25 minutos

### Conteúdos

- Estrutura YAML.
- Manifest Kubernetes.
- `apiVersion`.
- `kind`.
- `metadata`.
- `spec`.
- Pod.
- Namespace.
- Labels.
- Selectors.
- Annotations.
- Principais objetos Kubernetes.

### Manifest de referência

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

### Questões de análise

- O que está a ser criado?
- Qual o nome do recurso?
- Em que Namespace será criado?
- Qual a imagem utilizada?
- Que labels existem?
- Onde está definido o estado pretendido?

### Principais Objetos Kubernetes

Apresentar apenas como mapa de navegação:

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

Nesta sessão não se pretende aprofundar individualmente estes objetos.

---

## Bloco 7 — Laboratório Kubernetes

**Duração:** 25 minutos

### Objetivo

O formando deverá conseguir consultar o ambiente, identificar o contexto ativo, criar recursos básicos a partir de YAML e utilizar labels e selectors.

### Tarefa 1 — Consultar o ambiente

```bash
kubectl get nodes
kubectl get namespaces
kubectl config current-context
```

### Tarefa 2 — Criar Namespace

```bash
kubectl create namespace formacao
kubectl get ns
```

### Tarefa 3 — Criar Pod por YAML

```bash
kubectl apply -f pod-demo.yaml
kubectl get pods -n formacao
```

### Tarefa 4 — Consultar Labels

```bash
kubectl get pods -n formacao --show-labels
```

### Tarefa 5 — Utilizar Selector

```bash
kubectl get pods -n formacao -l app=web
```

### Tarefa 6 — Limpeza

```bash
kubectl delete namespace formacao
```

---

# 6. Metodologia Recomendada

A sessão deverá alternar frequentemente entre:

```text
Conceito
   ↓
Exemplo
   ↓
Demonstração
   ↓
Experimentação
   ↓
Conclusão
```

## Estratégias

- Exposição dialogada.
- Demonstrações técnicas.
- Laboratórios guiados.
- Exercícios individuais.
- Discussão orientada.
- Questionamento dirigido.
- Observação direta.

## Adaptação à Turma

Para uma turma até 5 formandos:

- cada formando deverá trabalhar no seu próprio terminal, sempre que possível;
- o formador demonstra e os formandos reproduzem;
- utilizar perguntas individualizadas;
- promover discussão entre pares na análise de YAML;
- acompanhar de perto dificuldades técnicas;
- privilegiar validação imediata de cada tarefa.

---

# 7. Critérios de Sucesso

## Critérios Formais

A sessão deverá ser considerada concluída com sucesso quando forem verificadas as seguintes evidências:

- Container executado e validado.
- Volume montado e persistência confirmada.
- Namespace criado.
- Pod criado a partir de manifesto.
- Labels aplicadas e filtragem por selector validada.

## Checklist de Validação

| Critério | Evidência |
|---|---|
| Container executado | Container em execução |
| Logs consultados | Saída identificada pelo formando |
| Volume utilizado | Volume criado e montado |
| Persistência confirmada | Dados mantidos após recriação |
| Cluster consultado | Nodes e namespaces identificados |
| Contexto identificado | `current-context` reconhecido |
| Namespace criado | Namespace visível |
| Pod criado por YAML | Pod em estado esperado |
| Labels verificadas | Labels apresentadas |
| Selector utilizado | Recurso corretamente filtrado |

---

# 8. Revisão do Plano Anterior

## 8.1. Elementos Mantidos

A revisão mantém a estrutura pedagógica anteriormente definida:

- Módulos 1 e 2 na Sessão 1.
- Abordagem intermédia.
- Progressão de containers para Kubernetes.
- Utilização de `kubectl`.
- Introdução a YAML.
- Introdução a Namespaces, Pods, labels, selectors e annotations.
- Laboratório guiado.
- Metodologia expositiva e ativa.

A linha condutora mantém-se:

```text
Containerização
      ↓
Imagem
      ↓
Container
      ↓
Necessidade de gerir containers em escala
      ↓
Kubernetes
      ↓
Cluster
      ↓
API
      ↓
kubectl
      ↓
Manifest YAML
      ↓
Recursos Kubernetes
```

---

## 8.2. Alterações Introduzidas

### Distribuição Temporal

O plano anterior não contemplava formalmente um intervalo e atribuía 40 minutos ao laboratório Kubernetes.

A revisão passa a adotar:

- 15 minutos de intervalo;
- 25 minutos de laboratório Kubernetes;
- maior integração de prática nos blocos de containers.

### Componente Prática de Containers

A versão anterior era excessivamente centrada na prática Kubernetes.

A revisão acrescenta:

```text
run → ps → logs → stop/remove
```

e:

```text
container → volume → dados → novo container → dados mantidos
```

### Volumes

Passam de conteúdo predominantemente conceptual para uma competência prática básica.

### Principais Objetos Kubernetes

Mantêm-se no conteúdo, mas são apresentados apenas como mapa de navegação, evitando aprofundamento precoce.

### Troubleshooting

Retira-se desta sessão o troubleshooting intencional mais estruturado, reservando-o para sessões posteriores.

---

# 9. Sugestões Pedagógicas e Técnicas

## 9.1. Integrar a Prática ao Longo da Sessão

Evitar concentrar toda a prática no final.

Sugestão:

```text
Containers
   ↓
conceito + execução prática
   ↓
volume + persistência
   ↓
INTERVALO
   ↓
Kubernetes
   ↓
kubectl + YAML
   ↓
laboratório Kubernetes
```

Esta abordagem reduz a carga expositiva contínua e melhora a retenção dos conceitos.

---

## 9.2. Não Transformar a Sessão numa Formação de Docker

A Sessão 1 deve apenas fornecer a base necessária para compreender o ecossistema de containers.

Evitar aprofundar:

- Dockerfile.
- Build avançado.
- Multi-stage builds.
- Gestão avançada de redes.
- Registry privado.
- Segurança avançada.
- Otimização de imagens.

Estes temas devem ser desenvolvidos nas sessões posteriores quando previsto.

---

## 9.3. Não Aprofundar Prematuramente Kubernetes

Nesta sessão, não aprofundar:

- Deployments.
- ReplicaSets.
- Services.
- Ingress.
- PV/PVC.
- ConfigMaps.
- Secrets.
- RBAC.
- NetworkPolicies.
- Scheduling.
- Alta Disponibilidade.

Devem ser apenas mencionados como parte do mapa global.

---

## 9.4. Manter o Laboratório Kubernetes Simples

O laboratório de 25 minutos deve usar recursos previamente testados.

O ambiente deve estar disponível antes da sessão:

- `kubectl` instalado;
- `kubeconfig` funcional;
- cluster acessível;
- imagem utilizada previamente validada;
- manifest YAML preparado;
- ligação de rede funcional.

---

## 9.5. Preparar Contingência Técnica

O formador deverá ter:

- manifest de referência validado;
- comandos preparados;
- ambiente Kubernetes testado;
- imagem previamente disponível ou em cache, se necessário;
- procedimento rápido de limpeza;
- solução de contingência caso o acesso ao registry falhe.

---

## 9.6. Avaliação Formativa

A avaliação deverá ser predominantemente prática e contínua.

Perguntas de consolidação sugeridas:

1. Qual é a principal diferença arquitetural entre uma VM e um container?
2. Qual é a diferença entre imagem e container?
3. Qual é a função de um container runtime?
4. Porque é necessário um orquestrador?
5. Qual é o papel do Control Plane?
6. Para que serve o `kubeconfig`?
7. Qual é a relação entre label e selector?
8. O que representa o campo `kind` num manifest Kubernetes?

---

# 10. Sequência Definitiva da Sessão 1

| Horário Relativo | Conteúdo | Tipo Predominante |
|---|---|---|
| 0–40 min | Virtualização, containers e VMs | Conceito + discussão |
| 40–75 min | Runtimes, Docker, Podman e OCI | Conceito + prática |
| 75–110 min | Imagens, registry, networking, volumes e segurança | Conceito + prática |
| 110–125 min | **Intervalo** | — |
| 125–160 min | Kubernetes, cloud-native e arquitetura | Conceito + diagrama |
| 160–190 min | API, `kubectl`, contextos e `kubeconfig` | Demonstração + prática |
| 190–215 min | YAML, Pods, namespaces, labels, selectors e annotations | Conceito + análise |
| 215–240 min | Laboratório Kubernetes | Prática |
| | **Total** | **240 min** |

---

# 11. Resultado Esperado da Sessão

A sessão deverá terminar com o formando a compreender o seguinte percurso:

```text
Virtualização
      ↓
Containers
      ↓
Imagens / Runtimes / Volumes / Networking
      ↓
Necessidade de Orquestração
      ↓
Kubernetes
      ↓
Cluster
 ┌────┴─────┐
Control   Workers
 Plane
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

A Sessão 1 deve cumprir sobretudo o objetivo de **compreender** os fundamentos de Containers e Kubernetes, preparando os formandos para a Sessão 2, onde a progressão passa para **construir**, containerizar e configurar aplicações.
