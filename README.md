# P8 – Pipeline CI/CD avec Docker

Dépôt unique regroupant les deux applications du projet OpenClassrooms P8 :

| Dossier | Application | Stack |
|---|---|---|
| `angular-app/` | Frontend | Angular, Karma/Jasmine, nginx |
| `java-app/` | Backend | Spring Boot, Gradle, JUnit |

## Contenu

```
.
├── .github/workflows/ci.yml   Workflow GitHub Actions générique (phase de test)
├── run-tests.sh               Script de lancement des tests en local
├── angular-app/               Dockerfile, docker-compose.yml, sources Angular
└── java-app/                  Dockerfile, docker-compose.yml, sources Java
```

## Docker

Chaque application possède son `Dockerfile` et son `docker-compose.yml` :

```bash
cd angular-app && docker compose up --build
cd java-app    && docker compose up --build
```

## Tests en local

Prérequis : Node.js 20, JDK 21, dépendances Angular installées (`cd angular-app && npm ci`).

```bash
./run-tests.sh
```

Les rapports JUnit XML sont générés dans `test-results/`.

## Workflow CI (`.github/workflows/ci.yml`)

Un seul fichier, utilisable pour les deux applications. Il se déclenche sur `push` et `pull_request` vers `main`.

1. **`detect`** : repère les projets présents (Angular si `package.json` contient `@angular/core`, Java si `build.gradle` et `gradlew` existent) et construit une matrice.
2. **`test`** : un run par projet détecté, avec des étapes conditionnelles selon le type :
   - Angular : Node 20, cache npm, `npm ci`, `npm test` ;
   - Java : JDK 21, cache Gradle, `./gradlew clean test`.
3. **Rapport** : les résultats JUnit sont publiés dans GitHub (check « Rapport de tests ») et archivés comme artefacts du run.

Le `GITHUB_TOKEN` est limité aux droits nécessaires (`contents: read`, `checks: write`, `pull-requests: write`) ; aucun secret n'est utilisé à ce stade.

Résultats : onglet [Actions](../../actions) du dépôt.
