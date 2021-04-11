# FROM elixir-server
FROM madnificent/elixir-server:latest

ENV PROXY_PORT 80
ADD . /app

RUN sh /setup.sh
