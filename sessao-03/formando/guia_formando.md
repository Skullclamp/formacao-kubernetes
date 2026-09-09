# Guia do Formando — Sessão 3

## Docker II — Build, Imagens, Segurança, Registry e Deployment Single-host

## 1. Objetivo

A Sessão 2 concentrou-se em **operar** containers. Nesta sessão o foco passa para **construir e preparar** o artefacto que será promovido entre ambientes.

```text
Código → Dockerfile → imagem → scan → registry → deploy → update → rollback
```

## 2. Pré-requisitos

- Docker Engine funcional;
- Docker Compose;
- Git;
- `curl`;
- Trivy para o Lab 05;
- acesso à Internet para obter o Symfony Demo e imagens públicas.

Preparar a aplicação:

```bash
./comum/prepare-source.sh
```

## 3. Cenário

A aplicação é a Symfony Demo `v3.1.0`, executada com PHP 8.4 + Apache e PostgreSQL 16.

Os endpoints adicionais são:

```text
/info
/health
/ready
```

`/health` responde à pergunta “o processo da aplicação está operacional?”. `/ready` acrescenta a dependência da base de dados.

## 4. Percurso dos laboratórios

| Lab | Tema | Resultado esperado |
|---:|---|---|
| 01 | Dockerfile e build | imagem funcional |
| 02 | Cache e multi-stage | imagem otimizada e build mais reutilizável |
| 03 | Hardening e secrets | riscos identificados e alternativas compreendidas |
| 04 | Healthcheck e operação | saúde e controlos operacionais validados |
| 05 | Scan, tags e digest | vulnerabilidades interpretadas e identidade compreendida |
| 06 | Registry e promoção | pull/push e build once/promote compreendidos |
| 07 | Deploy/update/rollback | ciclo operacional completo validado |

## 5. Regras de trabalho

1. Não colocar tokens ou passwords reais nos ficheiros versionados.
2. Não usar `latest` nos exercícios em que se pretende rastreabilidade.
3. Validar sempre o estado depois de uma alteração.
4. Não confundir persistência com backup.
5. Não confundir Docker `HEALTHCHECK` com probes Kubernetes.
6. Um deployment Compose num único host não é Alta Disponibilidade.

## 6. Versões de referência

```text
1.0.0      → versão inicial
1.1.0      → atualização válida
1.2.0-rc1  → candidata com falha de healthcheck
```

Imagens públicas:

```text
ghcr.io/skullclamp/symfony-demo
```

## 7. Evidência final

No final deverá conseguir mostrar:

- imagem construída;
- cache observada;
- scan executado;
- tag e digest explicados;
- deployment `1.0.0`;
- update `1.1.0`;
- falha `1.2.0-rc1` detetada;
- rollback `1.1.0`;
- dados preservados.
