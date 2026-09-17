# Padrão Canónico dos Laboratórios — Docker e Kubernetes

Este documento define o molde pedagógico comum dos laboratórios técnicos da formação. Aplica-se às **Sessões 1 a 7 atualmente publicadas no repositório** e deve ser reutilizado nas sessões seguintes quando os respetivos laboratórios forem criados.

A **Sessão 4** continua a ser a principal referência de estilo: o formando deve saber **o que está a fazer, porque o faz, que conceito está a trabalhar, como interpretar os comandos/flags e que evidência prova o resultado**.

---

## 1. Estrutura canónica de cada checkpoint

Sempre que o tema o permita, cada checkpoint (`CP`) deve seguir esta sequência:

```text
OBJETIVO / O QUE ESTAMOS A FAZER
        ↓
PORQUE É NECESSÁRIO
        ↓
CONCEITOS ABORDADOS NESTE CP
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

### 1.1. Conceitos abordados neste CP

Cada CP deve explicitar os conceitos que está a materializar. Não basta listar nomes de tecnologias: deve ficar clara a relação entre o conceito e a ação prática.

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

Quando o conceito pertence diretamente ao conteúdo programático da sessão, a explicação deve mostrar essa ligação. O objetivo é evitar laboratórios em que o formando executa a operação correta sem perceber **que problema Kubernetes/Docker está a resolver**.

### 1.2. Testes negativos e falhas controladas

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

---

## 2. Regra de explicação de comandos e flags

Sempre que surge um comando novo ou uma flag com relevância pedagógica, explicar o seu papel na **primeira utilização relevante**.

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

Não é necessário repetir a explicação completa em todas as ocorrências da mesma flag. É necessário voltar a destacá-la quando o **significado contextual mudar** ou quando a combinação de flags introduzir um novo comportamento.

### 2.1. Pipes, redirecionamentos e shell

Quando o laboratório usa sintaxe de shell que influencia o resultado, essa sintaxe também deve ser explicada, por exemplo:

```text
|              → envia stdout do comando anterior para o seguinte
>              → redireciona stdout para um ficheiro
2>/dev/null    → descarta stderr
&&             → executa o passo seguinte apenas se o anterior tiver sucesso
|| true        → neutraliza um código de saída não-zero quando isso é intencional
$(...)         → substitui a expressão pelo output de um comando
<<EOF          → here-document para fornecer várias linhas
```

A explicação deve incidir apenas na sintaxe efetivamente usada no CP.

---

## 3. Regra para YAML, Compose e Dockerfile

Os ficheiros técnicos usados pelo formando devem ser comentados quando os comentários ajudam a compreender a intenção.

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

---

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

---

## 5. Checkpoint e gate

Cada `CPx` é um ponto de controlo. O formando não deve avançar enquanto não conseguir responder a quatro perguntas:

1. Que conceito ou regra estava a ser trabalhado?
2. Qual era o resultado esperado?
3. Que evidência demonstra o resultado real?
4. Se o resultado divergir, em que camada está provavelmente a falha?

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

---

## 6. Health gate antes de operações de risco

Antes de update/rollback, upgrade, eliminação de storage, restore, alterações de rede potencialmente disruptivas ou outros passos destrutivos, deve existir um health gate explícito.

Um health gate deve validar apenas o necessário para distinguir um problema preexistente de uma falha introduzida pelo exercício.

Sempre que existirem conceitos diferentes de saúde/prontidão, distingui-los explicitamente. Exemplo do cenário Symfony:

```text
/health → saúde básica da aplicação
/ready  → prontidão incluindo a dependência de dados
```

---

## 7. Evidências e fecho pedagógico

Cada laboratório integrado deve terminar, quando aplicável, com:

- checklist de autoavaliação em primeira pessoa: `Consigo...`, `Distingo...`, `Sei explicar...`;
- uma **Regra de evidência da Sessão X**;
- uma `folha_evidencias.md` quando a sessão tiver laboratório integrado extenso;
- limpeza ou reposição do estado alterado pelo laboratório.

A evidência deve registar resultados **e interpretação**, e não apenas capturas de comandos.

Uma boa evidência responde a:

```text
O que esperava?
O que observei?
O que concluo?
```

---

## 8. Bootstrap canónico do repositório para sessões Kubernetes

As sessões Kubernetes devem usar o mesmo padrão robusto. Não assumir que a shell abriu dentro do repositório e não destruir uma diretoria não-Git com o mesmo nome.

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

### Como interpretar as opções relevantes

```text
git -C <dir>                → executa Git nessa diretoria sem fazer cd
switch main                 → garante a branch de formação
a pull --ff-only origin main → só aceita atualização fast-forward; evita merge local inesperado
--branch main               → faz clone da branch indicada
--single-branch             → limita o clone à branch necessária
```

---

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

---

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

Na Sessão 1 mantém-se `formacao` por ser um Namespace introdutório já alinhado com o manual e o plano da sessão.

---

## 11. Aplicação às sessões publicadas

- **Sessão 1:** os dois laboratórios introdutórios usam checkpoints, conceitos por CP, explicação de comandos/flags, observação, evidência e limpeza. O manifesto do Pod inclui comentários de intenção nos campos relevantes.
- **Sessão 2:** os seis labs curtos seguem checkpoints, explicação de comandos/flags, observação, testes controlados quando úteis e evidência; `compose.yaml` é comentado pedagogicamente.
- **Sessão 3:** o laboratório integrado mantém a história manual → observar → explicar → automatizar. O `README` dos labs disponibiliza o mapa CP1–CP15 para a narrativa contínua; Dockerfiles e Compose explicam os campos relevantes.
- **Sessão 4:** laboratório de referência para a estrutura de checkpoints Kubernetes.
- **Sessão 5:** laboratório integrado com conceitos explícitos, checkpoints, testes controlados, evidência e manifests externos comentados.
- **Sessão 6:** laboratório integrado de governação com checkpoints e coleção numerada de manifests para requests/limits, scheduling, RBAC, SecurityContext e NetworkPolicy.
- **Sessão 7:** laboratório integrado de troubleshooting e operação avançada, com interpretação de comandos/flags, método `Sintoma → Evidência → Hipótese → Teste → Causa raiz → Correção → Validação` e incidentes acompanhados.

As **Sessões 8, 9 e 10 não têm, nesta versão do repositório, laboratórios publicados em diretórios próprios**. Quando forem criados, devem nascer diretamente com este padrão em vez de introduzir uma nova variante estrutural.

---

## 12. Critério de revisão de um laboratório

Antes de considerar um laboratório uniformizado, confirmar:

```text
[ ] existe objetivo claro por CP
[ ] é explicado o que está a ser feito e porquê
[ ] os conceitos do CP são identificados explicitamente
[ ] host/Node/Namespace/contexto estão claros quando relevantes
[ ] comandos novos são explicados
[ ] flags relevantes são interpretadas
[ ] campos YAML/Compose/Dockerfile com impacto estão explicados
[ ] existe output/estado esperado
[ ] o formando sabe o que observar
[ ] existe teste negativo/falha controlada quando acrescenta valor
[ ] existe checkpoint/gate
[ ] existe evidência a registar
[ ] a limpeza/reposição é explícita quando necessária
[ ] o laboratório termina com síntese ou regra de evidência
```

A uniformização é pedagógica e operacional: **não significa tornar todos os laboratórios iguais em duração ou complexidade**, mas garantir que todos ensinam o formando a compreender, executar, observar, validar e explicar.
