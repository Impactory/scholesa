# Multi-stage Dockerfile for Next.js production on Cloud Run
# Build stage
FROM node:24-bullseye-slim AS builder
WORKDIR /app

# Copy package files first for better caching
COPY package.json package-lock.json ./
# If you use a workspace or functions folder, copy package-lock there too as needed
RUN npm ci --no-audit --no-fund --no-update-notifier --loglevel=error

# Copy the rest of the source
COPY . ./

# Build the Next.js app
RUN npm run build

# Prune dev dependencies and create minimal production install
RUN npm prune --omit=dev

# Production image
FROM node:24-bullseye-slim AS runner
WORKDIR /app

ENV NODE_ENV=production

# Copy necessary files from builder
COPY --from=builder /app/package.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/next.config.mjs ./next.config.mjs

# Expose default Next.js port (Cloud Run uses port from $PORT env var)
ENV PORT=8080
ENV HOSTNAME=0.0.0.0
EXPOSE 8080

# Use a lightweight non-root user
RUN useradd --user-group --create-home --shell /bin/false appuser
USER appuser

# Start the Next.js server
CMD ["npm", "start"]
