# Nom de l'image et du cluster pour éviter les répétitions
IMAGE_NAME=my-custom-nginx:latest
CLUSTER_NAME=lab

# La cible 'all' est celle exécutée par défaut si on tape juste 'make'
all: build-image import-image deploy run

# Nouvelle cible pour nettoyer la config locale et s'assurer du contexte
clean-kube:
	@echo "--- Nettoyage de la configuration Kubernetes locale ---"
	k3d kubeconfig merge $(CLUSTER_NAME) --kubeconfig-switch-context || true
	@echo "--- Nettoyage des anciennes ressources ---"
	kubectl delete deployment custom-nginx --ignore-not-found=true
	kubectl delete service custom-nginx-service --ignore-not-found=true

build-image:
	@echo "--- Construction de l'image avec Packer ---"
	packer init .
	packer build nginx.pkr.hcl

import-image:
	@echo "--- Import de l'image dans le cluster K3d ---"
	k3d image import $(IMAGE_NAME) -c $(CLUSTER_NAME)

deploy:
	@echo "--- Déploiement via Ansible ---"
	ansible-playbook deploy.yml

clean:
	@echo "--- Nettoyage du déploiement ---"
	kubectl delete deployment custom-nginx || true
	kubectl delete service custom-nginx-service || true

# Automatisation du tunnel pour voir le site
run:
	@echo "--- Attente que le Pod soit prêt ---"
	kubectl wait --for=condition=ready pod -l app=custom-nginx --timeout=60s
	@echo "--- Lancement du tunnel sur le port 8081 ---"
	@echo "Lien : https://$(CODESPACE_NAME)-8081.$(GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN)"
	kubectl port-forward svc/custom-nginx-service 8081:80