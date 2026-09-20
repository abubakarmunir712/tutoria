# ---- build ----
FROM node:22-bookworm-slim AS builder
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends python3 make g++ \
    && rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

# `prisma generate` only reads the schema to produce the client — it never connects to
# the database — but prisma.config.ts's env('DATABASE_URL') throws if the variable isn't
# set at all. Docker build ARGs aren't automatically visible to RUN as env vars, so a
# harmless placeholder here is enough; the real DATABASE_URL is only needed at runtime
# (supplied via docker-compose's `environment:`), never baked into the image.
ENV DATABASE_URL="postgresql://user:password@localhost:5432/placeholder"
RUN npx prisma generate
RUN npm run build

# ---- runtime ----
FROM node:22-bookworm-slim AS runner
WORKDIR /app
ENV NODE_ENV=production

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/prisma.config.ts ./prisma.config.ts
COPY --from=builder /app/package.json ./package.json

EXPOSE 3001

# Applies any pending migrations, then starts the server. Prisma CLI is available
# here because we copy the full node_modules (including devDependencies) above.
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/src/main"]
