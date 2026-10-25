# ---- Stage 1: Build ----
FROM node:20-alpine AS builder

WORKDIR /app

# Install deps first (better cache)
COPY package*.json ./
RUN npm ci

# Copy source and build
COPY . .
RUN npm run build

# ---- Stage 2: Serve with nginx ----
FROM nginx:1.27-alpine

# Remove default nginx index page
RUN rm -rf /usr/share/nginx/html/*

# Copy the React build output
COPY --from=builder /app/build /usr/share/nginx/html

# Custom nginx config — proxy /api to the backend service
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
