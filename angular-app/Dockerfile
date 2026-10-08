# Stage 1: build Angular static assets
FROM node:20-alpine AS build

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --prefer-offline

COPY . .
RUN npm run build

# Stage 2: serve with Nginx (only static files in the final image)
FROM nginx:1.27-alpine

COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY --from=build /app/dist/olympic-games-starter/browser /app

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
