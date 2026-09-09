# Lab 02 — Layers, Cache e Multi-stage

**Duração prevista:** 30 minutos

## Objetivo

Compreender a invalidação da cache e construir manualmente uma imagem multi-stage com separação entre build e runtime.

## Ponto de partida

Executar a partir de:

```text
formacao-kubernetes/sessao-03
```

Confirme:

```bash
test -f app/composer.json || ./comum/prepare-source.sh
test -f formando/docker/Dockerfile && echo 'OK: pronto'
```

## 1. Analisar o Dockerfile multi-stage

```bash
sed -n '1,260p' formando/docker/Dockerfile
```

Identifique:

```text
Stage build
   ↓
instala dependências e Composer
   ↓
produz aplicação preparada
   ↓
Stage runtime
   ↓
recebe apenas o necessário para executar
```

Localize também:

- `composer.json` e `composer.lock`;
- `COPY app/`;
- `ARG APP_VERSION`;
- labels;
- `HEALTHCHECK`;
- `CMD`.

## 2. Construir manualmente a versão 1.0.0

Não utilize `build.sh` ainda.

```bash
time docker build \
  -f formando/docker/Dockerfile \
  --build-arg APP_VERSION=1.0.0 \
  --build-arg SOURCE_REF=v3.1.0 \
  -t symfony-demo:1.0.0 \
  .
```

Durante o build, observe quais passos executam efetivamente e quais ficam em cache.

## 3. Observar as layers

```bash
docker history symfony-demo:1.0.0
```

Perguntas:

- Onde são instaladas dependências?
- Onde entra o código da aplicação?
- Que elementos existem no build stage mas não precisam de permanecer no runtime?

## 4. Novo build sem alterar dependências

Construa a versão `1.1.0` alterando apenas metadata de versão:

```bash
time docker build \
  -f formando/docker/Dockerfile \
  --build-arg APP_VERSION=1.1.0 \
  --build-arg SOURCE_REF=v3.1.0 \
  -t symfony-demo:1.1.0 \
  .
```

Observe as linhas `CACHED`.

### Questão

Porque é que a alteração de `APP_VERSION` não deve obrigar a reinstalar todas as dependências?

## 5. Experimentar a invalidação da cache

Altere apenas o timestamp de um ficheiro de código:

```bash
touch app/src/Controller/LabController.php
```

Repita o build:

```bash
time docker build \
  -f formando/docker/Dockerfile \
  --build-arg APP_VERSION=1.1.0 \
  --build-arg SOURCE_REF=v3.1.0 \
  -t symfony-demo:1.1.0 \
  .
```

Compare as layers reutilizadas com as layers reconstruídas.

> Não altere `composer.lock` durante a aula principal. Discuta o que aconteceria se esse ficheiro mudasse.

## 6. Validar a imagem final

```bash
docker run --rm -d --name s3-ms -p 18081:80 symfony-demo:1.1.0
sleep 5
curl -fsS http://localhost:18081/info
docker stop s3-ms
```

## 7. Da execução manual à automação

Já executou manualmente um build com:

- Dockerfile específico;
- `APP_VERSION`;
- `SOURCE_REF`;
- tag local;
- contexto `.`.

Agora abra o script:

```bash
sed -n '1,220p' formando/scripts/build.sh
```

Identifique onde esses elementos aparecem.

Só depois execute:

```bash
./formando/scripts/build.sh 1.1.0
```

### Ideia-chave

```text
Primeiro construir e compreender
            ↓
Depois automatizar
```

Os ficheiros `composer.json` e `composer.lock` entram antes do restante código para permitir reutilizar a layer de dependências quando apenas o código muda.
