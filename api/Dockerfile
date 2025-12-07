FROM node:22-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci --production --quiet

COPY src/app.js ./src/
COPY src/config ./src/config
COPY src/controllers ./src/controllers
COPY src/middlewares ./src/middlewares
COPY src/models ./src/models
COPY src/repositories ./src/repositories
COPY src/routes ./src/routes
COPY src/services ./src/services
COPY src/utils ./src/utils

FROM node:22-alpine

RUN apk add --no-cache curl

WORKDIR /app

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/src ./src
COPY package.json ./package.json

RUN chown -R node:node /app

EXPOSE 3000
ENV NODE_ENV=production


USER node

CMD ["node", "src/app.js"]