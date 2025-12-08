# Rapport de Projet - TD Docker 2025



## Introduction

Ce rapport présente le travail réalisé dans le cadre du TD Docker 2025. L'objectif était de concevoir, construire et déployer une application complète en utilisant Docker et Docker Compose. Le projet comprend trois services principaux qui communiquent entre eux ( api, db, frontend ) pour former une architecture complete.

---

## 1. Architecture de l'Application


### Frontend (Vue.js + Nginx)

Le frontend est une application Vue 3. L'application est servie par un serveur Nginx qui gère le reverse proxy vers l'API backend, ce qui permet d'éviter les problèmes de CORS en plaçant le frontend et l'API sur le même domaine. Les requêtes vers l'API sont préfixées par `/api/` et Nginx les redirige automatiquement vers le service API sur le port `3000`.

Le frontend affiche une liste d'items récupérés depuis la base de données via l'API. Le service d'API côté client ( `ItemService` ) gère les timeouts, les erreurs de réseau et affiche des messages appropriés à l'utilisateur en cas de problème.

### API (Node.js + Express)

L'API est développée en Node.js avec le framework Express. Elle suit une architecture avec des contrôleurs, des services et des repositories. L'API expose plusieurs endpoints dont les deux principaux demandés pour ce TD qui sont : 

- `/status`: retourne un simple message OK pour vérifier que l'API fonctionne
- `/items`: récupère la liste complète des items depuis la base de données PostgreSQL
- `/ready`: effectue un healthcheck en testant la connexion à la base de données, permettant de vérifier que le service est bien opérationnel.


L'API intègre un système de logging structuré qui enregistre toutes les requêtes HTTP avec leurs détails. Le logger est configurable via des variables d'environnement et supporte deux modes : un format JSON pour la production qui facilite l'analyse automatisée des logs, et un format human-readable pour le développement avec un affichage coloré et indenté. Le niveau de verbosité peut être ajusté entre ERROR, WARN, INFO et DEBUG selon les besoins.

> NOTE : Ce système de logging "avancé" n'était pas demandé pour le TD Docker, mais je l'ai vu comme un bon exercice personnel pour mettre en pratique les bonnes pratiques de développement backend. 

### Base de données (PostgreSQL)

La base de données utilise PostgreSQL en version 15 sur une image Alpine pour rester légère. Un script SQL d'initialisation est automatiquement exécuté au premier démarrage du conteneur. Ce script crée la base de données, l'utilisateur dédié et la table items avec quelques données de test de manière impotente.

Les données sont sauvgardées dans le volume Docker du projet,  garantissant leur pérénité même après l'arrêt /  suppression des containers.

### Communications entre services


```
┌─────────────────────────────────────────────────────────────────┐
│                      Réseau: td_network                         │
│                     (Bridge Docker isolé)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐         ┌──────────────┐      ┌───────────┐   │
│  │   Frontend   │         │     API      │      │     DB    │   │
│  │  (Nginx:8080)│  ────>  │ (Node:3000)  │ ───> │(Postgres) │   │
│  │              │  HTTP   │              │ SQL  │   :5432   │   │
│  └──────────────┘         └──────────────┘      └───────────┘   │
│         │                                                       │
│         │ Reverse Proxy                                         │
│         │ /api/* → api:3000                                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
         │
         │ Port mapping: 8080:8080
         ↓
   ┌─────────────┐
   │  Navigateur │  (Utilisateur)
   │  localhost  │
   └─────────────┘

```
> NOTE : schéma généré par Intelligence Artificiel.


Flow des requêtes:
1. Navigateur → http://localhost:8080/api/items
2. Nginx (frontend) → reverse proxy vers http://api:3000/items
3. API (Node.js) → SELECT depuis PostgreSQL (db:5432)
4. DB → Retourne les données
5. API → JSON response
6. Nginx → Transmet au navigateur

---

## 2. Commandes Clés Utilisées


### Construction des images

La commande `docker build` permet de construire chaque image à partir des Dockerfiles. Pour l'API on utilise `docker build -t lenderdiam/td-docker-api:latest -f api/Dockerfile api/` qui construit l'image en lui donnant un tag et en spécifiant le contexte de build.

### Orchestration avec Docker Compose

La commande principale est `docker compose up -d` qui démarre tous les services définis dans docker-compose.yml en mode détaché. Docker Compose lit le fichier de configuration `docker-compose.yml`, crée le réseau `networks: td_network: driver` et le volume `volumes: db_data:`, 

Pour arrêter l'application, on utilise `docker compose down` qui arrête et supprime les conteneurs et le réseau mais préserve les volumes. Si on veut aussi supprimer les volumes, on peut ajouter le flag -v mais cela supprimera toutes les données de la base.

La commande `docker compose logs -f` affiche les logs de tous les services en temps réel. Particulièrement utile pour voir le logger de l'API.

Pour reconstruire les images après un changement dans le code, on utilise `docker compose build` ou `docker compose up -d --build` qui rebuild et redémarre en une seule commande.

### Vérification de l'état

La commande `docker compose ps` qui liste tous les conteneurs du projet avec leur état, leurs ports exposés et depuis combien de temps ils tournent.

### Automatisation via le script

Le script PowerShell `build-and-deploy.ps1` automatise toute la chaîne de build et déploiement. Il exécute plusieurs commandes dans l'ordre : vérification de l'environnement Docker, build des trois images avec docker build, validation de docker-compose.yml avec docker compose config, scan de sécurité ( optionnel ) avec Trivy, login sur Docker Hub, push des images et enfin déploiement avec docker compose up. Le script gère aussi les erreurs et affiche des messages colorés pour indiquer la progression. En revanche il ne gère pas la signature d'image ( cf [problème docker content trust](#problème-avec-docker-content-trust-sur-windows) ).


### Tests automatisés

Le script `run-all-tests.ps1` lance un ensemble de tests PowerShell qui vérifient différents aspects de l'application. Il exécute des tests pour vérifier que les conteneurs tournent avec des utilisateurs non-root, que les capabilities Linux sont bien restreintes, que l'API répond correctement aux requêtes...

---

## 3. Bonnes Pratiques Suivies

### Builds multi-étapes

Les Dockerfiles de l'API et du frontend utilisent des builds multi-étapes. Cette technique permet de séparer la phase de build de la phase de runtime. Par exemple pour le frontend, une première étape builder utilise Node.js pour compiler l'application Vue avec Vite et générer les fichiers statiques optimisés. Une deuxième étape utilise une image Nginx légère et copie uniquement les fichiers compilés depuis le builder. On évite ainsi d'avoir tous les outils de build et node_modules dans l'image finale, ce qui réduit grandement sa taille finale.


### Fichiers .dockerignore

Chaque service possède un fichier .dockerignore qui liste les fichiers et dossiers à exclure lors du build.

### Utilisateurs non-root

Tous les conteneurs s'exécutent avec un utilisateur non-root pour renforcer la sécurité. L'API utilise l'utilisateur node, la base de données utilise postgres et le frontend utilise nginx. Si un attaquant arrive à compromettre le conteneur, il n'aura pas les privilèges root et ne pourra pas facilement s'échapper du conteneur ou compromettre l'hôte. Les Dockerfiles définissent explicitement ces utilisateurs avec l'instruction USER et configurent les permissions des fichiers en conséquence avec chown.

### Restriction des capabilities Linux

Dans docker-compose.yml, tous les services utilisent cap_drop pour retirer toutes les droits Linux par défaut, puis cap_add réajoute uniquement celles qui sont strictement nécessaires. Par exemple la base de données a besoin de CHOWN et SETUID pour gérer les permissions de ses fichiers, mais pas des droits admin tel que SYS_ADMIN.

### Security options

L'option no-new-privileges:true est activée sur tous les services. Elle empêche les processus dans le conteneur d'acquérir de nouveaux privilèges via setuid, sudo ou autres mécanismes. Même si un binaire setuid est présent dans le conteneur, il ne pourra pas élever ses privilèges.

### Healthchecks complets

Chaque service définit un healthcheck dans docker-compose.yml. La base de données utilise pg_isready pour vérifier qu'elle accepte les connexions. L'API est testée avec curl sur l'endpoint /status. Le frontend vérifie que Nginx répond sur l'endpoint /nginx-health.

### Externalisation de la configuration

Toutes les variables de configuration sont externalisées dans le fichier .env au lieu d'être directement écris dans le code ou les Dockerfiles.

### Limites de ressources

Le `docker-compose.yml` définit des limites de CPU et mémoire pour chaque service. Cela évite qu'un service défaillant ou attaqué consomme toutes les ressources de l'hôte et impacte les autres services. Par exemple l'API est limitée à 0.5 CPU et 512 Mo de RAM, suffissant pour répondre à ses besoins.


### Scan de sécurité

Le projet intègre Trivy pour scanner les images à la recherche de vulnérabilités connues. Trivy analyse les packages installés et les compare à des bases de données de CVE pour détecter les failles de sécurité. Le script d'automatisation exécute ce scan avant le déploiement et affiche le nombre de vulnérabilités critiques et hautes.

---

## 4. Difficultés Rencontrées

### Problème avec Docker Content Trust sur Windows

La principale difficulté rencontrée a été l'impossibilité d'utiliser Docker Content Trust pour signer les images. J'ai suivi toute la procédure de configuration : [docker trust](https://docs.docker.com/engine/security/trust/)

Seulement, toutes mes tentatives de signature ont échoué avec l'erreur "no hashes specified for target".

J'ai essayé plusieurs pistes de solutions de contournement trouvées sur [GitHub](https://github.com/docker/for-mac/issues/7273), [Docker Community](https://forums.docker.com/t/failing-to-sign-image-with-docker-content-trust/148005) et  Stack Overflow : utiliser docker trust sign manuellement, spécifier le digest au lieu du tag, nettoyer et réinitialiser complètement les métadonnées DCT locales, mais rien n'a fonctionné.


### Gestion des permissions Nginx

Une autre difficulté a été de faire tourner Nginx en tant qu'utilisateur non-root. Par défaut, Nginx a besoin de privilèges pour écouter sur les ports inférieurs à 1024 et pour écrire dans certains dossiers système. J'ai dû configurer Nginx pour écouter sur le port 8080 au lieu de 80, créer le fichier PID dans un emplacement accessible à l'utilisateur nginx, et donner les bonnes permissions à tous les dossiers dont Nginx a besoin.

---

## 5. Améliorations Possibles

### Tests multi-plateformes

Actuellement, tous les scripts PowerShell et les tests ont été développés et testés uniquement sur Windows avec PowerShell. Une amélioration évidente serait de rendre le projet compatible avec macOS et Linux.

### Pipeline CI/CD avec GitHub Actions

Le projet pourrait bénéficié d'une pipeline d'intégration continue. On pourrait configurer GitHub Actions pour builder automatiquement les images à chaque push, exécuter les tests, scanner les vulnérabilités avec Trivy et déployer automatiquement sur un environnement de staging.

### Backup automatisé de la base de données

Pour ne pas perdre de données, il faudrait mettre en place des backups réguliers de PostgreSQL. On pourrait créer un script qui se connecte à la base, fait un dump avec pg_dump et sauvegarde le fichier. Il faudrait aussi tester régulièrement la restauration des backups pour s'assurer qu'ils sont valides.

---

## Conclusion

Ce projet m'a permis de mettre en pratique pas mal de concepts Docker : orchestration multi-services avec compose, builds multi-étapes pour optimiser les images, sécurisation avec utilisateurs non-root...

Le projet final est un rendu fonctionnel qui suit les bonnes pratiques docker et de programation. Un projet grandement enrichissant d'un point de vu connaissances.
