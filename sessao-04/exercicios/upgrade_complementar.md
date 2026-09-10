# Exercício de Consolidação — Upgrade Kubernetes 1.36.x → 1.37.x

O upgrade real já faz parte do laboratório principal da Sessão 4. Este exercício serve para consolidar a sequência e a justificação técnica.

## 1. Estado inicial

```bash
kubectl get nodes -o wide
kubeadm version
kubectl version --client
```

Regista a versão 1.36.x de partida.

## 2. Descobrir o destino

Depois de apontar o APT para a série 1.37:

```bash
sudo apt-get update
sudo apt-cache madison kubeadm
```

Regista:

```text
PKG_1_37 = __________________
K8S_1_37 = v_________________
```

Baseline preparada em setembro de 2026: **1.36.4 → 1.37.0**.

## 3. Ordenar o upgrade do Control Plane

Ordena:

```text
kubeadm upgrade apply
atualizar kubelet
mudar o repositório para 1.37
uncordon
kubeadm upgrade plan
atualizar kubeadm
drain
reiniciar kubelet
```

## 4. Ordenar o upgrade do Worker

Ordena:

```text
kubeadm upgrade node
drain do Worker
atualizar kubelet
atualizar kubeadm
mudar o repositório para 1.37
reiniciar kubelet
uncordon
```

## 5. Version skew

Durante o upgrade, preenche:

```text
Control Plane: __________________
Worker:        __________________
```

Explica por que esta diferença temporária é aceitável dentro da política de version skew e do procedimento suportado.

## 6. Decisão operacional

Um `kubectl drain` recusa continuar porque existe um Pod sem controller.

Responde:

1. deves usar imediatamente `--force`?
2. que risco existe?
3. como mudaria a decisão num ambiente de produção?

## 7. Validação final

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get tigerastatus
kubectl cluster-info
```

Confirma:

```text
[ ] Control Plane Ready em v1.37.x
[ ] Worker Ready em v1.37.x
[ ] CoreDNS Running
[ ] Calico/Tigera saudável
[ ] Worker schedulable
```

## 8. Questões de reflexão

1. Porque não devemos saltar diretamente de 1.36 para 1.38?
2. Porque o Control Plane é atualizado antes do Worker?
3. Porque `kubeadm` é atualizado antes do `kubelet`?
4. Para que serve `kubeadm upgrade plan`?
5. Porque o Worker usa `kubeadm upgrade node` e não `kubeadm upgrade apply`?
6. Porque se deve validar o CNI depois do upgrade?
7. Qual a diferença entre uma combinação que funcionou no laboratório e uma combinação oficialmente testada pelo fornecedor?
