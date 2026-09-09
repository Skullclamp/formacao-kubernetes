# Lab 01 — Dockerfile e Build

**Duração prevista:** 30 minutos

## Objetivo

Construir manualmente a primeira imagem da Symfony Demo e relacionar cada instrução do Dockerfile com o conteúdo e comportamento da imagem.

## Ponto de partida

Todos os comandos deste laboratório são executados a partir de:

```text
formacao-kubernetes/sessao-03
```

Se ainda não tiver o repositório:

```bash
git clone https://github.com/Skullclamp/formacao-kubernetes.git
cd formacao-kubernetes/sessao-03
```

Se já o tiver:

```bash
cd formacao-kubernetes
git pull
cd sessao-03
```

Confirme:

```bash
test -f formando/docker/Dockerfile.inicial && echo 'OK: diretoria correta'
```

## 1. Preparar o código

```bash
./comum/prepare-source.sh
```

Confirmar:

```bash
test -f app/composer.json && echo 'OK: source preparado'
```

## 2. Analisar o Dockerfile inicial

```bash
sed -n '1,220p' formando/docker/Dockerfile.inicial
```

Antes de construir, complete mentalmente ou em notas:

```text
FROM        → __________________________
ENV         → __________________________
RUN         → __________________________
COPY        → __________________________
WORKDIR     → __________________________
EXPOSE      → __________________________
HEALTHCHECK → __________________________
CMD         → __________________________
```

Identifique também que ferramentas são necessárias para **construir** a aplicação e quais são necessárias apenas para **executá-la**.

## 3. Construir manualmente

Não utilize `build.sh` neste laboratório.

```bash
docker build \
  -f formando/docker/Dockerfile.inicial \
  -t symfony-demo:naive \
  .
```

Explique o significado do último argumento `.`.

## 4. Executar

```bash
docker run --rm -d --name s3-naive -p 18080:80 symfony-demo:naive
```

Aguardar o healthcheck:

```bash
docker inspect s3-naive \
  --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}'
```

Validar:

```bash
curl -fsS http://localhost:18080/health
curl -fsS http://localhost:18080/info
curl -fsS http://localhost:18080/en >/dev/null
```

## 5. Observar a imagem

```bash
docker image ls symfony-demo:naive
docker history symfony-demo:naive
```

Relacione as layers observadas com as instruções do Dockerfile.

## 6. Pequena alteração e novo build

Acrescente temporariamente ao fim do Dockerfile inicial:

```dockerfile
LABEL training.session="3"
```

Construa uma segunda imagem:

```bash
docker build \
  -f formando/docker/Dockerfile.inicial \
  -t symfony-demo:naive-v2 \
  .
```

Consultar a label:

```bash
docker image inspect symfony-demo:naive-v2 \
  --format '{{json .Config.Labels}}'
```

Depois reponha o Dockerfile inicial com Git:

```bash
git restore formando/docker/Dockerfile.inicial
```

## 7. Limpeza

```bash
docker stop s3-naive
```

### Questões

1. O que representa o contexto de build?
2. Que elementos usados para construir a aplicação não precisam necessariamente de permanecer na imagem final de runtime?
3. Qual é a relação entre Dockerfile, imagem e container?
