# Manifests — Sessão 6

Esta diretoria contém versões **comentadas e pedagogicamente explicadas** dos principais manifests usados no laboratório de **Recursos, Scheduling e Segurança**.

O laboratório integrado continua autocontido e apresenta os YAML nos checkpoints. Estes ficheiros existem para permitir ao formando:

- reler cada objeto sem o ruído dos comandos circundantes;
- identificar a função de cada campo;
- alterar uma variável de cada vez;
- reutilizar os manifests em exercícios de consolidação;
- comparar o YAML declarativo com a evidência observada no cluster.

A regra de leitura é a mesma do laboratório da Sessão 4:

```text
O QUE QUERO IMPOR
        ↓
QUE OBJETO / CAMPO O DECLARA
        ↓
APLICAR
        ↓
OBSERVAR O EFEITO
        ↓
PROVOCAR UM CASO NEGATIVO
        ↓
RECOLHER EVIDÊNCIA
        ↓
EXPLICAR O RESULTADO
```

## Ficheiros

| Ficheiro | Conceito principal |
|---|---|
| `00-namespace.yaml` | isolamento do laboratório num Namespace |
| `01-pod-resources.yaml` | requests e limits |
| `02-limitrange.yaml` | defaults, mínimos e máximos por container |
| `03-resourcequota.yaml` | limites agregados do Namespace |
| `04-node-selector.yaml` | placement por label simples |
| `05-node-affinity.yaml` | Node Affinity obrigatória |
| `06-pod-antiaffinity.yaml` | separação de réplicas por hostname |
| `07-toleration.yaml` | comparação sem/com toleration |
| `08-serviceaccount.yaml` | identidade dedicada de workload |
| `09-role.yaml` | permissões RBAC mínimas |
| `10-rolebinding.yaml` | associação identidade → Role |
| `11-security-context.yaml` | menor privilégio ao nível do processo |
| `12-secret-demo.yaml` | Secret fictício e `stringData` |
| `13-netpol-default-deny.yaml` | isolamento total por omissão |
| `14-netpol-allow-dns.yaml` | reabertura explícita de DNS |
| `15-netpol-allow-app.yaml` | cliente → aplicação |
| `16-netpol-allow-db.yaml` | aplicação → PostgreSQL |

## Regra importante

Os comentários explicam **intenção e função dos campos**, mas o sucesso de `kubectl apply` nunca substitui a validação operacional.

Exemplos:

```text
nodeSelector / Affinity
→ validar Node atribuído e Events

ResourceQuota
→ validar rejeição e Used/Hard

RBAC
→ validar yes/no com kubectl auth can-i

SecurityContext
→ validar UID, escrita, token e capacidades

NetworkPolicy
→ provar pelo menos um fluxo permitido e um bloqueado
```

> Os valores de Secrets são exclusivamente fictícios. Não introduzir credenciais reais nos ficheiros versionados no repositório.
