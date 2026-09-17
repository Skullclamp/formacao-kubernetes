# Padrão Canónico dos Laboratórios — Docker e Kubernetes

Este documento define o molde pedagógico comum dos laboratórios técnicos da formação. Aplica-se às **Sessões 1 a 7 atualmente publicadas no repositório** e deve ser reutilizado nas sessões seguintes quando os respetivos materiais forem criados.

A **Sessão 4** é a principal referência de estilo: o formando deve saber **o que está a fazer, porque o faz, que conceito está a trabalhar, como interpretar os comandos/flags e que evidência prova o resultado**.

---

## 1. Estrutura canónica de cada checkpoint

Sempre que o tema o permita, cada checkpoint (`CP`) deve seguir:

```text
OBJETIVO / O QUE ESTAMOS A FAZER
        ↓
PORQUE É NECESSÁRIO
        ↓
CONCEITOS ABORDADOS NESTE CP
        ↓
ONDE EXECUTAR, quando relevante
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

O laboratório não deve apresentar comandos sem explicar **o que fazem**, **porque surgem naquele momento** e **como se prova o efeito esperado**.

### Conceitos abordados neste CP

Cada CP deve explicitar os conceitos que materializa e o problema que resolvem. Quando o conceito pertence diretamente ao conteúdo programático da sessão, essa ligação deve ser visível.

Exemplo:

```text
CP — criar um Service

Conceitos:
- selector do Service;
- labels dos Pods;
- EndpointSlice;
- descoberta de backends;
- IP virtual estável do Service.
```

### Testes negativos

Usar testes negativos apenas quando comprovam uma fronteira real, por exemplo:

- conflito de porta Docker no host;
- containers em redes sem interseção;
- dados perdidos no filesystem efémero;
- Pod admitido pela API mas não agendável;
- PVC `Pending` antes do primeiro consumidor;
- ação RBAC permitida vs. negada;
- fluxo permitido vs. bloqueado por `NetworkPolicy`;
- Service sem backends devido a selector incorreto;
- release defeituosa antes de rollback.

---

## 2. Comandos, flags e sintaxe de shell

Sempre que surge um comando novo ou uma flag pedagogicamente relevante, explicar o seu papel na **primeira utilização relevante**.

Exemplo Docker:

```bash
docker run -d --name web -p 8080:80 nginx:alpine
```

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

```text
-n            → Namespace alvo
-o wide       → acrescenta informação operacional como Node/IP
```

Não é necessário repetir a explicação integral em todas as ocorrências. Deve voltar a ser destacada quando o contexto altera o significado operacional.

Quando a shell influencia o resultado, explicar também a sintaxe efetivamente usada:

```text
|             → envia stdout para o comando seguinte
>             → redireciona stdout
2>/dev/null   → descarta stderr
&&            → continua apenas se o passo anterior tiver sucesso
|| true       → neutraliza intencionalmente um código não-zero
$(...)        → substitui pela saída de um comando
<<EOF         → here-document para fornecer várias linhas
```

---

## 3. YAML, Compose e Dockerfile

Os ficheiros técnicos devem ser comentados quando o comentário ajuda a compreender **a intenção**.

Bom exemplo:

```yaml
# Named volume: separa os dados do ciclo de vida do container PostgreSQL.
volumes:
  - db-data:/var/lib/postgresql/data
```

Evitar comentários que apenas repetem o nome da chave.

Em YAML Kubernetes, comentar sobretudo campos com impacto em comportamento: selectors/labels, `serviceName`, probes, storage, requests/limits, affinity, tolerations, RBAC, `SecurityContext`, `NetworkPolicy` e Gateway API.

Em Docker/Compose, comentar sobretudo stages, `COPY --from`, cache, `ARG`/`ENV`, `HEALTHCHECK`, `ports`, `depends_on`, networks, mounts/volumes, recursos, logging e secrets.

---

## 4. Progressão pedagógica

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

Um comando sem erro prova apenas que a ferramenta aceitou a operação.

```text
docker compose up -d bem-sucedido
≠ aplicação necessariamente pronta

kubectl apply bem-sucedido
≠ comportamento necessariamente correto
```

---

## 5. Checkpoint e gate

Antes de avançar, o formando deve conseguir responder:

1. Que conceito ou regra estou a trabalhar?
2. Qual era o resultado esperado?
3. Que evidência demonstra o resultado real?
4. Se o resultado divergir, em que camada está a falha?

Em Docker, pensar inicialmente em:

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

Em Kubernetes:

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

---

## 6. Health gate antes de operações de risco

Antes de update/rollback, upgrade, eliminação de storage, restore ou alterações potencialmente disruptivas, estabelecer uma baseline/health gate explícita.

No cenário Symfony:

```text
/health → saúde básica da aplicação
/ready  → prontidão incluindo a dependência de dados
```

A baseline deve permitir distinguir uma falha preexistente de uma falha introduzida pelo exercício.

---

## 7. Evidência e fecho

Quando aplicável, cada laboratório integrado deve terminar com:

- checklist `Consigo... / Distingo... / Sei explicar...`;
- **Regra de evidência da Sessão X**;
- `folha_evidencias.md` nos laboratórios extensos;
- limpeza ou reposição do estado alterado.

A evidência deve registar resultado **e interpretação**:

```text
O que esperava?
O que observei?
O que concluo?
```

---

## 8. Bootstrap canónico do repositório para sessões Kubernetes

Não assumir que a shell abriu dentro do repositório e não destruir uma diretoria não-Git com o mesmo nome.

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

```text
git -C <dir>               → executa Git nessa diretoria sem fazer cd
switch main                → garante a branch da formação
pull --ff-only origin main → atualiza apenas por fast-forward
--branch main              → clona a branch indicada
--single-branch            → limita o clone à branch necessária
```

Depois, cada sessão entra na respetiva diretoria de trabalho.

---

## 9. Continuidade da topologia

Nenhum Node deve surgir num laboratório sem explicação documental. Quando um Node adicional é preparado pelo formador fora do tempo de aula, indicar quando foi introduzido, quem o preparou, baseline esperada e procedimento reutilizado.

Na edição atual, a Sessão 4 termina com `k8s-cp-01 + k8s-wk-01`. Antes da Sessão 5, o formador adiciona `k8s-wk-03` fora dos 240 minutos, reutilizando `kubeadm join` já praticado. O nome corresponde ao inventário real e não implica um `k8s-wk-02` pedagógico.

---

## 10. Convenção de Namespaces

Para novos laboratórios Kubernetes, preferir:

```text
s<sessão>-<slug>
```

Exemplo: `s6-governance`.

Exceções existentes e justificadas:

- Sessão 1: `formacao`, por ser introdutório e estar alinhado com o manual/plano;
- Sessão 5: `sessao5`, já validado de ponta a ponta e ligado a DNS/FQDNs existentes.

---

## 11. Aplicação às sessões publicadas

- **Sessão 1:** checkpoints, conceitos por CP, explicação de comandos/flags, evidência e limpeza; manifesto do Pod comentado.
- **Sessão 2:** seis labs curtos com checkpoints, flags, observação, testes controlados e evidência.
- **Sessão 3:** narrativa contínua com mapa CP1–CP15 no `README`, conceitos por checkpoint, Dockerfiles/Compose comentados e evidência de deployment/update/falha/rollback.
- **Sessão 4:** laboratório de referência da estrutura canónica.
- **Sessão 5:** laboratório integrado com conceitos, checkpoints, testes controlados, evidência e manifests comentados.
- **Sessão 6:** governação com checkpoints e manifests de requests/limits, scheduling, RBAC, SecurityContext e NetworkPolicy.
- **Sessão 7:** troubleshooting/operação avançada com interpretação de comandos/flags e método `Sintoma → Evidência → Hipótese → Teste → Causa raiz → Correção → Validação`.

As **Sessões 8, 9 e 10 ainda não têm laboratórios publicados em diretórios próprios** nesta versão do repositório. Quando forem criados, devem nascer diretamente com este padrão.

---

## 12. Checklist de revisão

Antes de considerar um laboratório uniformizado:

```text
[ ] objetivo claro por CP
[ ] explicação do que está a ser feito e porquê
[ ] conceitos do CP identificados
[ ] host/Node/Namespace/contexto claros quando relevantes
[ ] comandos novos explicados
[ ] flags relevantes interpretadas
[ ] campos técnicos com impacto explicados
[ ] output/estado esperado
[ ] observação orientada
[ ] teste negativo quando acrescenta valor
[ ] checkpoint/gate explícito
[ ] evidência a registar
[ ] limpeza/reposição quando necessária
[ ] síntese ou regra de evidência no final
```

Uniformizar não significa tornar todos os laboratórios iguais em duração ou complexidade. Significa garantir que todos ensinam o formando a **compreender, executar, observar, validar e explicar**.
