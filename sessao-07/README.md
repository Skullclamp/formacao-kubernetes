# Sessão 7 — Continuidade, Troubleshooting e Operação Avançada

O laboratório principal é [`lab-integrado.md`](lab-integrado.md).

A Sessão 7 segue o mesmo padrão pedagógico de checkpoints usado como referência na Sessão 4. Em cada CP o formando deve conseguir explicar:

```text
O que estou a fazer?
        ↓
Porque é necessário?
        ↓
Que conceito Kubernetes estou a trabalhar?
        ↓
O que significam os comandos e flags relevantes?
        ↓
Que estado/output espero?
        ↓
Que evidência prova o resultado?
```

## Conceitos nucleares do laboratório

```text
baseline / preflight
        ↓
Kustomize / configuração declarativa
        ↓
Helm / releases / revisões
        ↓
Prometheus Operator / CRDs / Custom Resources
        ↓
readiness / rollout
        ↓
Service / EndpointSlice
        ↓
Node NotReady / Control Plane / etcd
        ↓
rollback
        ↓
controller / reconciliação
```

Nos incidentes, o método obrigatório é:

```text
Sintoma
   ↓
Evidência
   ↓
Hipótese
   ↓
Teste
   ↓
Causa raiz
   ↓
Correção
   ↓
Validação
```

## Materiais

- [`lab-integrado.md`](lab-integrado.md) — percurso acompanhado pelo formador;
- [`folha_evidencias.md`](folha_evidencias.md) — registo do que foi observado e concluído;
- [`incidents/`](incidents/) — falhas controladas trabalhadas durante o laboratório;
- [`app/`](app/) — base e overlays Kustomize;
- [`helm/`](helm/) — chart e valores para gestão de releases;
- [`monitoring/`](monitoring/) — Prometheus Operator e recursos de monitorização;
- [`solutions/`](solutions/) — validação/soluções destinadas ao formador.

## Regra de trabalho

Um comando que termina sem erro não prova, por si só, que o serviço está saudável. Em cada checkpoint devem ser relacionados:

```text
conceito
+
comando ou manifesto
+
flag/campo relevante
+
estado observado
+
evidência
+
interpretação
```

Os incidentes são acompanhados pelo formador: a causa raiz não é revelada no início, mas o objetivo é desenvolver raciocínio operacional, não transformar a sessão numa avaliação autónoma.
