# Formação — Orquestração de Containers com Kubernetes

Repositório de apoio aos **formandos** da formação *Orquestração de Containers com Kubernetes*.

## Objetivo

Este repositório reúne guiões de laboratório, manuais, checklists, ficheiros de configuração, scripts e exemplos técnicos utilizados ao longo das 10 sessões da formação.

Os conteúdos são disponibilizados progressivamente e cada sessão possui um ponto de entrada próprio em `sessao-XX/README.md`.

## Navegação

- [`docs/`](docs/) — pré-requisitos, ambiente, utilização do repositório e estrutura global;
- [`app/`](app/) — aplicação transversal usada nos laboratórios;
- [`sessao-01/`](sessao-01/) — Fundamentos de Containers e Kubernetes;
- [`sessao-02/`](sessao-02/) — Docker I: operação, networking, storage e Compose;
- [`sessao-03/`](sessao-03/) — Docker II: build, imagens, segurança, registry e deployment single-host;
- [`sessao-04/`](sessao-04/) — Kubernetes Admin I: instalação e administração do cluster;
- [`sessao-05/`](sessao-05/) — Kubernetes Admin II: workloads, networking e storage;
- [`sessao-06/`](sessao-06/) — Recursos, scheduling e segurança;
- [`sessao-07/`](sessao-07/) — Alta disponibilidade, monitorização e troubleshooting;
- [`sessao-08/`](sessao-08/) — Gestão e operações avançadas;
- [`sessao-09/`](sessao-09/) — Kubernetes para Developers I;
- [`sessao-10/`](sessao-10/) — Kubernetes para Developers II.

Consulte [`docs/estrutura-repositorio.md`](docs/estrutura-repositorio.md) para as convenções de organização.

## Aplicação transversal

Ao longo da formação é utilizada a **Symfony Demo Application**, numa variante pedagógica preparada para os laboratórios.

Stack de referência:

- Symfony Demo `v3.1.0`;
- Symfony 8.1;
- PHP 8.4 + Apache;
- PostgreSQL 16.

A variante de laboratório disponibiliza os endpoints pedagógicos:

```text
/info
/health
/ready
```

## Como começar

1. Consulte [`docs/pre-requisitos.md`](docs/pre-requisitos.md).
2. Leia [`docs/como-usar-repositorio.md`](docs/como-usar-repositorio.md).
3. Confirme o contexto em [`docs/ambiente-laboratorio.md`](docs/ambiente-laboratorio.md).
4. Abra o `README.md` da sessão em que está a trabalhar.

## Método de troubleshooting

Durante os laboratórios, sempre que surgir uma falha:

```text
Sintoma
   ↓
Evidência
   ↓
Hipótese
   ↓
Causa
   ↓
Correção
   ↓
Validação
```

> Antes de alterar configuração, recolha evidências.

## Segurança

Não faça commit de tokens, passwords, `admin.conf`, ficheiros `kubeconfig`, `.env` reais, chaves privadas ou outros segredos. Consulte as regras em [`docs/estrutura-repositorio.md`](docs/estrutura-repositorio.md).
