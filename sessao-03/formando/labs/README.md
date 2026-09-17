# Sessão 3 — Estrutura canónica do laboratório

O laboratório principal é [`laboratorio_integrado_sessao_3.md`](laboratorio_integrado_sessao_3.md).

A Sessão 3 é mantida como uma história técnica contínua porque acompanha o mesmo artefacto desde o código até ao deployment e rollback. A sua leitura deve seguir o **mesmo padrão pedagógico da Sessão 4**:

```text
OBJETIVO / O QUE ESTAMOS A FAZER
        ↓
PORQUE É NECESSÁRIO
        ↓
CONCEITOS ABORDADOS NESTE CP
        ↓
COMANDO / FICHEIRO
        ↓
FLAGS / CAMPOS IMPORTANTES
        ↓
OUTPUT / ESTADO ESPERADO
        ↓
O QUE OBSERVAR
        ↓
FALHA CONTROLADA, quando aplicável
        ↓
CHECKPOINT — NÃO AVANÇAR SEM VALIDAR
        ↓
EVIDÊNCIA
```

## Mapa de checkpoints e conceitos

| CP | Secção do laboratório | Conceitos que estão a ser trabalhados | Evidência principal |
|---:|---|---|---|
| **CP1** | Preparar VM / Docker | Docker CLI, Engine, `containerd`, `runc`, Buildx, Compose, permissões do grupo `docker` | Engine, Compose e Buildx operacionais |
| **CP2** | Instalar Trivy | scanner de vulnerabilidades, base de vulnerabilidades, ferramenta vs. artefacto analisado | versão do Trivy disponível |
| **CP3** | Obter/preparar Symfony | Git, source reproduzível, versão da aplicação, endpoints pedagógicos | source e endpoints presentes |
| **CP4** | Primeira imagem | Dockerfile, build context, `.dockerignore`, layers, tag, assets de runtime, port publishing | build concluído, assets presentes e HTTP funcional |
| **CP5** | Cache e multi-stage | cache de build, invalidation, build stage, runtime stage, `COPY --from`, separação build/runtime | cache observável e runtime com assets compilados |
| **CP6** | Hardening e secrets | superfície de ataque, menor privilégio, build secret, runtime secret, risco de `ARG`/`ENV` | segredo não persistido indevidamente na imagem final |
| **CP7** | HEALTHCHECK e controlos | saúde vs. prontidão, Docker `HEALTHCHECK`, limites CPU/memória, restart policy, logging | healthcheck e controlos interpretados |
| **CP8** | Scan | vulnerabilidade conhecida, severidade, findings, quality gate por exit code | findings interpretados sem depender de contagem fixa |
| **CP9** | Tag, digest e registry | SemVer, tag mutável, digest imutável, registry, promoção do mesmo artefacto | artefacto identificado e promoção compreendida |
| **CP10** | Deployment 1.0.0 | Compose multi-container, rede, volume, dependência de DB, configuração de produção single-host | aplicação e PostgreSQL operacionais |
| **CP11** | Validação | `/health`, `/ready`, `/info`, health do Docker, validação funcional do browser | estado operacional comprovado em várias camadas |
| **CP12** | Persistência/backup | named volume, persistência ≠ backup, `pg_dump`, evidência de dados | marcador persistente e `backup.sql` não vazio |
| **CP13** | Update 1.1.0 | atualização de versão, substituição do container, preservação de dados, promoção | versão e imagem corretas com dados preservados |
| **CP14** | Falha 1.2.0-rc1 | falha controlada, healthcheck incorreto, processo ativo ≠ aplicação saudável | `/health=200`, `/healthz=404`, container `unhealthy` |
| **CP15** | Rollback 1.1.0 | diagnóstico antes de rollback, recuperação de versão conhecida, continuidade dos dados | versão saudável recuperada e dados preservados |

Este mapa não substitui a explicação detalhada existente no laboratório; torna explícito **que conceito do percurso Docker II está a ser comprovado em cada CP**.

## Regra para comandos

Não copiar apenas o comando. Sempre que surgir sintaxe nova, responder:

```text
Que programa estou a usar?
Que objeto estou a alterar ou consultar?
Que flags mudam o comportamento?
Que output prova o resultado?
```

Exemplo:

```bash
docker build \
  -f formando/docker/Dockerfile \
  --build-arg APP_VERSION=1.1.0 \
  -t symfony-demo:1.1.0 \
  .
```

```text
-f          → Dockerfile a utilizar
--build-arg → valor fornecido a ARG durante o build
-t          → nome/tag atribuídos à imagem resultante
.           → build context enviado ao builder
```

## Regra para Dockerfile e Compose

Os ficheiros da Sessão 3 estão comentados para explicar **intenção**, não apenas nomes de chaves. Ler em conjunto com o laboratório:

- `../docker/Dockerfile.inicial` — versão single-stage para comparação;
- `../docker/Dockerfile` — multi-stage, assets, metadata e HEALTHCHECK;
- `../compose/compose.yaml` — serviços, dependência, volume e health da DB;
- `../compose/compose.prod.yaml` — imagem promovida, recursos, restart e logging;
- `../exemplos/secrets/compose.secret-demo.yaml` — entrega de secret ao serviço autorizado.

## Checklist final do formando

- [ ] Consigo explicar o build context e a finalidade do `.dockerignore`.
- [ ] Distingo a imagem inicial single-stage da versão multi-stage.
- [ ] Consigo explicar como a ordem das layers influencia cache/rebuild.
- [ ] Sei explicar porque Composer/assets pertencem ao build e não devem introduzir ferramentas desnecessárias no runtime.
- [ ] Distingo `ARG` de `ENV` e não trato nenhum deles como secret manager.
- [ ] Consigo explicar o mecanismo de BuildKit secret usado no laboratório.
- [ ] Consigo interpretar o Docker `HEALTHCHECK` e distingui-lo de `/ready`.
- [ ] Sei interpretar limites de CPU/memória, restart policy e logging do Compose de produção.
- [ ] Consigo executar e interpretar o scan Trivy sem assumir uma contagem fixa de findings.
- [ ] Distingo tag de digest.
- [ ] Consigo explicar **build once, promote the same artifact**.
- [ ] Consigo provar que a versão `1.1.0` substituiu a `1.0.0`.
- [ ] Consigo explicar por que a `1.2.0-rc1` fica `unhealthy` apesar de `/health` responder.
- [ ] Só faço rollback depois de diagnosticar a causa da falha controlada.
- [ ] Consigo provar que os dados PostgreSQL sobreviveram ao update e rollback.
- [ ] Distingo persistência de backup.
- [ ] Sei explicar porque Compose single-host não é Alta Disponibilidade.

## Regra de evidência da Sessão 3

```text
imagem inicial funcional
+
assets compilados
+
multi-stage/cache explicados
+
secret não persistido indevidamente
+
healthcheck interpretado
+
scan analisado
+
artefacto identificado por versão/digest
+
deployment 1.0.0 saudável
+
update 1.1.0 comprovado
+
dados preservados
+
falha 1.2.0-rc1 diagnosticada
+
rollback 1.1.0 comprovado
```
