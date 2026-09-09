# Lab 03 — Hardening e Secrets

**Duração prevista:** 25 minutos

## Objetivo

Identificar informação que não deve ficar persistida na imagem e comparar formas de fornecer secrets.

## 1. Má prática

Analise:

```bash
cat formando/exemplos/secrets/Dockerfile.bad
```

Perguntas:

- O secret fica no Dockerfile?
- Poderá aparecer no histórico ou metadata?
- Deverá um secret ser tratado como `ARG` ou `ENV` permanente?

## 2. BuildKit secret

Analise:

```bash
cat formando/exemplos/secrets/Dockerfile.secret
```

O mount `type=secret` disponibiliza o ficheiro apenas durante a instrução `RUN` que o utiliza.

> Não introduza um secret real neste laboratório.

## 3. Compose secret

```bash
cat formando/exemplos/secrets/compose.secret-demo.yaml
```

No container, o secret é montado como ficheiro em `/run/secrets/<nome>`.

## 4. `.env`

O ficheiro `.env.prod` é útil para parametrizar o Compose, mas não é um secret manager. Deve ser excluído do Git e protegido no host.

## 5. Hardening

Reveja a imagem final e identifique:

- dependências de build removidas do runtime;
- origem da imagem base;
- diretórios que precisam de escrita;
- privilégios necessários ao Apache;
- ausência de secrets embutidos.

### Nota

A imagem Apache oficial tem requisitos próprios de arranque e binding de porta; não altere `USER` mecanicamente sem validar o funcionamento do entrypoint/runtime.
