# Quiz Formativo — Sessão 4

**Nome:** ____________________  **Tempo:** 10 min

1. Qual componente corre em todos os Nodes e comunica com o Control Plane?
   - a) `kubectl`
   - b) `kubelet`
   - c) `kubeadm`
   - d) `etcd`

2. O CRI é:
   - a) um runtime
   - b) uma interface entre `kubelet` e runtime
   - c) o CNI
   - d) um ficheiro de configuração

3. Porque usamos `SystemdCgroup = true` neste laboratório?

4. Após `kubeadm init`, o Control Plane aparece `NotReady` e o CNI ainda não foi instalado. É necessariamente um erro? Explica.

5. Que comando é usado para adicionar um Worker?

6. Um contexto `kubeconfig` associa principalmente:
   - a) container + Pod
   - b) cluster + utilizador + namespace opcional
   - c) Node + Service
   - d) runtime + CRI

7. O que faz `kubectl cordon k8s-wk-01`?

8. Porque pode `kubectl drain ... --ignore-daemonsets` recusar continuar perante um Pod criado diretamente?

9. Depois de `drain --force`, porque esse Pod não reaparece automaticamente?

10. Indica três comandos úteis para investigar um Node `NotReady`.

11. Qual é a finalidade de `kubeadm upgrade plan` nesta sessão?

12. Indica uma diferença entre manutenção planeada e falha de nó.
