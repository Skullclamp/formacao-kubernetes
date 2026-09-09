# Lab 07 — Deploy, Update, Falha e Rollback

**Duração prevista:** 50 minutos

## Objetivo

Executar um deployment single-host controlado, compreender o algoritmo operacional automatizado, validar saúde/prontidão, atualizar e regressar a uma versão conhecida como boa sem perder os dados.

## Ponto de partida

Executar a partir de:

```text
formacao-kubernetes/sessao-03
```

Confirme:

```bash
test -f formando/compose/compose.yaml && echo 'OK: Compose disponível'
test -x formando/scripts/deploy-prod.sh && echo 'OK: scripts disponíveis'
```

Neste laboratório os scripts são utilizados de forma deliberada. Nos labs anteriores executou manualmente build, Compose, tag, push e validações. Agora o objetivo é integrar esses conhecimentos num processo operacional repetível.

## 1. Preparar

```bash
cp formando/compose/.env.prod.example formando/compose/.env.prod
```

Se utilizar outro registry, editar apenas `IMAGE_REPO`.

## 2. Compreender antes de executar

Abra o script principal:

```bash
sed -n '1,320p' formando/scripts/deploy-prod.sh
```

Não é necessário dominar toda a sintaxe Bash. Identifique o algoritmo:

```text
1. validar configuração Compose
2. verificar antecipadamente a porta publicada
3. obter/pull das imagens
4. iniciar PostgreSQL
5. aguardar DB healthy
6. verificar/inicializar schema do laboratório
7. iniciar aplicação
8. validar endpoints
9. validar Docker HEALTHCHECK
```

Abra também o validador:

```bash
sed -n '1,260p' formando/scripts/validate.sh
```

Localize as verificações de:

- `/health`;
- `/ready`;
- `/info`;
- Docker health status.

## 3. Validar Compose

```bash
./formando/scripts/compose-prod.sh config
```

Confirme que não existe `build:` para o serviço `app`: nesta fase o deployment consome uma imagem já construída e promovida.

## 4. Deployment inicial — 1.0.0

```bash
./formando/scripts/deploy-prod.sh 1.0.0
```

Enquanto executa, relacione cada mensagem apresentada com o algoritmo identificado no passo 2.

Validar novamente:

```bash
./formando/scripts/validate.sh
curl -fsS http://localhost:8080/info
```

## 5. Criar evidência persistente

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

Esta tabela serve apenas como evidência pedagógica de persistência.

## 6. Backup lógico

Antes de executar, abra:

```bash
sed -n '1,220p' formando/scripts/backup-postgres.sh
```

Identifique o `pg_dump` utilizado.

Depois execute:

```bash
./formando/scripts/backup-postgres.sh
```

Mensagem-chave:

```text
Persistência
     ≠
Backup
```

## 7. Atualizar para 1.1.0

```bash
./formando/scripts/deploy-prod.sh 1.1.0
```

Validar versão:

```bash
curl -fsS http://localhost:8080/info
```

Validar dados:

```bash
./formando/scripts/compose-prod.sh exec -T db \
  psql -U symfony -d symfony \
  -c 'SELECT * FROM lab_marker;'
```

O marcador deve continuar presente.

Explique:

```text
imagem/container da aplicação mudou
           ↓
volume PostgreSQL permaneceu
           ↓
dados permaneceram
```

## 8. Falha controlada — 1.2.0-rc1

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
- Docker HEALTHCHECK fica `unhealthy` porque a imagem aponta o teste para um caminho incorreto;
- o script de deployment devolve erro.

## 9. Diagnosticar antes do rollback

Não execute imediatamente o rollback. Primeiro prove a causa.

Consultar estado:

```bash
./formando/scripts/compose-prod.sh ps
```

Obter o container:

```bash
CID=$(./formando/scripts/compose-prod.sh ps -q app)
```

Consultar Docker health:

```bash
docker inspect "$CID" \
  --format '{{json .State.Health}}'
```

Consultar logs:

```bash
./formando/scripts/compose-prod.sh logs --tail 100 app
```

Comparar os dois caminhos:

```bash
curl -i http://localhost:8080/health
curl -i http://localhost:8080/healthz
```

Pergunta:

> Porque pode a aplicação responder em `/health` e o Docker considerar o container `unhealthy`?

## 10. Compreender o rollback

Abra antes de executar:

```bash
sed -n '1,240p' formando/scripts/rollback.sh
```

Identifique:

- alteração da versão;
- pull;
- atualização da stack;
- validação final.

## 11. Executar rollback

```bash
./formando/scripts/rollback.sh 1.1.0
```

Confirmar:

```bash
./formando/scripts/validate.sh
./formando/scripts/compose-prod.sh exec -T db \
  psql -U symfony -d symfony \
  -c 'SELECT * FROM lab_marker;'
```

A versão deverá voltar a `1.1.0`, o healthcheck deverá ficar `healthy` e o marcador deverá permanecer.

## 12. Síntese

```text
processo manual aprendido
        ↓
automação compreendida
        ↓
1.0.0
  ↓ deploy
1.1.0
  ↓ update
1.2.0-rc1
  ↓ diagnóstico: unhealthy
1.1.0
  ↓ rollback
healthy + dados preservados
```

> Kubernetes não reutiliza automaticamente a metadata de Docker HEALTHCHECK como liveness/readiness probe.

### Questão final

Que vantagens tem automatizar o deployment **depois** de compreender manualmente os passos que o compõem?
