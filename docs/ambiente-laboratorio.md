# Ambiente de laboratório

## Contexto

Os exercícios são realizados em ambiente controlado de formação, sobre VMs Ubuntu.

Na Sessão 2 trabalhamos num **único host Docker**. O objetivo é dominar operação, networking, storage e Docker Compose antes de avançar para a administração e orquestração com Kubernetes.

## Aplicação transversal

A aplicação de referência é uma variante pedagógica da **Symfony Demo Application**.

Stack:

```text
Symfony Demo v3.1.0
Symfony 8.1
PHP 8.4 + Apache
PostgreSQL 16
```

Endpoints pedagógicos:

```text
/info    → informação da aplicação/ambiente
/health  → confirma que a aplicação responde
/ready   → confirma que a aplicação está pronta, incluindo dependências necessárias ao laboratório
```

## Sessão 2

Nesta sessão a imagem da aplicação é fornecida já construída.

Não é objetivo da Sessão 2 aprofundar:

- Dockerfile;
- `docker build`;
- layers e cache;
- multi-stage builds;
- hardening da imagem;
- publicação da imagem no registry.

Esses temas são trabalhados na Sessão 3.

## Credenciais de laboratório

Os valores presentes nos exemplos são exclusivamente de laboratório. Não representam uma estratégia adequada para gestão de segredos em produção.
