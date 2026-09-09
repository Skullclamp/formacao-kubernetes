# Lab 03 — Hardening e Secrets

**Duração prevista:** 25 minutos

## Objetivo

Identificar, através de experiências simples, informação que não deve ficar persistida na imagem e comparar formas de fornecer secrets.

## Ponto de partida

Executar a partir de:

```text
formacao-kubernetes/sessao-03
```

Confirme:

```bash
test -f formando/exemplos/secrets/Dockerfile.bad && echo 'OK: pronto'
```

## 1. Má prática — observar o problema

Analise primeiro:

```bash
cat formando/exemplos/secrets/Dockerfile.bad
```

Utilize apenas um valor fictício de laboratório:

```bash
docker build \
  -f formando/exemplos/secrets/Dockerfile.bad \
  --build-arg DEMO_SECRET=segredo-falso-lab \
  -t secret-demo:bad \
  formando/exemplos/secrets
```

Investigue a imagem:

```bash
docker history --no-trunc secret-demo:bad
docker image inspect secret-demo:bad
```

Perguntas:

- O valor ficou visível no histórico ou metadata?
- Deverá um secret ser tratado como `ARG` ou `ENV` permanente?
- Que risco existiria com uma credencial real?

> Nunca utilize um secret real neste laboratório.

## 2. BuildKit secret — observar a alternativa

Analise:

```bash
cat formando/exemplos/secrets/Dockerfile.secret
```

Criar um ficheiro temporário com valor fictício:

```bash
printf 'segredo-falso-lab\n' > /tmp/demo_secret.txt
```

Construir:

```bash
DOCKER_BUILDKIT=1 docker build \
  -f formando/exemplos/secrets/Dockerfile.secret \
  --secret id=demo_secret,src=/tmp/demo_secret.txt \
  -t secret-demo:buildkit \
  formando/exemplos/secrets
```

O mount `type=secret` disponibiliza o ficheiro apenas durante a instrução `RUN` que o utiliza.

Compare:

```bash
docker history --no-trunc secret-demo:buildkit
docker image inspect secret-demo:buildkit
```

Remover o ficheiro temporário:

```bash
rm -f /tmp/demo_secret.txt
```

## 3. Compose secret

Analise:

```bash
cat formando/exemplos/secrets/compose.secret-demo.yaml
```

Crie apenas a cópia de exemplo local indicada pelo laboratório, sem credenciais reais, e execute:

```bash
docker compose \
  -f formando/exemplos/secrets/compose.secret-demo.yaml \
  up --abort-on-container-exit
```

No container, um Compose secret é disponibilizado como ficheiro em:

```text
/run/secrets/<nome>
```

Isto é diferente de transformar automaticamente o secret numa variável de ambiente.

## 4. `.env`

O ficheiro `.env.prod` é útil para parametrizar Compose, mas:

```text
.env.prod
   ≠
secret manager
```

Deve ser excluído do Git e protegido no host.

## 5. Hardening da imagem final

Reveja:

```bash
sed -n '1,260p' formando/docker/Dockerfile
```

Identifique:

- origem e adequação da imagem base;
- dependências de build removidas do runtime;
- diretórios que precisam de escrita;
- privilégios necessários ao Apache;
- ausência de secrets embutidos;
- ferramentas que não precisam de existir no runtime.

### Nota sobre non-root

A imagem Apache oficial tem requisitos próprios de arranque e binding de porta. Não altere `USER` mecanicamente sem validar o comportamento real do entrypoint e das permissões.

### Síntese

```text
Secret em ARG/ENV persistente
           ↓
        risco

BuildKit secret mount
           ↓
disponível apenas durante RUN

Compose secret
           ↓
ficheiro em /run/secrets/...
```
