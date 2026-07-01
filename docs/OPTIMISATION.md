# Optimisation du Dockerfile

## Tableau avant / après

| Critère | Avant | Après |
|---------|-------|-------|
| Image de base | `node:latest` (Debian, ~1.1 GB) | `node:22.3.0-alpine3.20` (Alpine, ~180 MB) |
| Taille image finale | ~1.2 GB | ~150–170 MB (estimation) |
| Multi-stage | Non | Oui (stage `deps` + stage final) |
| Version épinglée | Non | Oui (`22.3.0-alpine3.20`) |
| Outil d'install | `npm install` | `npm ci --omit=dev` |
| devDependencies embarquées | Oui (jest, fast-check, supertest) | Non |
| Ordre COPY optimisé pour cache | Non | Oui (`package.json` avant `main.js`) |
| Utilisateur non-root | Non (root) | Oui (`USER node`) |
| .dockerignore présent | Non | Oui |

---

## Les 5 anti-patterns corrigés

### 1. `FROM node:latest` — Image non épinglée et trop lourde

**Problème :**  
`node:latest` est une image Debian full (~1.1 GB). Le tag `latest` change à chaque nouvelle version de Node.js : deux builds réalisés à 3 mois d'intervalle peuvent produire des binaires différents, ce qui casse la reproductibilité. Un image Debian complète embarque gcc, make, perl, libssl en version Debian — surface d'attaque inutile pour une app Node.js.

**Correction :**  
`node:22.3.0-alpine3.20` — version LTS épinglée exacte, image Alpine (~45 MB de base). Même runtime Node.js, surface réduite, build déterministe.

**Gain :** −83 % sur la taille de l'image de base.

---

### 2. `COPY . .` avant `npm install` — Cache Docker invalidé à chaque changement de code

**Problème :**  
Docker construit les layers en séquence et invalide le cache dès qu'un fichier change. Copier tout le code source avant d'installer les dépendances signifie que la moindre modification de `main.js` ou d'un fichier `public/` force un `npm install` complet depuis zero, même si `package.json` n'a pas bougé.

**Correction :**  
Copier `package.json` et `package-lock.json` **seuls** en premier, lancer `npm ci`, puis copier le code source. Le layer des dépendances est recalculé uniquement quand les manifestes changent.

**Gain :** Build 5 à 20× plus rapide en développement iteratif.

---

### 3. `npm install` au lieu de `npm ci --omit=dev`

**Problème (a) — non-déterminisme :**  
`npm install` résout les versions à la volée selon les contraintes `^` dans `package.json`. Deux builds successifs peuvent installer des versions mineures différentes si un package publie une mise à jour entre temps.

**Problème (b) — devDependencies en production :**  
`npm install` installe toutes les dépendances, y compris `jest`, `fast-check` et `supertest` qui ne servent qu'aux tests. Ces packages représentent ~60 MB et augmentent la surface d'attaque.

**Correction :**  
`npm ci` installe exactement ce qui est dans `package-lock.json` (déterministe). `--omit=dev` exclut les devDependencies.

**Gain :** Image plus petite (~60 MB de moins), builds reproductibles.

---

### 4. Pas de `USER` — Processus tournant en root

**Problème :**  
Par défaut, les containers Docker s'exécutent en tant que `root` (UID 0). Si un attaquant exploite une faille applicative (RCE, path traversal…) et parvient à sortir du container (escape), il obtient les droits root sur le nœud Kubernetes. C'est une violation du principe du moindre privilège.

**Correction :**  
Ajout de `USER node` dans le Dockerfile. L'image officielle `node:alpine` crée l'utilisateur `node` (UID 1000) sans droits particuliers. En Kubernetes, le `securityContext.runAsNonRoot: true` refuse de démarrer le pod si l'image tente de tourner en root — le `USER node` est donc cohérent avec la politique du cluster.

**Gain :** Conformité aux bonnes pratiques CIS Kubernetes Benchmark, compatible avec `runAsNonRoot: true`.

---

### 5. Absence de `.dockerignore` — Contexte de build pollué

**Problème :**  
Sans `.dockerignore`, `COPY . .` envoie au daemon Docker **tout** le répertoire : `node_modules/` (des centaines de MB), `.git/` (historique complet), les fichiers de tests, les `.env` locaux, etc. Cela :
- gonfle le contexte de build envoyé au daemon (réseau + mémoire)
- invalide le cache Docker dès que n'importe quel fichier change (y compris les logs)
- risque d'embarquer des secrets (`.env`) dans l'image poussée sur le registry

**Correction :**  
Création du fichier `.dockerignore` excluant `node_modules/`, `tests/`, `.git/`, `.env*`, `*.log`.

**Gain :** Contexte de build réduit, sécurité des secrets, cache plus stable.

---

## Multi-stage : pourquoi deux stages ?

Le stage `deps` installe les dépendances avec accès aux outils Alpine (compilateurs natifs si besoin d'un addon Node.js). Le stage final copie uniquement `node_modules/` depuis ce stage — aucun outil de compilation, aucun cache npm, aucun `package-lock.json` n'atterrit dans l'image finale. Cette technique garantit que l'image de production ne contient que le strict nécessaire à l'exécution.

```
Stage deps  →  node_modules/ (prod only)
                     ↓ COPY --from=deps
Stage final →  node_modules/ + main.js + public/
               (aucun outil de build, aucun dev dep)
```
