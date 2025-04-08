# Use Node 18 as the base image
FROM node:18-alpine AS base

# Install dependencies needed for Prisma and bcrypt
RUN apk add --no-cache openssl libc6-compat python3 make g++ curl

# Create app directory
WORKDIR /app

# Install dependencies
FROM base AS deps
COPY package.json package-lock.json ./
RUN npm ci

# Build the application
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Generate Prisma client
RUN npx prisma generate

# Rebuild bcrypt for the current architecture
RUN npm rebuild bcrypt --build-from-source

# Build the Next.js application
RUN npm run build

# Production image
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
# ENV PORT 80 # No longer needed, set via npm start
ENV HOSTNAME="0.0.0.0"

# Create a non-root user to run the app
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs
USER nextjs

# Copy necessary files from builder
COPY --from=builder --chown=nextjs:nodejs /app/.next ./.next
COPY --from=builder --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nextjs:nodejs /app/package.json ./package.json
COPY --from=builder --chown=nextjs:nodejs /app/package-lock.json ./package-lock.json
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/prisma ./prisma
COPY --from=builder --chown=nextjs:nodejs /app/next.config.mjs ./next.config.mjs

# Expose the port the app will run on
EXPOSE 3000

# Add a health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:3000/api/health || exit 1

# Define the command to run the app
CMD ["node", ".next/standalone/server.js"] 