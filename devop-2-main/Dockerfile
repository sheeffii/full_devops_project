# Stage 1 - Build

FROM node:20-alpine AS builder

WORKDIR /app

COPY app/package*.json ./

RUN npm install

COPY app .


# Stage 2 - Production

FROM node:20-alpine

WORKDIR /app

COPY --from=builder /app .

EXPOSE 3000

CMD ["npm", "start"]