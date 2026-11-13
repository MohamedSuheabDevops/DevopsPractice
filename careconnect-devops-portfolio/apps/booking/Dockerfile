FROM node:22-alpine
LABEL org.opencontainers.image.title="careconnect-booking"
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev                    # dependencies layer (cached unless package.json changes)
COPY server.js .
USER node
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost:8080/health || exit 1
CMD ["node", "server.js"]
