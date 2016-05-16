FROM node:latest

ENV PORT 80
EXPOSE 80

COPY package.json /app/
WORKDIR /app

RUN npm set progress=false
RUN npm install

COPY index.js /app/

CMD ["npm", "run", "start"]