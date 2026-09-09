# Lab 07 — Deploy, Update, Falha e Rollback

**Duração prevista:** 50 minutos

**Objetivo:** executar um deployment single-host controlado, validar saúde/prontidão, atualizar e regressar a uma versão conhecida como boa sem perder os dados.

## 1. Preparar

```bash
cp formando/compose/.env.prod.example formando/compose/.env.prod
```

Se utilizar outro registry, editar apenas `IMAGE_REPO`.

## 2. Validar Compose

```bash
./formando/scripts/compose-prod.sh config
```

Confirmar que não existe `build:` para o serviço `app`.

## 3. Deployment inicial

```bash
./formando/scripts/deploy-prod.sh 1.0.0
```

O script:

1. valida a configuração Compose;
2. verifica antecipadamente a porta publicada;
3. faz pull das imagens;
4. inicia PostgreSQL;
5. aguarda o healthcheck da base de dados;
6. verifica se o schema da aplicação já existe;
7. numa base vazia, cria o schema inicial do laboratório;
8. inicia a aplicação;
9. valida `/health`, `/ready`, `/info` e Docker HEALTHCHECK.

> A criação automática do schema é uma conveniência específica do laboratório. Em produção, a evolução do schema deve ser efetuada através de migrações explícitas e versionadas.

## 4. Criar evidência persistente

```bash
./formando/scripts/compose-prod.sh exec -T db \
  psql -U symfony -d symfony <<'SQL'
CREATE TABLE IF NOT EXISTS lab_marker (
  id bigserial PRIMARY KEY,
  note text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO lab_marker(note) VALUES ('sessao-3');
SELECT * FROM lab_marker;
SQL
```

## 5. Backup lógico

```bash
./formando/scripts/backup-postgres.sh
```

Persistência e backup são mecanismos distintos.

## 6. Atualizar para 1.1.0

```bash
./formando/scripts/deploy-prod.sh 1.1.0
```

Validar:

```bash
curl -fsS http://localhost:8080/info
./formando/scripts/compose-prod.sh exec -T db \
  psql -U symfony -d symfony -c 'SELECT * FROM lab_marker;'
```

O marcador deve continuar presente.

## 7. Falha controlada — 1.2.0-rc1

```bash
set +e
./formando/scripts/deploy-prod.sh 1.2.0-rc1
RC=$?
set -e
echo "EXIT_CODE=$RC"
```

Resultado esperado:

- `/health` pode responder;
- `/ready` pode responder;
- `/info` apresenta `1.2.0-rc1`;
- o Docker HEALTHCHECK fica `unhealthy`, porque a imagem aponta o healthcheck para um caminho incorreto;
- o script de deployment devolve erro.

Diagnóstico:

```bash
./formando/scripts/compose-prod.sh ps
CID=$(./formando/scripts/compose-prod.sh ps -q app)
docker inspect "$CID" --format '{{json .State.Health}}'
./formando/scripts/compose-prod.sh logs --tail 100 app
```

## 8. Rollback

```bash
./formando/scripts/rollback.sh 1.1.0
```

Confirmar:

```bash
./formando/scripts/validate.sh
./formando/scripts/compose-prod.sh exec -T db \
  psql -U symfony -d symfony -c 'SELECT * FROM lab_marker;'
```

A versão deverá voltar a `1.1.0`, o healthcheck deverá ficar `healthy` e o marcador deverá permanecer.

## 9. Síntese

```text
1.0.0
  ↓ deploy
1.1.0
  ↓ update
1.2.0-rc1
  ↓ unhealthy
1.1.0
  ↓ rollback
healthy + dados preservados
```

> Kubernetes não reutiliza automaticamente a metadata de Docker HEALTHCHECK como liveness/readiness probe.
