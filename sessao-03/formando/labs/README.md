# Sessão 3 — Estrutura canónica do laboratório

O laboratório principal é [`laboratorio_integrado_sessao_3.md`](laboratorio_integrado_sessao_3.md).

A Sessão 3 foi mantida como uma história técnica contínua porque acompanha o mesmo artefacto desde o código até ao deployment/rollback. A sua leitura deve, contudo, seguir o **mesmo padrão pedagógico da Sessão 4**:

```text
OBJETIVO / O QUE ESTAMOS A FAZER
        ↓
PORQUE É NECESSÁRIO
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

## Mapa de checkpoints

| Checkpoint | Secção do laboratório | Evidência principal |
|---|---|---|
| CP1 | Preparar VM / Docker | Engine, Compose e Buildx operacionais |
| CP2 | Instalar Trivy | versão do scanner disponível |
| CP3 | Obter/preparar Symfony | source e endpoints pedagógicos presentes |
| CP4 | Primeira imagem | build concluído, assets presentes, HTTP funcional |
| CP5 | Cache e multi-stage | cache observável e runtime com assets compilados |
| CP6 | Hardening e secrets | segredo não persistido na imagem final |
| CP7 | HEALTHCHECK e controlos | healthcheck + recursos + restart/logging interpretados |
| CP8 | Scan | findings interpretados sem depender de contagem fixa |
| CP9 | Tag, digest e registry | artefacto identificado e promoção compreendida |
| CP10 | Deployment 1.0.0 | app + PostgreSQL operacionais |
| CP11 | Validação | `/health`, `/ready`, `/info`, health Docker e assets |
| CP12 | Persistência/backup | marcador persistente + `backup.sql` não vazio |
| CP13 | Update 1.1.0 | versão e imagem corretas + dados preservados |
| CP14 | Falha 1.2.0-rc1 | `/health=200`, `/healthz=404`, container unhealthy |
| CP15 | Rollback 1.1.0 | versão saudável recuperada + dados preservados |

## Regra para comandos

Não copiar apenas o comando. Sempre que surgir sintaxe nova, responder:

```text
Que programa estou a usar?
Que objeto estou a alterar/consultar?
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
