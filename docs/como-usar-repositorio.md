# Como utilizar este repositório

Este repositório contém os materiais destinados aos **formandos**.

## Obter os materiais

Na primeira utilização:

```bash
git clone https://github.com/Skullclamp/formacao-kubernetes.git
cd formacao-kubernetes
```

Nas sessões seguintes:

```bash
git pull
```

## Organização

Os materiais são publicados progressivamente por sessão:

```text
sessao-02/
sessao-03/
...
```

Dentro de cada sessão encontrará, conforme necessário:

```text
README.md       → ponto de entrada
labs/           → guiões práticos
compose/        → ficheiros Docker Compose
manifests/      → recursos Kubernetes
checklist.md    → consolidação
```

## Regra de trabalho

Não altere os ficheiros de referência diretamente se pretender conservar uma cópia limpa. Quando um exercício pedir alterações, pode criar uma cópia de trabalho.

Exemplo:

```bash
cp sessao-02/compose/.env.example sessao-02/compose/.env
```

O ficheiro `.env` local não deverá ser utilizado para guardar credenciais reais.

## Durante troubleshooting

Evite a estratégia "alterar até funcionar". Utilize:

```text
Sintoma → Evidência → Hipótese → Causa → Correção → Validação
```

Registe os comandos e a evidência que suportam a sua conclusão.
