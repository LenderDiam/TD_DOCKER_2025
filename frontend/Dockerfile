# Build stage
FROM node:22-alpine AS builder

# Build arguments
ARG VITE_API_URL=http://localhost:3000

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Set environment variable for Vite build
ENV VITE_API_URL=$VITE_API_URL

# Build the application
RUN npm run build

# Production stage
FROM nginx:stable-alpine

# Copy built assets from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Expose port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
