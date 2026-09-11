# Laboratório 1 — Fundamentos de Containers

## Objetivo

Executar um container, consultar o seu estado e logs, parar e remover o recurso e introduzir o conceito de persistência através de volumes.

## 1. Executar um container

```bash
docker run --name web-demo -d nginx
```

O comando cria um container denominado `web-demo` a partir da imagem `nginx` e executa-o em segundo plano (`-d`).

## 2. Confirmar a execução

```bash
docker ps
```

Confirme que o container aparece na lista e que o estado indica execução ativa.

## 3. Consultar logs

```bash
docker logs web-demo
```

Os logs ajudam a observar o comportamento da aplicação executada dentro do container.

## 4. Parar o container

```bash
docker stop web-demo
```

Confirme depois:

```bash
docker ps -a
```

## 5. Remover o container

```bash
docker rm web-demo
```

## 6. Criar um volume

```bash
docker volume create dados-demo
```

Consultar:

```bash
docker volume ls
```

## 7. Questões de reflexão

1. Qual é a diferença entre a imagem `nginx` e o container `web-demo`?
2. O que acontece ao processo da aplicação quando o container é parado?
3. Porque é útil separar dados do ciclo de vida do container?

## Resultado esperado

- container criado e executado;
- logs consultados;
- container parado e removido;
- volume criado e identificado.
