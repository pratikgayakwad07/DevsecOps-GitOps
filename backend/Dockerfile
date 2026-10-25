# Use Node.js LTS on Alpine for a small image
FROM node:20-alpine

# Run as non-root for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Install dependencies before copying source (layer cache)
COPY package*.json ./
RUN npm ci --omit=dev

# Copy application source code
COPY . .

# Transfer ownership to the non-root user
RUN chown -R appuser:appgroup /app

USER appuser

# Expose application port
EXPOSE 5003

# Healthcheck so Docker / ECS can detect unhealthy containers
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget -qO- http://localhost:5003/health || exit 1

# Start the application
CMD ["node", "server.js"]
