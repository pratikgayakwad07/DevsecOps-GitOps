FROM node:22-bookworm-slim AS build

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY server.js ./

FROM gcr.io/distroless/nodejs22-debian13:nonroot

WORKDIR /app
ENV NODE_ENV=production
EXPOSE 5000
USER 65532:65532

COPY --from=build --chown=nonroot:nonroot /app/node_modules ./node_modules
COPY --from=build --chown=nonroot:nonroot /app/server.js ./server.js

CMD ["server.js"]
