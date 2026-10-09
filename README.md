# P8 – Pipeline CI/CD avec Docker

Dépôt unique regroupant les deux applications du projet OpenClassrooms P8 :

| Dossier | Application | Stack | Port Docker |
|---|---|---|---|
| `angular-app/` | Frontend | Angular, Karma/Jasmine, nginx | 80 |
| `java-app/` | Backend | Spring Boot, Gradle, JUnit, PostgreSQL | 8080 |

## Contenu

```
.
├── .github/workflows/ci.yml   Workflow GitHub Actions générique (tests + build Docker)
├── run-tests.sh               Lance les tests des deux applications en local
├── angular-app/               Dockerfile, docker-compose.yml, sources Angular
└── java-app/                  Dockerfile, docker-compose.yml, sources Java
```

## Lancer les applications avec Docker

Prérequis : Docker et Docker Compose.

```bash
# Frontend Angular -> http://localhost
cd angular-app && docker compose up --build

# Backend Java + base PostgreSQL -> http://localhost:8080
cd java-app && docker compose up --build
```

Arrêt : `docker compose down` dans le dossier concerné.

## Lancer les tests en local

Prérequis : Node.js 20+, Google Chrome (tests Karma en mode headless), JDK 21.

**Les deux applications d'un coup** (depuis la racine) :

```bash
(cd angular-app && npm ci)   # une seule fois : installe les dépendances Angular
./run-tests.sh
```

Le script exécute `npm test` (Angular) puis `./gradlew clean test` (Java), copie les rapports JUnit XML dans `test-results/angular/` et `test-results/java/`, et retourne un code d'erreur si une suite échoue.

**Une application seule :**

```bash
cd angular-app && npm ci && npm test          # rapports dans angular-app/reports/
cd java-app    && ./gradlew clean test        # rapports dans java-app/build/test-results/test/
```

## Workflow CI (`.github/workflows/ci.yml`)

Un seul fichier, utilisable pour les deux applications. Il se déclenche sur `push` (`main` et `feature/**`) et sur `pull_request` vers `main`.

1. **Job `detect`** : parcourt la racine et les sous-dossiers, repère les projets (Angular si `package.json` contient `@angular/core`, Java si `build.gradle` et `gradlew` existent) et construit une matrice `[{dir, type}, …]`.
2. **Job `test`** : une exécution par projet détecté, en parallèle (`strategy.matrix`, `working-directory` = dossier du projet). Les étapes sont choisies par des conditions `if: matrix.type == …` :
   - Angular : Node 20, cache npm, `npm ci`, `npm test` ;
   - Java : JDK 21, cache Gradle, `./gradlew clean test`.
3. **Rapport** (dans le job `test`) : les résultats JUnit XML sont publiés dans GitHub (check « Rapport de tests (angular|java) ») et archivés comme artefacts du run (`test-results-angular`, `test-results-java`).

4. **Job `build`** (après `test`, uniquement sur `push`) : une exécution par projet qui construit l'image Docker du dossier, la vérifie, puis la publie sur le GitHub Container Registry :
   - nom : `ghcr.io/<propriétaire>/<dépôt>/angular` et `.../java` (en minuscules) ;
   - tag : `<branche>-<sha court du commit>`, par exemple `main-1a2b3c4` ;
   - vérification avant publication : Angular, nginx doit servir l'application ; Java, le JAR doit être présent et le JRE 21 fonctionner (l'application complète nécessite PostgreSQL) ;
   - connexion avec le `GITHUB_TOKEN` (droit `packages: write`), aucun secret à créer.

Les versions sont définies par les variables d'environnement `NODE_VERSION`, `JAVA_VERSION` et `REGISTRY` en tête du fichier. Le `GITHUB_TOKEN` est limité aux droits nécessaires (`contents: read`, `checks: write`, `pull-requests: write`, `packages: write`) ; aucun secret n'est utilisé à ce stade.

**Consulter les résultats :** onglet **Actions** du dépôt → choisir un run → jobs `Tests (…)` et `Build Docker (…)`, rapport dans le résumé et artefacts en bas de page. Les images publiées sont dans la section **Packages** du dépôt.
**Récupérer une image :** `docker pull ghcr.io/<propriétaire>/<dépôt>/angular:<tag>` (connexion préalable si le package est privé).
**Relancer un run :** onglet Actions → run → « Re-run all jobs », ou pousser un nouveau commit sur `main`.
