# Manifests — Sessão 4

- `calico_installation_sessao4.yaml` — recurso `Installation` mínimo do Calico para o CNI/core networking da Sessão 4. Não ativa APIServer, Goldmane nem Whisker, porque esses componentes não são objetivos deste laboratório e acrescentam workloads desnecessários ao cluster pedagógico de dois nós.
- `pod_cordon_test.yaml` — Pod descartável, colocado explicitamente em `k8s-wk-01`, usado para observar o comportamento de `cordon` e `drain` perante um Pod sem controlador.

Os recursos são pedagógicos. O manifesto Calico é deliberadamente reduzido ao âmbito da sessão, e o Pod `cordon-test` não representa a forma recomendada de executar workloads de produção.
