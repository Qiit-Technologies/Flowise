# Stage 1: Build
FROM node:20-alpine AS builder

# Install system dependencies and build tools for native compilation
RUN apk add --no-cache \
    libc6-compat \
    python3 \
    make \
    g++ \
    build-base \
    cairo-dev \
    pango-dev \
    chromium \
    curl && \
    npm install -g pnpm

WORKDIR /usr/src/flowise

# Set CI=true to avoid non-TTY confirmation prompts during pnpm prune
ENV CI=true

# Copy app source (respects .dockerignore)
COPY . .

# Install dependencies and build
RUN pnpm install --ignore-scripts && \
    pnpm build && \
    pnpm prune --prod --ignore-scripts

# Stage 2: Runtime
FROM node:20-alpine AS runner

# Install runtime dependencies ONLY
RUN apk add --no-cache \
    libc6-compat \
    cairo \
    pango \
    chromium \
    curl && \
    npm install -g pnpm

WORKDIR /usr/src/flowise

# Copy build artifacts and production dependencies from builder
COPY --from=builder --chown=node:node /usr/src/flowise/node_modules ./node_modules
COPY --from=builder --chown=node:node /usr/src/flowise/packages ./packages
COPY --from=builder --chown=node:node /usr/src/flowise/package.json ./package.json
COPY --from=builder --chown=node:node /usr/src/flowise/pnpm-workspace.yaml ./pnpm-workspace.yaml

ENV PUPPETEER_SKIP_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# Memory set for typical Render plans (e.g. Starter/Pro). Adjust if needed.
ENV NODE_OPTIONS=--max-old-space-size=2048

USER node

EXPOSE 3000

# Start the server directly, bypassing devDependencies like run-script-os
CMD [ "node", "packages/server/bin/run", "start" ]
