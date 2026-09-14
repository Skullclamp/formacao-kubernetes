# Labs — Sessão 6

O laboratório principal é [`laboratorio_integrado_sessao_6.md`](laboratorio_integrado_sessao_6.md) e segue o padrão pedagógico definido em [`../../docs/padrao-laboratorios-kubernetes.md`](../../docs/padrao-laboratorios-kubernetes.md).

A lógica de cada checkpoint é:

```text
REGRA / OBJETIVO
    ↓
PORQUE EXISTE
    ↓
APLICAR
    ↓
OBSERVAR
    ↓
PROVOCAR UMA EXCEÇÃO / TESTE NEGATIVO
    ↓
RECOLHER EVIDÊNCIA
    ↓
EXPLICAR
```

As versões comentadas dos principais YAML encontram-se em [`../manifests/`](../manifests/). Devem ser usadas para estudar **a intenção de cada campo**, não apenas para copiar configuração.

## Flags recorrentes

| Sintaxe | Significado |
|---|---|
| `-n s6-governance` | limita a operação ao Namespace da sessão |
| `-o wide` | acrescenta informação operacional como Node/IP |
| `-o yaml` | apresenta a representação YAML do objeto |
| `-o jsonpath=...` | extrai campos específicos para validação/evidência |
| `-l chave=valor` | seleciona objetos por labels |
| `--show-labels` | mostra labels na listagem |
| `--sort-by=.lastTimestamp` | ordena Events pelo timestamp indicado |
| `--as=<identidade>` | testa autorização através de impersonation, quando permitido |
| `kubectl auth can-i` | pergunta objetivamente à camada de autorização se uma ação é permitida |
| `--overwrite` em `kubectl label` | permite alterar uma label já existente |

## Regra de validação

```text
requests/limits → describe + Events + estado
quota            → Used/Hard + rejeição de excesso
scheduling       → Node atribuído ou FailedScheduling
RBAC             → pelo menos um yes e um no
SecurityContext  → UID/escrita/token observados dentro do Pod
NetworkPolicy    → um fluxo permitido funciona e um proibido falha
```

O sucesso de `kubectl apply` nunca é, sozinho, a prova final de um controlo administrativo.
