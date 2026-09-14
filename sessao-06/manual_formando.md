# Manual do Formando — Sessão 6
## Kubernetes Admin III — Recursos, Scheduling e Segurança

## Identificação

| Elemento | Definição |
|---|---|
| **Formação** | Mini MBA em Orquestração de Containers com Kubernetes |
| **Sessão** | 6 de 10 |
| **Duração** | 4 horas / 240 minutos |
| **Nível** | Intermédio |
| **Módulo** | M9 — Recursos, Scheduling e Segurança |
| **Foco pedagógico** | **GOVERNAR O CLUSTER** |
| **Topologia** | 1 Control Plane + 2 Worker Nodes |
| **Runtime** | containerd |
| **CNI** | Calico |
| **Namespace de laboratório** | `s6-governance` |
| **Laboratório** | `labs/laboratorio_integrado_sessao_6.md` |
| **Mensagem central** | **Definir regras não chega: é necessário provar o seu efeito.** |

---

# 1. Como utilizar este manual

Este manual acompanha o laboratório integrado da Sessão 6. O objetivo não é memorizar YAML nem decorar comandos, mas compreender **que controlo administrativo estamos a aplicar, em que camada atua e que evidência demonstra o seu efeito**.

A sequência de trabalho é:

```text
CONCEITO
   ↓
PORQUE É NECESSÁRIO
   ↓
OBJETO / CAMPO / COMANDO
   ↓
APLICAR
   ↓
OBSERVAR
   ↓
PROVOCAR UM CASO NEGATIVO
   ↓
RECOLHER EVIDÊNCIA
   ↓
EXPLICAR
```

Nesta sessão, um `kubectl apply` bem-sucedido prova apenas que a API aceitou o objeto. Não prova, por si só, que o Scheduler escolheu o Node pretendido, que o RBAC bloqueia uma operação, que o `SecurityContext` produz o comportamento esperado ou que uma `NetworkPolicy` está efetivamente a ser aplicada pelo CNI.

Ao longo do manual, procure responder sistematicamente a estas perguntas:

1. **Que regra quero impor?**
2. **Que objeto ou campo Kubernetes representa essa regra?**
3. **Em que camada é tomada a decisão?**
4. **Que comando permite observar o estado efetivo?**
5. **Que teste positivo e/ou negativo prova o resultado?**

---

# 2. Objetivos da sessão

No final da sessão deverás ser capaz de:

- distinguir `requests` de `limits` de CPU e memória;
- relacionar `requests` com as decisões do Scheduler;
- interpretar `Capacity`, `Allocatable` e recursos já alocados num Node;
- distinguir uma rejeição em admission de um problema de scheduling;
- aplicar e interpretar `LimitRange` e `ResourceQuota`;
- controlar placement com labels, `nodeSelector` e Node Affinity;
- explicar `requiredDuringSchedulingIgnoredDuringExecution`;
- utilizar Pod Anti-Affinity para separar réplicas por topologia;
- distinguir `Pending` sem Node de um Pod já agendado mas ainda em criação;
- aplicar taints e tolerations sem confundir tolerância com obrigação de placement;
- distinguir Authentication, Authorization e Admission;
- distinguir `Role`, `ClusterRole`, `RoleBinding` e `ClusterRoleBinding`;
- criar uma `ServiceAccount` dedicada e aplicar RBAC mínimo;
- validar permissões e negações com `kubectl auth can-i`;
- utilizar `SecurityContext` para reduzir privilégios de um workload compatível;
- explicar por que Base64 não é encriptação de Secrets;
- aplicar `NetworkPolicy` com enforcement pelo Calico;
- construir uma política `default deny` e reabrir apenas fluxos necessários;
- provar simultaneamente um caminho permitido e um caminho bloqueado;
- relacionar cada falha com a camada onde realmente ocorreu.

---

# 3. Continuidade pedagógica

A Sessão 6 dá continuidade direta às sessões anteriores:

```text
Sessão 4
CONSTRUIR O CLUSTER
        ↓
Sessão 5
ADMINISTRAR WORKLOADS, REDE E DADOS
        ↓
Sessão 6
GOVERNAR O CLUSTER
```

A mudança de perspetiva é importante.

Na Sessão 5 a pergunta principal era:

> O workload funciona e os seus dados e acessos estão operacionais?

Nesta sessão passamos a perguntar:

> O workload funciona **dentro de regras controladas** de recursos, placement, identidade, autorização, privilégios e comunicação?

A questão orientadora é:

> **Como imponho regras, controlo a utilização dos recursos e provo objetivamente o que cada workload e cada identidade podem ou não fazer?**

---

# 4. Ambiente de referência

O laboratório reutiliza o cluster Kubernetes das sessões anteriores:

```text
Control Plane:  k8s-cp-01
Worker 1:       k8s-wk-01
Worker 2:       k8s-wk-03
Kubernetes:     1.36.4
Runtime:        containerd
CNI:            Calico 3.32.2
Namespace lab:  s6-governance
```

Os exercícios de scheduling utilizam os **dois Worker Nodes**. O Control Plane deve permanecer fora dos workloads normais da formação.

O plano da sessão utiliza Symfony Demo e PostgreSQL como caso transversal. No laboratório integrado, alguns checkpoints — sobretudo `NetworkPolicy` — utilizam propositadamente workloads mínimos (`nginx`, PostgreSQL e BusyBox) para isolar a variável em estudo. Esses workloads de diagnóstico não substituem conceptualmente o caso transversal; servem para tornar a prova de rede previsível e observável.

---

# 5. Governar significa controlar várias camadas

Os controlos desta sessão não atuam todos no mesmo ponto.

```text
Manifesto / pedido
       ↓
API Server
       ↓
Authentication
       ↓
Authorization
       ↓
Admission
       ↓
Objeto persistido
       ↓
Scheduler
       ↓
Node selecionado
       ↓
kubelet / runtime / CNI
       ↓
processo em execução
```

Isto explica por que dois sintomas parecidos podem ter causas completamente diferentes.

Exemplos:

```text
ResourceQuota excedida
→ Admission rejeita
→ objeto nem chega a existir

Request impossível
→ API aceita
→ objeto existe
→ Scheduler não encontra Node
→ Pod fica sem spec.nodeName

CNI com problema
→ Scheduler já escolheu Node
→ spec.nodeName existe
→ criação da sandbox falha depois
```

Uma das competências centrais desta sessão é **identificar a camada da falha antes de tentar corrigi-la**.

---

# 6. CPU e memória como recursos Kubernetes

Kubernetes permite declarar recursos de computação para cada container.

Nesta sessão trabalhamos sobretudo:

```text
CPU
Memória
```

## 6.1. Unidades de CPU

Exemplos:

```text
1      → uma CPU lógica
500m   → 0,5 CPU
250m   → 0,25 CPU
100m   → 0,1 CPU
```

O sufixo `m` significa *millicpu*.

## 6.2. Unidades de memória

No laboratório utilizamos unidades binárias:

```text
64Mi
128Mi
256Mi
2Gi
```

A unidade deve ser indicada explicitamente para evitar ambiguidades.

---

# 7. Requests e Limits

Um bloco típico é:

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "64Mi"
  limits:
    cpu: "250m"
    memory: "128Mi"
```

## 7.1. `requests`

`requests` representam a **necessidade declarada** do container para efeitos de scheduling.

Modelo mental:

```text
Pod declara request
      ↓
Scheduler avalia Nodes
      ↓
Node elegível tem de conseguir acomodar o request declarado
```

O Scheduler contabiliza os requests. Isto não significa que esteja a medir utilização instantânea de CPU ou memória para decidir o placement deste exercício.

## 7.2. `limits`

`limits` representam o teto de utilização definido para o container.

Modelo:

```text
request
= necessidade declarada para placement

limit
= teto de utilização em runtime
```

A distinção é fundamental: o Scheduler usa os `requests` para decidir elegibilidade; `limits` pertencem ao controlo de utilização do container em runtime.

## 7.3. Capacity e Allocatable

Antes de escolher valores, observar:

```bash
kubectl describe node k8s-wk-01
kubectl describe node k8s-wk-03
```

Procurar:

```text
Capacity
Allocatable
Allocated resources
```

Interpretação:

```text
Capacity
→ capacidade total reportada pelo Node

Allocatable
→ capacidade que Kubernetes considera disponível para Pods

Allocated resources
→ requests/limits atualmente contabilizados no Node
```

No laboratório, a observação vem **antes** de provocar um request impossível. Isto evita escolher um valor “mágico” sem conhecer o cluster.

---

# 8. Scheduling falhado por falta de recursos

Um Pod pode existir na API e continuar sem Node.

Exemplo pedagógico:

```yaml
resources:
  requests:
    cpu: "100"
    memory: "64Mi"
```

Neste cluster de laboratório, o pedido de `100` CPU é deliberadamente impossível.

O estado esperado é:

```text
Pod existe
   ↓
Scheduler avalia Nodes
   ↓
nenhum satisfaz o request
   ↓
Pod permanece Pending
   ↓
NODE = <none>
   ↓
Event FailedScheduling
```

Os comandos de diagnóstico são:

```bash
kubectl get pod resources-impossible \
  -n s6-governance \
  -o wide

kubectl describe pod resources-impossible \
  -n s6-governance

kubectl get events \
  -n s6-governance \
  --field-selector involvedObject.name=resources-impossible \
  --sort-by=.lastTimestamp
```

## Regra operacional

> **Antes de alterar um Pod `Pending`, ler os Events e confirmar se existe `spec.nodeName`.**

`Pending` é uma fase demasiado genérica para concluir, por si só, que houve `FailedScheduling`.

---

# 9. LimitRange

`LimitRange` aplica regras por objeto/container dentro de um Namespace.

No laboratório:

```yaml
spec:
  limits:
    - type: Container
      min:
        cpu: "10m"
        memory: "16Mi"
      max:
        cpu: "4"
        memory: "2Gi"
      defaultRequest:
        cpu: "100m"
        memory: "64Mi"
      default:
        cpu: "500m"
        memory: "256Mi"
```

## 9.1. Campos principais

| Campo | Função no laboratório |
|---|---|
| `min` | mínimo permitido por container |
| `max` | máximo permitido por container |
| `defaultRequest` | request aplicado quando o container não o declara |
| `default` | limit aplicado quando o container não o declara |

## 9.2. Defaults em admission

Depois de criar o `LimitRange`, um Pod sem bloco `resources` pode receber os valores por omissão.

```bash
kubectl run defaulted-resources \
  --image=nginx:stable-alpine \
  --restart=Never \
  -n s6-governance
```

Observar a especificação efetiva:

```bash
kubectl get pod defaulted-resources \
  -n s6-governance \
  -o jsonpath='{.spec.containers[0].resources}{"\n"}'
```

## 9.3. Não é retroativo

O `LimitRange` atua na criação/admission. Um Pod criado anteriormente não é reescrito automaticamente só porque o Namespace passou a ter um `LimitRange`.

Isto é uma boa demonstração da diferença entre:

```text
regra aplicada a novas admissões
        ≠
reconfiguração retroativa de objetos existentes
```

---

# 10. ResourceQuota

`ResourceQuota` controla o consumo agregado do Namespace.

Exemplo do laboratório:

```yaml
spec:
  hard:
    requests.cpu: "2"
    requests.memory: "2Gi"
    limits.cpu: "4"
    limits.memory: "4Gi"
    pods: "20"
```

Consultar:

```bash
kubectl get resourcequota -n s6-governance
kubectl describe resourcequota namespace-quota -n s6-governance
```

As duas colunas conceptuais mais importantes são:

```text
Used
Hard
```

## 10.1. LimitRange vs. ResourceQuota

| Objeto | Pergunta que responde |
|---|---|
| `LimitRange` | Quanto pode/deve pedir ou limitar cada container? |
| `ResourceQuota` | Quanto pode consumir/criar o Namespace no total? |

## 10.2. Rejeição por quota

O laboratório cria um Pod que pede `3 CPU`.

Esse valor é inferior ao máximo individual de `4 CPU` definido no `LimitRange`, mas ultrapassa a quota agregada de `requests.cpu=2`.

Resultado esperado:

```text
Forbidden
```

O ponto pedagógico é distinguir:

```text
Request impossível
API aceita
→ objeto existe
→ Scheduler falha

Quota excedida
Admission rejeita
→ objeto não existe
→ Scheduler nunca recebe o Pod
```

Não apresentar `ResourceQuota` como mecanismo de scheduling.

---

# 11. Como pensa o Scheduler

Para os objetivos desta sessão, podemos usar este modelo simplificado:

```text
Pod por agendar
      ↓
filtrar Nodes incompatíveis
      ↓
comparar Nodes elegíveis
      ↓
escolher placement
      ↓
registar Node no Pod
```

Restrições de recursos, labels, affinity, taints e outras regras podem retirar Nodes do conjunto elegível.

Quando a decisão falha, os Events ajudam a perceber **qual regra eliminou as opções disponíveis**.

---

# 12. Labels em Nodes

Labels são pares chave/valor associados a objetos Kubernetes.

No laboratório marcamos um Worker com:

```bash
kubectl label node k8s-wk-01 \
  training.goldconsulting/workload=apps
```

E observamos:

```bash
kubectl get nodes \
  -L training.goldconsulting/workload
```

A label não move Pods sozinha. É informação que pode ser utilizada por regras de scheduling.

---

# 13. nodeSelector

`nodeSelector` é a forma mais simples de exigir uma correspondência de labels.

```yaml
spec:
  nodeSelector:
    training.goldconsulting/workload: apps
```

Modelo:

```text
Pod exige label workload=apps
       ↓
Scheduler procura Nodes correspondentes
       ↓
Pod só é elegível nesses Nodes
```

Se nenhum Node tiver a label necessária:

```text
Pod existe
NODE = <none>
FailedScheduling
```

O laboratório cria deliberadamente `selector-impossible` para demonstrar esse caso.

---

# 14. Node Affinity

Node Affinity permite regras mais expressivas do que igualdade simples.

Exemplo:

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: training.goldconsulting/workload
              operator: In
              values:
                - apps
```

## 14.1. `requiredDuringSchedulingIgnoredDuringExecution`

A regra é obrigatória **durante o scheduling**.

No laboratório, depois de o Pod estar `Running`, removemos temporariamente a label do Node.

Resultado esperado:

```text
Pod continua Running no mesmo Node
```

Isto demonstra o componente:

```text
IgnoredDuringExecution
```

Ou seja, a alteração posterior da label não provoca expulsão automática do Pod por esta regra.

## 14.2. `preferredDuringSchedulingIgnoredDuringExecution`

É uma preferência, não uma exigência absoluta.

Nesta sessão é sobretudo importante distinguir:

```text
required
→ condição obrigatória para scheduling

preferred
→ preferência utilizada na escolha, quando possível
```

---

# 15. Pod Affinity e Pod Anti-Affinity

Enquanto Node Affinity relaciona o Pod com labels de Nodes, Pod Affinity/Anti-Affinity relaciona placement com **outros Pods**.

Nesta sessão praticamos Pod Anti-Affinity.

Exemplo:

```yaml
podAntiAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchLabels:
          app: antiaffinity-demo
      topologyKey: kubernetes.io/hostname
```

Interpretação:

```text
Pods app=antiaffinity-demo
não podem coexistir
na mesma topologia kubernetes.io/hostname
```

Com dois Workers elegíveis e duas réplicas:

```text
Réplica 1 → Worker A
Réplica 2 → Worker B
```

Ao escalar para três:

```text
Réplica 3
→ não existe terceiro hostname elegível
→ NODE <none>
→ PodScheduled=False
→ FailedScheduling
```

## 15.1. Anti-Affinity não é Alta Disponibilidade completa

A Anti-Affinity contribui para distribuição de réplicas, mas não cria, por si só:

```text
Control Plane HA
storage replicado
backup
recuperação automática de todas as dependências
```

É um mecanismo de placement, não uma solução integral de Alta Disponibilidade.

---

# 16. `Pending` não significa sempre “não agendado”

Esta distinção é importante no laboratório.

Caso A:

```text
status.phase = Pending
spec.nodeName vazio
PodScheduled=False
FailedScheduling
```

Isto é uma falha de scheduling.

Caso B:

```text
status.phase = Pending
spec.nodeName = k8s-wk-03
container ainda em criação
```

Aqui o Scheduler já fez o placement. O problema pode ocorrer depois, por exemplo na criação da sandbox de rede.

Se surgir:

```text
FailedCreatePodSandBox
```

investigar runtime/CNI, não Anti-Affinity.

Regra:

> **Classificar pela evidência da camada, não apenas pela palavra `Pending`.**

---

# 17. Taints e Tolerations

Labels/affinity ajudam a **atrair ou restringir** placement. Taints ajudam a **repelir** Pods.

Modelo:

```text
taint no Node
→ cria uma barreira

toleration no Pod
→ permite ultrapassar uma barreira compatível
```

No laboratório:

```bash
kubectl taint node "$LAB_WORKER" \
  training.goldconsulting/dedicated=lab:NoSchedule
```

## 17.1. `NoSchedule`

`NoSchedule` impede novo scheduling de Pods que não possuam uma toleration compatível.

Não expulsa automaticamente os Pods que já estavam em execução.

## 17.2. Toleration

Exemplo:

```yaml
tolerations:
  - key: training.goldconsulting/dedicated
    operator: Equal
    value: lab
    effect: NoSchedule
```

A mensagem principal é:

```text
Toleration
= “este taint não me exclui”

Toleration
≠ “tenho de correr neste Node”
```

No laboratório, quem restringe o Pod ao Worker marcado é o `nodeSelector`; a toleration apenas remove a barreira criada pelo taint.

Para workloads realmente dedicados, é comum combinar conceptualmente:

```text
taint / toleration
       +
label / nodeSelector ou affinity
```

---

# 18. Authentication, Authorization e Admission

Um pedido à API pode ser pensado assim:

```text
Quem és?
Authentication
     ↓
O que podes fazer?
Authorization
     ↓
A operação cumpre as políticas de admissão?
Admission
     ↓
Persistir / executar
```

## 18.1. Authentication

Responde à pergunta:

> Que identidade está a fazer o pedido?

Pode tratar-se, por exemplo, de uma identidade humana ou de uma ServiceAccount.

## 18.2. Authorization

Responde à pergunta:

> Esta identidade pode executar este verbo sobre este recurso neste escopo?

Nesta sessão utilizamos RBAC para expressar a resposta.

## 18.3. Admission

Mesmo uma identidade autorizada pode encontrar uma regra de admission que rejeite o objeto, como acontece no teste de `ResourceQuota`.

---

# 19. RBAC: o modelo mental

RBAC pode ser resumido por:

```text
Subject
   ↓
RoleBinding
   ↓
Role
   ↓
verbs + apiGroups + resources
```

No laboratório:

```text
ServiceAccount: app-reader
        ↓
RoleBinding: app-reader-binding
        ↓
Role: app-reader-role
        ↓
get/list Pods e ConfigMaps
```

## 19.1. Role

Uma `Role` define regras num Namespace.

Exemplo:

```yaml
rules:
  - apiGroups: [""]
    resources:
      - pods
      - configmaps
    verbs:
      - get
      - list
```

Elementos a interpretar:

| Campo | Pergunta |
|---|---|
| `apiGroups` | em que grupo da API estão os recursos? |
| `resources` | sobre que tipos de recurso atua a regra? |
| `verbs` | que ações são permitidas? |

## 19.2. RoleBinding

Liga um ou mais subjects a uma `Role` ou `ClusterRole` no escopo do Namespace do binding.

## 19.3. ClusterRole e ClusterRoleBinding

Conceptualmente:

```text
Role / RoleBinding
→ governação namespaced

ClusterRole / ClusterRoleBinding
→ regras e/ou associação ao nível do cluster
```

Nesta prática principal não precisamos de conceder permissões cluster-wide à ServiceAccount `app-reader`.

---

# 20. ServiceAccounts

Uma `ServiceAccount` representa uma identidade utilizada por workloads dentro do cluster.

No laboratório:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-reader
  namespace: s6-governance
```

A abordagem recomendada é:

```text
workload precisa de falar com a API
→ ServiceAccount dedicada
→ RBAC mínimo

workload não precisa da API
→ não montar credenciais desnecessariamente
```

## 20.1. `automountServiceAccountToken`

Quando um workload não necessita de comunicar com a Kubernetes API, o laboratório demonstra:

```yaml
automountServiceAccountToken: false
```

Isto reduz a exposição de credenciais desnecessárias dentro do Pod.

---

# 21. Validar RBAC com `kubectl auth can-i`

O comando:

```bash
kubectl auth can-i get pods \
  -n s6-governance \
  --as=system:serviceaccount:s6-governance:app-reader
```

pergunta ao API Server se a identidade indicada seria autorizada a executar a operação.

No laboratório esperamos:

```text
get pods      → yes
delete pods   → no
get secrets   → no
```

## 21.1. `--as`

`--as` utiliza impersonation para testar outra identidade.

A identidade administrativa que executa o comando tem de possuir permissão para impersonation.

## 21.2. Menor privilégio

O objetivo não é “dar acesso suficiente até deixar de haver erros”. É definir explicitamente o mínimo necessário e conseguir provar tanto:

```text
Ação necessária → yes
```

como:

```text
Ação não necessária → no
```

---

# 22. SecurityContext

`SecurityContext` define aspetos de segurança do Pod e/ou do container.

No laboratório usamos um BusyBox simples para reduzir variáveis e demonstrar controlos compatíveis com a imagem.

Configuração principal:

```yaml
spec:
  automountServiceAccountToken: false
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: shell
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop:
            - ALL
```

---

# 23. Execução non-root

```yaml
runAsNonRoot: true
runAsUser: 10001
runAsGroup: 10001
```

No laboratório verificamos o comportamento real:

```bash
kubectl exec -n s6-governance security-demo -- id
```

Esperado:

```text
uid=10001 gid=10001 groups=10001
```

A prova não é apenas a presença do YAML; é o processo efetivamente executar com o UID/GID esperados.

---

# 24. `allowPrivilegeEscalation`

```yaml
allowPrivilegeEscalation: false
```

Expressa que o processo do container não deve adquirir mais privilégios através dos mecanismos abrangidos por este controlo.

O princípio pedagógico é:

> Um workload deve receber apenas os privilégios necessários para a sua função.

---

# 25. Linux capabilities

No laboratório:

```yaml
capabilities:
  drop:
    - ALL
```

O objetivo é começar por um conjunto mínimo quando a aplicação suporta esse modelo.

Não transformar `drop: ALL` numa regra mecânica para todas as imagens. Um workload real pode necessitar de determinadas capacidades; nesse caso deve ser analisado o menor conjunto compatível.

---

# 26. Filesystem read-only

```yaml
readOnlyRootFilesystem: true
```

O laboratório testa:

```bash
kubectl exec -n s6-governance security-demo -- \
  sh -c 'touch /teste-escrita'
```

Esperado:

```text
Read-only file system
```

Isto demonstra a regra efetiva.

Se uma aplicação necessita de escrever, não significa que tenhamos de tornar todo o filesystem gravável. Devem ser fornecidos volumes graváveis apenas nos caminhos necessários, quando aplicável.

---

# 27. Seccomp

Ao nível do Pod:

```yaml
securityContext:
  seccompProfile:
    type: RuntimeDefault
```

O laboratório não pretende aprofundar perfis seccomp personalizados. O objetivo é reconhecer `RuntimeDefault` como parte de uma postura de menor privilégio e confirmar a configuração efetiva no objeto.

---

# 28. Hardening deve ser compatível

Mensagem principal:

> **Hardening não consiste em copiar um `SecurityContext` “forte”; consiste em aplicar o menor conjunto de privilégios que permita ao workload funcionar corretamente.**

Um `SecurityContext` incompatível com a imagem pode impedir a aplicação de funcionar. Por isso a sequência correta é:

```text
compreender necessidade do workload
        ↓
aplicar controlo mínimo
        ↓
executar
        ↓
validar comportamento
```

---

# 29. Secrets

Um Kubernetes `Secret` é um objeto destinado a transportar dados que devem ser tratados como sensíveis.

No laboratório utilizamos exclusivamente valores fictícios:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-demo
  namespace: s6-governance
type: Opaque
stringData:
  username: demo
  password: lab-only-not-a-real-secret
```

## 29.1. `stringData`

`stringData` permite fornecer texto na criação. Kubernetes transforma esses valores para a representação utilizada em `data`.

## 29.2. Base64 não é encriptação

Esta distinção deve ficar clara:

```text
Base64
= codificação
≠ encriptação
```

Não devemos dizer que um Secret está “seguro porque está em Base64”.

## 29.3. Proteção por controlo de acesso

No laboratório, a ServiceAccount `app-reader` não tem permissão para ler Secrets:

```bash
kubectl auth can-i get secrets \
  -n s6-governance \
  --as=system:serviceaccount:s6-governance:app-reader
```

Esperado:

```text
no
```

A proteção de Secrets depende também de medidas administrativas que ficam apenas enquadradas nesta sessão, como encriptação em repouso e secret stores externos.

## 29.4. Evitar exposição desnecessária

Durante a formação:

- não utilizar credenciais reais;
- não colocar passwords reais em ficheiros versionados;
- não copiar valores de Secrets para evidências;
- preferir consultar metadata e nomes das chaves quando isso é suficiente para o objetivo pedagógico.

---

# 30. Modelo de rede antes de NetworkPolicy

Antes das policies, o cenário de diagnóstico é:

```text
net-client
   │
   ├── HTTP → net-app:80
   │
   └── TCP  → net-db:5432

net-app
   └── TCP → net-db:5432
```

Os workloads mínimos são utilizados para isolar a variável **rede**.

A primeira tarefa é provar a baseline:

```text
DNS                         → OK
net-client → net-app:80     → OK
net-client → net-db:5432    → OK
```

Sem baseline saudável, não é possível atribuir corretamente uma falha às policies aplicadas depois.

---

# 31. NetworkPolicy depende do CNI

Criar um objeto `NetworkPolicy` na API não garante, por si só, enforcement de rede.

Nesta formação, o cluster utiliza **Calico**, que fornece o enforcement necessário ao laboratório.

Antes de aplicar policies, confirmar:

```bash
kubectl get pods -A | grep -i calico
kubectl get pods -n kube-system --show-labels
kubectl get svc -n kube-system
```

A política só fica validada quando o comportamento real da rede corresponde ao pretendido.

---

# 32. `podSelector`

Uma `NetworkPolicy` aplica-se aos Pods selecionados por `spec.podSelector`.

Exemplo:

```yaml
podSelector:
  matchLabels:
    component: app
```

Seleciona Pods com:

```text
component=app
```

Um selector vazio:

```yaml
podSelector: {}
```

seleciona todos os Pods do Namespace da policy.

---

# 33. Ingress e Egress em NetworkPolicy

No contexto de `NetworkPolicy`:

```text
Ingress
→ tráfego que entra nos Pods selecionados

Egress
→ tráfego que sai dos Pods selecionados
```

Uma policy pode declarar um ou ambos em:

```yaml
policyTypes:
  - Ingress
  - Egress
```

Quando aplicamos `default deny` nas duas direções, os Pods selecionados ficam isolados nessas direções, exceto pelo que outras policies permitirem.

---

# 34. Default deny

A policy do laboratório é:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: s6-governance
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

Não existem regras `ingress` nem `egress`.

O resultado esperado é bloquear os fluxos anteriormente funcionais.

É importante testar separadamente:

```text
DNS
HTTP por ClusterIP
PostgreSQL por ClusterIP
```

Ao usar diretamente o `ClusterIP`, conseguimos provar bloqueio de rede sem confundir o resultado com falha de DNS.

---

# 35. DNS depois de default deny

Uma policy de `default deny` de egress pode bloquear também o acesso ao DNS do cluster.

Por isso, o laboratório identifica primeiro as labels reais dos Pods DNS e depois cria uma autorização explícita para UDP/TCP 53.

Exemplo:

```yaml
egress:
  - to:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: kube-system
        podSelector:
          matchLabels:
            k8s-app: kube-dns
    ports:
      - protocol: UDP
        port: 53
      - protocol: TCP
        port: 53
```

No cluster de referência a label validada é:

```text
k8s-app=kube-dns
```

Não assumir que outro cluster utiliza obrigatoriamente a mesma label. Observar primeiro.

---

# 36. Policies são aditivas

Este é um dos conceitos mais importantes do laboratório.

Quando aplicamos:

```text
default-deny-all
+
allow-dns
```

`allow-dns` não “substitui” a policy anterior.

As permissões resultam da combinação das policies aplicáveis.

Assim, depois de permitir DNS podemos ter:

```text
DNS                         → OK
net-client → net-app:80     → BLOQUEADO
net-client → net-db:5432    → BLOQUEADO
```

Isto prova que apenas o fluxo explicitamente reaberto passou a funcionar.

---

# 37. Quando ambos os lados estão isolados

Para permitir:

```text
cliente → aplicação
```

num cenário em que os dois lados estão isolados, o laboratório autoriza:

```text
egress do cliente
       +
ingress da aplicação
```

O mesmo princípio é utilizado para:

```text
aplicação → PostgreSQL
```

com egress no Pod `component=app` e ingress no Pod `component=db`.

O resultado final pretendido é:

```text
DNS                      PERMITIDO
cliente → aplicação      PERMITIDO
aplicação → PostgreSQL   PERMITIDO
cliente → PostgreSQL     BLOQUEADO
```

---

# 38. Porque testar um caminho bloqueado?

Se testarmos apenas caminhos permitidos, sabemos que a aplicação comunica, mas não sabemos se a segmentação está realmente a restringir aquilo que deveria.

Por isso, a regra da sessão é:

> **Uma `NetworkPolicy` só está validada quando um fluxo permitido funciona e um fluxo proibido falha.**

Isto transforma uma configuração declarada numa política efetivamente comprovada.

---

# 39. Diagnóstico por camada

A tabela seguinte resume sintomas importantes do laboratório.

| Sintoma | Camada provável | Evidência principal |
|---|---|---|
| `Forbidden` ao criar objeto por quota | Admission | mensagem da API / `ResourceQuota` |
| Pod existe, `NODE=<none>`, `FailedScheduling` | Scheduling | `describe pod`, Events, `PodScheduled=False` |
| Pod tem Node mas está em `ContainerCreating` | pós-scheduling | `spec.nodeName`, Events |
| `FailedCreatePodSandBox` | runtime/CNI | Events do Pod |
| `kubectl auth can-i` devolve `no` | Authorization | resposta do API Server |
| `touch /...` falha com read-only | segurança do processo | comportamento do container |
| DNS falha após default deny | NetworkPolicy egress | `nslookup` |
| HTTP por ClusterIP falha com DNS fora da equação | NetworkPolicy | teste direto ao IP |

A abordagem correta é:

```text
SINTOMA
   ↓
CAMADA
   ↓
EVIDÊNCIA
   ↓
HIPÓTESE
   ↓
ALTERAÇÃO
   ↓
NOVA VALIDAÇÃO
```

---

# 40. Flags e opções recorrentes

## `-n` / `--namespace`

```bash
kubectl get pods -n s6-governance
```

Define explicitamente o Namespace alvo.

## `-A` / `--all-namespaces`

```bash
kubectl get pods -A
```

Consulta todos os Namespaces.

## `-o wide`

```bash
kubectl get pods -o wide
```

Acrescenta informação operacional, incluindo Node e IP quando aplicável.

## `-o jsonpath=...`

Extrai campos concretos de objetos Kubernetes sem imprimir todo o YAML/JSON.

## `-f -`

```bash
cat <<'EOF' | kubectl apply -f -
...
EOF
```

O hífen significa que o manifesto é lido de `stdin`.

## `--dry-run=client -o yaml`

Permite gerar a representação YAML de um objeto sem o criar diretamente. No laboratório é usado em conjunto com `kubectl apply -f -` para obter um fluxo repetível.

## `--timeout`

Limita o tempo máximo de espera em operações como `kubectl wait` ou `kubectl rollout status`.

## `--as`

Testa autorização usando impersonation de outra identidade.

## `--ignore-not-found`

Evita que uma limpeza falhe apenas porque um objeto já não existe.

---

# 41. Manifests comentados da Sessão 6

A diretoria `manifests/` contém versões comentadas dos principais objetos do laboratório:

```text
00-namespace.yaml
01-pod-resources.yaml
02-limitrange.yaml
03-resourcequota.yaml
04-node-selector.yaml
05-node-affinity.yaml
06-pod-antiaffinity.yaml
07-toleration.yaml
08-serviceaccount.yaml
09-role.yaml
10-rolebinding.yaml
11-security-context.yaml
12-secret-demo.yaml
13-netpol-default-deny.yaml
14-netpol-allow-dns.yaml
15-netpol-allow-app.yaml
16-netpol-allow-db.yaml
17-networkpolicy-test-workloads.yaml
```

Estes ficheiros servem para:

- reler os campos sem o ruído dos comandos circundantes;
- comparar YAML declarativo com o efeito observado;
- modificar uma variável de cada vez em exercícios de consolidação;
- reutilizar os objetos sem voltar a copiar os blocos inline do laboratório.

O laboratório integrado continua a ser a sequência operacional canónica. Os manifests são material de apoio, não uma segunda ordem de execução independente.

---

# 42. Exercícios de consolidação

## Exercício 1 — Admission ou Scheduler?

Para cada situação, indicar a camada principal:

1. criação de Pod rejeitada porque ultrapassa `requests.cpu` da quota;
2. Pod criado mas sem Node devido a request impossível;
3. Pod com Node atribuído mas sandbox de rede não criada.

**Objetivo:** distinguir Admission, Scheduling e runtime/CNI.

## Exercício 2 — LimitRange

Altera temporariamente `defaultRequest.cpu` para outro valor pequeno e cria um novo Pod sem `resources`.

Perguntas:

- o novo valor surge no Pod novo?
- o Pod antigo foi alterado?
- porquê?

## Exercício 3 — Affinity

Substitui a label `training.goldconsulting/workload=apps` por outra label de laboratório e adapta a Node Affinity.

Prova:

- que o Pod só é colocado num Node elegível;
- que remover a label depois do scheduling não expulsa automaticamente o Pod.

## Exercício 4 — RBAC

Adiciona temporariamente `watch` à Role `app-reader-role` e valida:

```bash
kubectl auth can-i watch pods ...
```

Depois remove a permissão e comprova a negação.

**Objetivo:** perceber que o RBAC deve ser demonstrável e reversível.

## Exercício 5 — NetworkPolicy

Mantendo `default deny`, cria uma policy que permita ao `net-client` chegar à aplicação numa porta diferente **apenas se existir um serviço real nessa porta**. Não criar uma regra sem workload que a justifique.

**Objetivo:** ligar política a uma necessidade real, em vez de acumular permissões abstratas.

---

# 43. Questões de revisão

1. Porque é que `requests` e `limits` não são sinónimos?
2. Que diferença existe entre `Capacity` e `Allocatable`?
3. Como provas que um Pod `Pending` ainda não foi agendado?
4. Porque é que `ResourceQuota` não deve ser descrita como mecanismo de scheduling?
5. O que acontece aos Pods antigos quando é criado um `LimitRange`?
6. Quando preferir `nodeSelector` e quando é necessária a expressividade de Node Affinity?
7. O que significa `IgnoredDuringExecution` no exercício de Node Affinity?
8. Porque é que uma terceira réplica da Anti-Affinity fica não agendável com apenas dois Workers?
9. Uma toleration força o Pod a correr no Node com taint?
10. Qual é a diferença entre Authentication e Authorization?
11. Que papel desempenha um `RoleBinding`?
12. Porque validamos RBAC com ações permitidas **e** negadas?
13. Quando faz sentido `automountServiceAccountToken: false`?
14. Porque não devemos aplicar um `SecurityContext` rígido sem validar compatibilidade da imagem?
15. Porque Base64 não deve ser confundido com encriptação?
16. Porque é necessário permitir DNS após um `default deny` de egress?
17. Porque um `kubectl apply` bem-sucedido não prova enforcement de `NetworkPolicy`?
18. Porque devemos testar comunicação por `ClusterIP` quando queremos separar falha de DNS de falha de rede?

---

# 44. Resumo dos conceitos principais

```text
REQUEST
→ necessidade declarada para scheduling

LIMIT
→ teto de utilização do container

LIMITRANGE
→ regras/defaults por container/objeto

RESOURCEQUOTA
→ limites agregados do Namespace

NODESELECTOR
→ correspondência simples de labels

NODE AFFINITY
→ regras de placement mais expressivas

POD ANTI-AFFINITY
→ separar Pods segundo uma topologia

TAINT
→ repele

TOLERATION
→ remove uma barreira compatível

SERVICEACCOUNT
→ identidade de workload

ROLE
→ conjunto de permissões namespaced

ROLEBINDING
→ associa identidade a permissões

SECURITYCONTEXT
→ reduz privilégios do processo/container

SECRET
→ objeto de dados sensíveis; Base64 não é encriptação

NETWORKPOLICY
→ controla fluxos L3/L4 para Pods selecionados
```

---

# 45. Checklist final do formando

- [ ] Consigo explicar `requests` e `limits` sem os tratar como sinónimos.
- [ ] Sei consultar `Capacity`, `Allocatable` e recursos alocados.
- [ ] Consigo provar `FailedScheduling` através de Events e `NODE=<none>`.
- [ ] Distingo rejeição de Admission de falha do Scheduler.
- [ ] Distingo `LimitRange` de `ResourceQuota`.
- [ ] Consigo explicar que `LimitRange` não é retroativo sobre Pods existentes.
- [ ] Sei aplicar labels e `nodeSelector`.
- [ ] Distingo `nodeSelector` de Node Affinity.
- [ ] Sei explicar `requiredDuringSchedulingIgnoredDuringExecution`.
- [ ] Consigo interpretar Pod Anti-Affinity e `topologyKey`.
- [ ] Não concluo “falha de scheduling” apenas porque vejo `Pending`.
- [ ] Distingo taint de toleration.
- [ ] Sei que toleration não força placement.
- [ ] Distingo Authentication, Authorization e Admission.
- [ ] Distingo `Role`/`RoleBinding` de `ClusterRole`/`ClusterRoleBinding`.
- [ ] Consigo validar RBAC com `kubectl auth can-i` e `--as`.
- [ ] Sei explicar quando evitar o automount do token da ServiceAccount.
- [ ] Consigo validar UID non-root, filesystem read-only e seccomp no Pod de laboratório.
- [ ] Sei explicar por que hardening deve ser compatível com o workload.
- [ ] Sei explicar por que Base64 não é encriptação.
- [ ] Sei que `NetworkPolicy` depende de enforcement pelo CNI.
- [ ] Consigo explicar `Ingress` e `Egress` no contexto de NetworkPolicy.
- [ ] Sei que policies são aditivas.
- [ ] Consigo provar um fluxo permitido e outro bloqueado.
- [ ] Consigo distinguir falha de DNS de bloqueio de rede por ClusterIP.
- [ ] Consigo mapear uma anomalia à camada técnica correta antes de alterar o cluster.

---

# 46. Regra de evidência da Sessão 6

A sessão fica consolidada quando consegues apresentar e explicar:

```text
preflight e CNI validados
+
requests/limits observáveis
+
quota aplicada e rejeição explicada
+
LimitRange e defaults comprovados
+
Pending justificado por Event e NODE <none>
+
placement controlado por labels/selector/affinity
+
IgnoredDuringExecution demonstrado
+
Anti-Affinity positiva e negativa demonstradas
+
taint/toleration demonstrados
+
permissão RBAC necessária = yes
+
permissões desnecessárias = no
+
SecurityContext comprovado pelo comportamento
+
Secret tratado sem exposição desnecessária
+
DNS reaberto explicitamente após default deny
+
cliente → aplicação permitido
+
aplicação → PostgreSQL permitido
+
cliente → PostgreSQL bloqueado
```

---

# 47. Continuidade para a Sessão 7

A Sessão 6 termina com controlos preventivos:

```text
prevenir
restringir
controlar
provar
```

A questão seguinte é:

> **Mesmo com estas regras, o que fazemos quando o sistema falha, degrada ou apresenta sintomas que não compreendemos?**

A progressão pedagógica passa então de:

```text
Sessão 6
GOVERNAR
→ recursos
→ scheduling
→ identidade
→ autorização
→ hardening
→ segmentação
```

para:

```text
Sessão 7
OBSERVAR
→ diagnosticar
→ relacionar sintomas com causas
→ recuperar
```

Esta transição prepara o trabalho posterior de monitorização, troubleshooting e disponibilidade sem misturar esses objetivos com a governação tratada nesta sessão.
