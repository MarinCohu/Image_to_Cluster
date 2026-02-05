------------------------------------------------------------------------------------------------------
ATELIER FROM IMAGE TO CLUSTER
------------------------------------------------------------------------------------------------------
L’idée en 30 secondes : Cet atelier consiste à **industrialiser le cycle de vie d’une application** simple en construisant une **image applicative Nginx** personnalisée avec **Packer**, puis en déployant automatiquement cette application sur un **cluster Kubernetes** léger (K3d) à l’aide d’**Ansible**, le tout dans un environnement reproductible via **GitHub Codespaces**.
L’objectif est de comprendre comment des outils d’Infrastructure as Code permettent de passer d’un artefact applicatif maîtrisé à un déploiement cohérent et automatisé sur une plateforme d’exécution.
  
-------------------------------------------------------------------------------------------------------
Séquence 1 : Codespace de Github
-------------------------------------------------------------------------------------------------------
Objectif : Création d'un Codespace Github  
Difficulté : Très facile (~5 minutes)
-------------------------------------------------------------------------------------------------------
**Faites un Fork de ce projet**. Si besion, voici une vidéo d'accompagnement pour vous aider dans les "Forks" : [Forker ce projet](https://youtu.be/p33-7XQ29zQ) 
  
Ensuite depuis l'onglet [CODE] de votre nouveau Repository, **ouvrez un Codespace Github**.
  
---------------------------------------------------
Séquence 2 : Création du cluster Kubernetes K3d
---------------------------------------------------
Objectif : Créer votre cluster Kubernetes K3d  
Difficulté : Simple (~5 minutes)
---------------------------------------------------
Vous allez dans cette séquence mettre en place un cluster Kubernetes K3d contenant un master et 2 workers.  
Dans le terminal du Codespace copier/coller les codes ci-dessous etape par étape :  

**Création du cluster K3d**  
```
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
```
```
k3d cluster create lab \
  --servers 1 \
  --agents 2
```
**vérification du cluster**  
```
kubectl get nodes
```
**Déploiement d'une application (Docker Mario)**  
```
kubectl create deployment mario --image=sevenajay/mario
kubectl expose deployment mario --type=NodePort --port=80
kubectl get svc
```
**Forward du port 80**  
```
kubectl port-forward svc/mario 8080:80 >/tmp/mario.log 2>&1 &
```
**Réccupération de l'URL de l'application Mario** 
Votre application Mario est déployée sur le cluster K3d. Pour obtenir votre URL cliquez sur l'onglet **[PORTS]** dans votre Codespace et rendez public votre port **8080** (Visibilité du port).
Ouvrez l'URL dans votre navigateur et jouer !

---------------------------------------------------
Séquence 3 : Exercice
---------------------------------------------------
Objectif : Customisez un image Docker avec Packer et déploiement sur K3d via Ansible
Difficulté : Moyen/Difficile (~2h)
---------------------------------------------------  
Votre mission (si vous l'acceptez) : Créez une **image applicative customisée à l'aide de Packer** (Image de base Nginx embarquant le fichier index.html présent à la racine de ce Repository), puis déployer cette image customisée sur votre **cluster K3d** via **Ansible**, le tout toujours dans **GitHub Codespace**.  

**Architecture cible :** Ci-dessous, l'architecture cible souhaitée.   
  
![Screenshot Actions](Architecture_cible.png)   
  
---------------------------------------------------  
## Processus de travail (résumé)

1. Installation du cluster Kubernetes K3d (Séquence 1)
2. Installation de Packer et Ansible
3. Build de l'image customisée (Nginx + index.html)
4. Import de l'image dans K3d
5. Déploiement du service dans K3d via Ansible
6. Ouverture des ports et vérification du fonctionnement

---------------------------------------------------
Séquence 4 : Documentation  
Difficulté : Facile (~30 minutes)
---------------------------------------------------
**Complétez et documentez ce fichier README.md** pour nous expliquer comment utiliser votre solution.  
Faites preuve de pédagogie et soyez clair dans vos expliquations et processus de travail.  
   
---------------------------------------------------
Evaluation
---------------------------------------------------
Cet atelier, **noté sur 20 points**, est évalué sur la base du barème suivant :  
- Repository exécutable sans erreur majeure (4 points)
- Fonctionnement conforme au scénario annoncé (4 points)
- Degré d'automatisation du projet (utilisation de Makefile ? script ? ...) (4 points)
- Qualité du Readme (lisibilité, erreur, ...) (4 points)
- Processus travail (quantité de commits, cohérence globale, interventions externes, ...) (4 points) 



------------------------------------------------------------------------------------------------------
-------------------------------------         Rapport       ------------------------------------------
------------------------------------------------------------------------------------------------------


# **1. Installation des outils (Packer & Ansible)**
Dans le terminal Codespaces, installation des dépendances manquantes :

1.1 Installation de Packer
```
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo rm -f /etc/apt/sources.list.d/yarn.list
sudo apt-get update && sudo apt-get install -y packer
```

1.2 Installation du module Python pour Kubernetes
```
pip install kubernetes
ansible-galaxy collection install kubernetes.core
```

1.3 Installation d'Ansible
```
pip install ansible
```

1.4 Verification d'installation
```
packer version
ansible --version
pip show kubernetes
ansible-galaxy collection list
```

--------------------------------------------------------------------------------
# **2. Build de l'image avec Packer**
Crée un fichier nommé ```nginx.pkr.hcl```. Packer va utiliser Docker pour construire l'image, y injecter le fichier index.html, puis la sauvegarder localement.

```
packer {
  required_plugins {
    docker = {
      version = ">= 1.0.8"
      source  = "github.com/hashicorp/docker"
    }
  }
}

source "docker" "nginx" {
  image  = "nginx:latest"
  commit = true
}

build {
  sources = ["source.docker.nginx"]

  provisioner "file" {
    source      = "index.html"
    destination = "/usr/share/nginx/html/index.html"
  }

  post-processor "docker-tag" {
    repository = "my-custom-nginx"
    tag        = ["latest"]
  }
}
```

==> Commande : 
```
packer init . && packer build nginx.pkr.hcl
```


--------------------------------------------------------------------------------
# **3. Import de l'image dans K3d**
C'est une étape cruciale souvent oubliée. K3d est un cluster isolé ; il ne connaît pas l'image locale si on ne lui "injectes" pas.
```
k3d image import my-custom-nginx:latest -c lab
```


--------------------------------------------------------------------------------
# **4. Déploiement via Ansible**
Au lieu de faire un kubectl apply, on utilise Ansible pour piloter Kubernetes. Crée un fichier '''deploy.yml'''.

```
- hosts: localhost
  tasks:
    - name: Créer le déploiement Nginx
      kubernetes.core.k8s:
        definition:
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: custom-nginx
            namespace: default
          spec:
            replicas: 1
            selector:
              matchLabels:
                app: custom-nginx
            template:
              metadata:
                labels:
                  app: custom-nginx
              spec:
                containers:
                - name: nginx
                  image: my-custom-nginx:latest
                  imagePullPolicy: Never # Très important pour K3d !
                  ports:
                  - containerPort: 80
    - name: Créer le service Nginx
      kubernetes.core.k8s:
        definition:
          apiVersion: v1
          kind: Service
          metadata:
            name: custom-nginx-service
            namespace: default
          spec:
            type: NodePort
            selector:
              app: custom-nginx
            ports:
              - port: 80
                targetPort: 80
```

Note : Il y aura besoin d'installer la collection community. Assurez-vous que la commande ```ansible-galaxy collection install kubernetes.core``` de la partie 1 s'est exécuté correctement.

--------------------------------------------------------------------------------
# **5. Pour aller chercher les points de "Degré d'automatisation" (Le Makefile)**
Le professeur a mentionné un Makefile. C'est le secret pour avoir les 4 points d'automatisation. Crée un fichier Makefile à la racine :

```
# Nom de l'image et du cluster pour éviter les répétitions
IMAGE_NAME=my-custom-nginx:latest
CLUSTER_NAME=lab

# La cible 'all' est celle exécutée par défaut si on tape juste 'make'
all: build-image import-image deploy run

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
	@echo "--- Lancement du tunnel sur le port 8081 ---"
	@echo "Lien : https://$(CODESPACE_NAME)-8081.$(GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN)"
	kubectl port-forward svc/custom-nginx-service 8081:80
```

--------------------------------------------------------------------------------
# Pour finir
Il ne reste plus qu'à exécuter la commande ```make all``` et de cliquer sur le lien.

# TADAA !



