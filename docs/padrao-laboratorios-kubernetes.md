# Padrão Canónico dos Laboratórios — Docker e Kubernetes

Este documento define o molde pedagógico comum para os laboratórios técnicos da formação, com aplicação imediata às **Sessões 2 a 8**. O objetivo é evitar que cada sessão evolua para uma estrutura diferente e garantir que a prática é orientada por compreensão, evidência, diagnóstico e validação.

A Sessão 4 continua a ser a principal referência de estilo para os laboratórios Kubernetes; as Sessões 2 e 3 aplicam o mesmo princípio aos comandos Docker, Compose, Dockerfiles e ficheiros YAML.

## 1. Estrutura canónica de cada checkpoint

Sempre que o tema o permita, cada checkpoint deve seguir esta sequência:

```text
OBJETIVO / O QUE ESTAMOS A FAZER
        ↓
PORQUE É NECESSÁRIO
        ↓
ONDE EXECUTAR, quando o host/nó/contexto for relevante
        ↓
COMANDO / MANIFESTO
        ↓
FLAGS / CAMPOS IMPORTANTES
        ↓
OUTPUT / ESTADO ESPERADO
        ↓
O QUE OBSERVAR
        ↓
TESTE NEGATIVO ou FALHA CONTROLADA, quando fizer sentido
        ↓
CHECKPOINT — NÃO AVANÇAR SEM VALIDAR
        ↓
EVIDÊNCIA A REGISTAR
```

O laboratório não deve apresentar um bloco de comandos sem explicar **o que faz**, **porque é executado naquele momento** e **como se prova que produziu o efeito esperado**.

O teste negativo não deve ser artificial. Deve existir quando permite provar uma fronteira real, por exemplo:

- porta Docker do host já ocupada;
- containers em redes Docker sem interseção;
- dados guardados apenas no filesystem do container e perdidos após remoção;
- aplicação saudável mas dependência ainda indisponível;
- Pod admitido pela API mas não agendável;
- PVC `Pending` antes do primeiro consumidor;
- RBAC com uma ação permitida e outra negada;
- NetworkPolicy com um fluxo permitido e outro bloqueado;
- Service sem EndpointSlice por selector incorreto;
- operação destrutiva apenas depois de um health gate válido.

## 2. Regra de explicação de comandos e flags

Sempre que surge um comando novo ou uma flag com relevância pedagógica, explicar o seu papel.

Exemplo Docker:

```bash
docker run -d --name web -p 8080:80 nginx:alpine
```

Deve ficar explícito que:

```text
-d            → execução em background
--name web    → nome estável para operações seguintes
-p 8080:80    → HOST:CONTAINER
nginx:alpine  → imagem:tag usada para criar a instância
```

Exemplo Kubernetes:

```bash
kubectl get pods -n s6-governance -o wide
```

Deve ficar explícito que:

```text
-n            → Namespace alvo
-o wide       → acrescenta informação operacional como Node/IP
```

Não é necessário repetir a explicação completa em todas as ocorrências da mesma flag; é necessário explicá-la **na primeira utilização relevante** e voltar a destacá-la quando o significado contextual mudar.

## 3. Regra para YAML, Compose e Dockerfile

Os ficheiros técnicos usados pelo formando devem ser comentados quando os comentários ajudarem a compreender a intenção.

O comentário deve explicar **porquê**, e não apenas traduzir a chave.

Bom exemplo:

```yaml
# Named volume: separa os dados do ciclo de vida do container PostgreSQL.
volumes:
  - db-data:/var/lib/postgresql/data
```

Evitar comentários sem valor pedagógico:

```yaml
# Volumes
volumes:
```

Para YAML Kubernetes, comentar especialmente campos com impacto em comportamento, por exemplo:

- selectors e labels;
- `serviceName` de StatefulSet;
- probes;
- `storageClassName`, access modes e requests de storage;
- requests/limits;
- affinity/anti-affinity;
- taints/tolerations do lado do workload;
- ServiceAccounts e RBAC;
- `SecurityContext`;
- `NetworkPolicy`;
- `parentRefs`, listeners e backends da Gateway API.

Para Docker/Compose, comentar especialmente:

- `FROM`, stages e `COPY --from`;
- cache/layers e ordem das instruções;
- `ARG` vs. `ENV`;
- `HEALTHCHECK`;
- `ports` (`HOST:CONTAINER`);
- `depends_on` e respetiva limitação;
- networks;
- bind mounts/named volumes;
- restart policy, resource limits e logging;
- secrets e respetiva origem.

Comentários não devem alterar a semântica dos ficheiros nem substituir a validação prática.

## 4. Regra de progressão

```text
COMPREENDER
    ↓
EXECUTAR
    ↓
OBSERVAR
    ↓
PROVOCAR / TESTAR
    ↓
RECOLHER EVIDÊNCIA
    ↓
EXPLICAR
    ↓
AVANÇAR
```

Um comando que termina sem erro prova apenas que a ferramenta aceitou a operação. A conclusão pedagógica exige evidência do comportamento efetivo.

Exemplos:

```text
docker compose up -d bem-sucedido
≠ aplicação necessariamente pronta

kubectl apply bem-sucedido
≠ política ou workload necessariamente com o efeito pretendido
```

## 5. Checkpoint e gate

Cada `CPx` é um ponto de controlo. O formando não deve avançar enquanto não conseguir responder a três perguntas:

1. Qual era o resultado esperado?
2. Que evidência demonstra o resultado real?
3. Se o resultado divergir, em que camada está a falha?

Em Docker, a classificação inicial pode seguir:

```text
Engine / objeto
    ↓
processo / logs
    ↓
configuração
    ↓
rede / portas
    ↓
storage / mounts
    ↓
aplicação / dependência
```

Em Kubernetes, privilegiar:

```text
API / admission
    ↓
Scheduling
    ↓
Runtime / CNI / storage
    ↓
Workload / aplicação
    ↓
Rede / Service / policy
```

## 6. Health gate antes de operações de risco

Antes de update/rollback, upgrade, eliminação de storage, restore, alterações de rede potencialmente disruptivas ou outros passos destrutivos, deve existir um health gate explícito.

Um health gate deve validar apenas o que é necessário para distinguir um problema preexistente de uma falha introduzida pelo exercício.

Sempre que existirem conceitos diferentes de saúde/prontidão, distingui-los explicitamente. Exemplo do cenário Symfony:

```text
/health → saúde básica da aplicação
/ready  → prontidão incluindo a dependência de dados
```

## 7. Evidências e fecho pedagógico

Cada laboratório integrado deve terminar, quando aplicável, com:

- checklist de autoavaliação em primeira pessoa: `Consigo...`, `Distingo...`, `Sei explicar...`;
- uma **Regra de evidência da Sessão X**;
- uma `folha_evidencias.md` quando a sessão tiver laboratório integrado extenso;
- limpeza ou reposição do estado alterado pelo laboratório.

A evidência deve registar resultados **e interpretação**, e não apenas capturas de comandos.

## 8. Bootstrap canónico do repositório para sessões Kubernetes

As Sessões 4 a 8 devem usar o mesmo padrão robusto. Não assumir que a shell abriu dentro do repositório e não destruir uma diretoria não-Git com o mesmo nome.

```bash
clear

REPO_DIR="$HOME/formacao-kubernetes"
REPO_URL="https://github.com/Skullclamp/formacao-kubernetes.git"

if [ -d "$REPO_DIR/.git" ]; then
  git -C "$REPO_DIR" switch main
  git -C "$REPO_DIR" pull --ff-only origin main
elif [ -e "$REPO_DIR" ]; then
  BACKUP_DIR="${REPO_DIR}.bak-$(date +%Y%m%d-%H%M%S)"
  mv "$REPO_DIR" "$BACKUP_DIR"
  echo "Diretoria anterior preservada em: $BACKUP_DIR"
  git clone --branch main --single-branch "$REPO_URL" "$REPO_DIR"
else
  git clone --branch main --single-branch "$REPO_URL" "$REPO_DIR"
fi

git -C "$REPO_DIR" branch --show-current
git -C "$REPO_DIR" status --short
```

Depois, cada sessão entra na respetiva diretoria de trabalho.

## 9. Continuidade da topologia

Nenhum Node deve surgir num laboratório sem explicação documental.

Quando um Node adicional for preparado pelo formador fora do tempo de aula, os materiais devem indicar explicitamente:

- quando foi introduzido;
- quem o preparou;
- que não faz parte do tempo pedagógico da sessão;
- qual a baseline esperada;
- que o `join` segue o procedimento já demonstrado anteriormente;
- que o preflight da sessão valida o Node antes de depender dele.

Na edição atual, a Sessão 4 termina com `k8s-cp-01 + k8s-wk-01`. Antes da Sessão 5, o formador adiciona `k8s-wk-03` fora dos 240 minutos, reutilizando o procedimento de `kubeadm join` já praticado na Sessão 4. O nome `k8s-wk-03` corresponde ao inventário real do laboratório e não representa um checkpoint omitido nem implica a existência pedagógica de um `k8s-wk-02`.

## 10. Convenção de Namespaces

Para novos laboratórios Kubernetes, adotar preferencialmente:

```text
s<sessão>-<slug>
```

Exemplo:

```text
s6-governance
```

O Namespace `sessao5` é mantido na Sessão 5 porque o laboratório foi validado de ponta a ponta com esse nome e a mudança afetaria DNS/FQDNs, comandos e evidências já ensaiadas sem acrescentar valor pedagógico. Esta é uma exceção documentada, não um segundo padrão para novos materiais.

## 11. Aplicação às sessões revistas

- **Sessão 2:** cada lab curto segue checkpoint, explicação de comandos/flags, observação e evidência; `compose.yaml` é comentado pedagogicamente.
- **Sessão 3:** laboratório integrado mantém a sequência manual → observar → explicar → automatizar; Dockerfiles e Compose explicam os campos relevantes e os comandos incluem interpretação de flags/output.
- **Sessão 4:** laboratório de referência para estrutura de checkpoints Kubernetes.
- **Sessão 5:** mantém checkpoints, testes controlados, evidência e manifests externos comentados.
- **Sessão 6:** mantém checkpoints de governação e dispõe de uma coleção numerada de manifests comentados para requests/limits, scheduling, RBAC, SecurityContext e NetworkPolicy.
- **Sessões 7 e 8:** devem nascer diretamente com este molde, evitando criar outra variante estrutural.
