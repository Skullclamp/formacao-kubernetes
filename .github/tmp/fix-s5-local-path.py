from pathlib import Path

p = Path("sessao-05-06/labs/laboratorio_integrado_sessao_5.md")
text = p.read_text()

tree_old = "├── 00-namespace.yaml\n├── 01-governacao/"
tree_new = "├── 00-namespace.yaml\n├── 00-storage/\n│   └── local-path-storage.yaml\n├── 01-governacao/"
if tree_old not in text:
    raise SystemExit("Âncora da árvore de recursos não encontrada")
text = text.replace(tree_old, tree_new, 1)

anchor = "## 2.1. Aplicar os recursos na ordem das dependências"
if anchor not in text:
    raise SystemExit("Âncora CP2.1 não encontrada")

block = '''## 2.0. Garantir o provisionamento dinâmico `local-path`

O `StatefulSet` PostgreSQL deste laboratório pede explicitamente:

```yaml
storageClassName: local-path
```

Isto significa que **não basta existir um PVC**: o cluster tem de ter uma `StorageClass` chamada `local-path` e um provisioner capaz de criar o respetivo PV. Num cluster Kubernetes instalado de raiz, esse provisioner pode não existir.

Sem esta dependência, o efeito típico aparece no ponto **2.2 — Aguardar convergência**: o PostgreSQL não consegue ficar `Ready`, o PVC permanece `Pending` e o `rollout status` termina por timeout. O erro parece ser do rollout, mas a causa está no storage.

### O que estamos a fazer e porquê

Antes de criar o PostgreSQL, verificamos se o **Local Path Provisioner** está disponível. Se não estiver, instalamo-lo a partir do manifesto incluído no repositório da formação.

O manifesto usado em `00-storage/local-path-storage.yaml` corresponde à versão `v0.0.37` do `rancher/local-path-provisioner`, incluída localmente para que o laboratório não dependa de descarregar YAML externo durante a sessão.

```bash
if ! kubectl get storageclass local-path >/dev/null 2>&1 || \\
   ! kubectl get deployment local-path-provisioner \\
      -n local-path-storage >/dev/null 2>&1; then
  kubectl apply -f 00-storage/local-path-storage.yaml
fi

kubectl rollout status deployment/local-path-provisioner \\
  -n local-path-storage \\
  --timeout=120s

kubectl get storageclass local-path
kubectl get pods -n local-path-storage -o wide
```

### Como interpretar os comandos e flags

```text
kubectl get storageclass local-path
→ verifica se a StorageClass que o StatefulSet referencia existe

kubectl get deployment local-path-provisioner -n local-path-storage
→ verifica se o controller responsável pelo provisionamento está instalado

>/dev/null 2>&1
→ oculta stdout e stderr porque aqui queremos apenas testar sucesso/falha do comando

||
→ executa a condição seguinte quando a anterior falha; neste caso basta faltar a StorageClass ou o Deployment para instalar/reconciliar o provisioner

kubectl apply -f 00-storage/local-path-storage.yaml
→ instala/reconcilia Namespace, RBAC, Deployment, StorageClass e ConfigMap do Local Path Provisioner

kubectl rollout status deployment/local-path-provisioner
→ espera que o controller de storage esteja operacional antes de criar PVCs que dependem dele

-n local-path-storage
→ indica o Namespace onde o provisioner é executado

--timeout=120s
→ evita espera indefinida e transforma ausência de convergência numa falha observável
```

### O que observar para validar

- `deployment "local-path-provisioner" successfully rolled out` ou equivalente;
- `kubectl get storageclass local-path` devolve a classe `local-path`;
- o provisioner aparece `Running` e `Ready` em `local-path-storage`;
- a `StorageClass` apresenta `PROVISIONER` igual a `rancher.io/local-path`;
- só depois avançamos para o PostgreSQL.

> **Checkpoint de storage:** se `local-path` não existir ou o provisioner não estiver `Ready`, não avançar para 2.1. Caso contrário, o erro surgirá mais tarde como PVC `Pending`/rollout em timeout e será mais difícil identificar a causa.

'''

text = text.replace(anchor, block + anchor, 1)
p.write_text(text)
