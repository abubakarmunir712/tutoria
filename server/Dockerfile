# ---- build ----
# Debian-based (not alpine): several native deps in this tree (bcrypt, unrs-resolver,
# @prisma/engines, etc.) ship prebuilt binaries for glibc but not musl, so alpine forces
# a from-source compile that isn't reliable for all of them. glibc avoids that entirely.
FROM node:22-bookworm-slim AS builder
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends python3 make g++ \
    && rm -rf /var/lib/apt/lists/*

RUN corepack enable

COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

COPY . .
RUN pnpm exec prisma generate
RUN pnpm build

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
