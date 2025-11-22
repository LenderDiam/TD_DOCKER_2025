FROM node:22-alpine AS builder
WORKDIR /app
# RUN adduser -D -u 1000 appuser
COPY package.json package-lock.json* ./
RUN npm ci --production
COPY src ./src

FROM node:22-alpine
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/src ./src
COPY package.json ./package.json
RUN chown -R appuser:appgroup /app
USER appuser
EXPOSE 3000
ENV NODE_ENV=production
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/ready', res=>{if(res.statusCode!==200) process.exit(1)}) .on('error', ()=>process.exit(1))"

CMD ["node", "src/app.js"]