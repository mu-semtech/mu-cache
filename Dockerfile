FROM node:9.11.1

ENV PORT 80
EXPOSE 80

COPY package.json /app/
WORKDIR /app

RUN npm set progress=false
RUN npm install

COPY *.js /app/

CMD ["npm", "run", "start"]
