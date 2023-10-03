FROM node:18.18.0-alpine

ENV HOST=0.0.0.0
ENV PORT=3000

USER node
WORKDIR /home/node

COPY --chown=node:node package*.json ./
RUN npm ci

COPY --chown=node:node . .
RUN npm run build 

EXPOSE 3000

CMD [ "node", "dist/main.js" ]
