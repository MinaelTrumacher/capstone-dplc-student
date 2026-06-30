# ─── Stage 1: deps de production ───────────────────────────────────────────
FROM node:22.3.0-alpine3.20 AS deps

WORKDIR /app

# Copier uniquement les manifestes pour maximiser le cache de layers
COPY package.json package-lock.json ./

# Installation déterministe des dépendances de production uniquement
RUN npm ci --omit=dev

# ─── Stage 2: image finale ──────────────────────────────────────────────────
FROM node:22.3.0-alpine3.20

WORKDIR /app

# Copier les dépendances compilées depuis le stage précédent
COPY --from=deps /app/node_modules ./node_modules

# Copier le code source (invalidé seulement si le code change, pas les deps)
COPY main.js ./
COPY job-standings.js ./
COPY public ./public

# Utilisateur non-root pour limiter la surface d'attaque
USER node

EXPOSE 3000

CMD ["node", "main.js"]
