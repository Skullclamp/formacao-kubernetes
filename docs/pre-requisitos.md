# Pré-requisitos

## Ambiente do formando

Cada formando deverá dispor de uma VM Ubuntu preparada para os laboratórios.

Antes da Sessão 2, confirme:

```bash
git --version
docker version
docker info
docker compose version
curl --version
```

## Acesso ao GitHub

O repositório é privado. Confirme que consegue aceder ao repositório e cloná-lo com a sua conta GitHub autorizada.

```bash
git clone https://github.com/Skullclamp/formacao-kubernetes.git
cd formacao-kubernetes
```

## Docker

O laboratório da Sessão 2 necessita de:

- Docker Engine funcional;
- Docker Compose v2, através de `docker compose`;
- acesso do utilizador aos comandos Docker;
- conectividade para obter as imagens indicadas pelo formador ou acesso ao registry do laboratório.

## Imagens utilizadas na Sessão 2

Durante os exercícios são utilizadas imagens como:

```text
nginx:alpine
busybox:stable
postgres:16
<registry>/formacao/symfony-demo:1.0
```

O endereço concreto do registry da formação será indicado pelo formador.

## Verificação rápida

```bash
docker run --rm hello-world
```

Se este comando falhar, resolva o acesso ao Docker antes de iniciar os laboratórios.
