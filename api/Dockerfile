FROM node:22-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci --production
COPY src ./src

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