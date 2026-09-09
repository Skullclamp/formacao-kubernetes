# Guia do Formando — Sessão 3

## Docker II — Build, Imagens, Segurança, Registry e Deployment Single-host

## 1. Objetivo

A Sessão 2 concentrou-se em **operar** containers. Nesta sessão o foco passa para **construir, preparar, analisar, publicar e operar** o artefacto que será promovido entre ambientes.

```text
Código → Dockerfile → imagem → scan → registry → deploy → update → rollback
```

## 2. Formato da sessão

A Sessão 3 utiliza agora **um único laboratório integrado**, em vez de sete laboratórios separados.

[Laboratório Integrado da Sessão 3](labs/laboratorio_integrado_sessao_3.md)

O percurso começa numa VM Ubuntu Server limpa e termina num rollback validado:

```text
Ubuntu Server limpo
      ↓
Docker
      ↓
Trivy
      ↓
Git clone
      ↓
Source Symfony
      ↓
Build
      ↓
Cache / Multi-stage
      ↓
Hardening / Secrets
      ↓
Health / Recursos / Logging
      ↓
Scan
      ↓
Tag / Digest / Registry
      ↓
Compose produção
      ↓
Deploy 1.0.0
      ↓
Dados / Backup
      ↓
Update 1.1.0
      ↓
Falha 1.2.0-rc1
      ↓
Diagnóstico
      ↓
Rollback 1.1.0
```

## 3. Regra de aprendizagem

O laboratório foi escrito para não funcionar como uma simples lista de comandos.

Em cada etapa encontrará:

```text
CONCEITO
   ↓
PORQUE É NECESSÁRIO
   ↓
COMANDO
   ↓
FLAGS / ARGUMENTOS
   ↓
O QUE OBSERVAR
   ↓
BOA PRÁTICA
```

A progressão prática é:

```text
FAZER manualmente
      ↓
OBSERVAR
      ↓
EXPLICAR
      ↓
AUTOMATIZAR
```

Os scripts de `formando/scripts/` permanecem disponíveis, mas só devem ser utilizados depois de o formando compreender os passos que automatizam.

## 4. Cenário técnico

A aplicação é a Symfony Demo `v3.1.0`, executada com PHP 8.4 + Apache e PostgreSQL 16.

Endpoints pedagógicos:

```text
/info
/health
/ready
```

- `/info` — identifica versão e ambiente;
- `/health` — valida saúde básica da aplicação;
- `/ready` — valida prontidão incluindo a dependência da base de dados.

## 5. Conceitos que deverá dominar

No final deverá conseguir explicar:

1. Docker CLI, Docker Engine, `containerd` e `runc`;
2. imagem versus container;
3. build context e `.dockerignore`;
4. layers e build cache;
5. multi-stage build;
6. `ARG` e `ENV`;
7. hardening e gestão de secrets;
8. Docker `HEALTHCHECK`;
9. recursos, restart policy e logging;
10. scan de vulnerabilidades com Trivy;
11. tag versus digest;
12. o que é um container registry;
13. `pull` versus `push`;
14. GHCR;
15. build once / promote the same artifact;
16. Compose de produção single-host;
17. persistência versus backup;
18. update, diagnóstico e rollback.

## 6. Regras de trabalho

1. Não colocar tokens ou passwords reais em ficheiros versionados.
2. Não usar `latest` quando é necessária rastreabilidade.
3. Validar sempre o estado depois de uma alteração.
4. Diagnosticar antes de corrigir.
5. Não confundir persistência com backup.
6. Não confundir Docker `HEALTHCHECK` com probes Kubernetes.
7. Docker Compose num único host não é Alta Disponibilidade.
8. Antes de executar um script, saber explicar o processo que ele automatiza.

## 7. Versões de referência

```text
1.0.0      → versão inicial
1.1.0      → atualização válida
1.2.0-rc1  → candidata com falha controlada de HEALTHCHECK
```

Registry público da formação:

```text
ghcr.io/skullclamp/symfony-demo
```

## 8. Evidência final esperada

No final deverá conseguir mostrar:

- Docker Engine, Compose e Buildx funcionais;
- Trivy funcional;
- repositório clonado;
- source Symfony preparado;
- imagem construída manualmente;
- cache observada;
- multi-stage compreendido;
- risco de secret demonstrado;
- HEALTHCHECK interpretado;
- scan executado;
- tag e digest distinguidos;
- conceito de registry explicado;
- pull efetuado e push pessoal quando aplicável;
- Compose de produção validado;
- deployment `1.0.0`;
- dados persistentes e backup lógico;
- update `1.1.0`;
- falha `1.2.0-rc1` diagnosticada;
- rollback `1.1.0`;
- dados preservados depois do rollback.
