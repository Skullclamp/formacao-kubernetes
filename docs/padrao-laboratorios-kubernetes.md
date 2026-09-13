# Padrão Canónico dos Laboratórios Kubernetes

Este documento define o molde pedagógico comum para os laboratórios Kubernetes das Sessões 4 a 8. O objetivo é evitar que cada sessão evolua para uma estrutura diferente e garantir que a prática é orientada por evidência, diagnóstico e validação.

## 1. Estrutura canónica de cada checkpoint

Sempre que o tema o permita, cada checkpoint deve seguir esta sequência:

```text
OBJETIVO / O QUE ESTAMOS A FAZER
        ↓
PORQUE É NECESSÁRIO
        ↓
ONDE EXECUTAR, quando o nó/contexto for relevante
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

O teste negativo não deve ser artificial. Deve existir quando permite provar uma fronteira real, por exemplo:

- Pod admitido pela API mas não agendável;
- PVC `Pending` antes do primeiro consumidor;
- RBAC com uma ação permitida e outra negada;
- NetworkPolicy com um fluxo permitido e outro bloqueado;
- Service sem EndpointSlice por selector incorreto;
- operação destrutiva apenas depois de um health gate válido.

## 2. Regra de progressão

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

Um `kubectl apply` bem-sucedido prova apenas que a API aceitou a configuração. A conclusão pedagógica exige evidência do comportamento efetivo do cluster.

## 3. Checkpoint e gate

Cada `CPx` é um ponto de controlo. O formando não deve avançar enquanto não conseguir responder a três perguntas:

1. Qual era o resultado esperado?
2. Que evidência demonstra o resultado real?
3. Se o resultado divergir, em que camada está a falha?

A classificação inicial deve privilegiar evidência:

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

## 4. Health gate antes de operações de risco

Antes de upgrade, eliminação de storage, restore, alterações de rede potencialmente disruptivas ou outros passos destrutivos, deve existir um health gate explícito.

Um health gate deve validar apenas o que é necessário para distinguir um problema preexistente de uma falha introduzida pelo exercício.

## 5. Evidências e fecho pedagógico

Cada sessão Kubernetes deve terminar com:

- checklist de autoavaliação em primeira pessoa: `Consigo...`, `Distingo...`, `Sei explicar...`;
- uma **Regra de evidência da Sessão X**;
- uma `folha_evidencias.md` quando a sessão tiver laboratório integrado extenso;
- limpeza ou reposição do estado que tenha sido alterado pelo laboratório.

A evidência deve registar resultados e interpretação, e não apenas capturas de comandos.

## 6. Bootstrap canónico do repositório

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

## 7. Continuidade da topologia

Nenhum Node deve surgir num laboratório sem explicação documental.

Quando um Node adicional for preparado pelo formador fora do tempo de aula, os materiais devem indicar explicitamente:

- quando foi introduzido;
- quem o preparou;
- que não faz parte do tempo pedagógico da sessão;
- qual a baseline esperada;
- que o `join` segue o procedimento já demonstrado anteriormente;
- que o preflight da sessão valida o Node antes de depender dele.

Na edição atual, a Sessão 4 termina com `k8s-cp-01 + k8s-wk-01`. Antes da Sessão 5, o formador adiciona `k8s-wk-03` fora dos 240 minutos, reutilizando o procedimento de `kubeadm join` já praticado na Sessão 4. O nome `k8s-wk-03` corresponde ao inventário real do laboratório e não representa um checkpoint omitido nem implica a existência pedagógica de um `k8s-wk-02`.

## 8. Convenção de Namespaces

Para novos laboratórios, adotar preferencialmente:

```text
s<sessão>-<slug>
```

Exemplo:

```text
s6-governance
```

O Namespace `sessao5` é mantido na Sessão 5 porque o laboratório foi validado de ponta a ponta com esse nome e a mudança afetaria DNS/FQDNs, comandos e evidências já ensaiadas sem acrescentar valor pedagógico. Esta é uma exceção documentada, não um segundo padrão para novos materiais.

## 9. Regra para Sessões 7 e 8

Os novos laboratórios devem nascer diretamente com este molde, evitando criar uma quarta variante estrutural. Sempre que um checkpoint não precisar de teste negativo, isso deve ser uma decisão consciente e não uma omissão automática.
