# Quiz Formativo — Sessão 4

**Nome:** ____________________  **Tempo:** 10–12 min

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

5. Em que nó se executa `kubeadm init`?

6. Em que nó se executa `kubeadm join`?

7. Qual é a versão minor inicial do cluster nesta sessão?

8. Qual é a versão minor de destino?

9. Porque é necessário mudar o repositório `pkgs.k8s.io` da série 1.36 para a série 1.37 durante o upgrade?

10. Para que serve `kubeadm upgrade plan`?

11. Porque o Control Plane é atualizado antes do Worker?

12. Qual comando é usado no Worker durante o upgrade?
   - a) `kubeadm upgrade apply`
   - b) `kubeadm upgrade node`
   - c) `kubeadm init`
   - d) `kubeadm join`

13. Porque se drena o nó antes de atualizar o `kubelet` numa mudança minor?

14. Porque pode existir version skew temporário durante o processo?

15. Que componentes deves voltar a validar depois do upgrade?

16. Porque "funcionou no laboratório" não significa necessariamente "é oficialmente testado pelo fornecedor"?
