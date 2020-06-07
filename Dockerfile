# FROM elixir-server
FROM madnificent/elixir-server:latest

ENV MU_SPARQL_ENDPOINT 'http://database:8890/sparql'

ADD . /app

RUN sh /setup.sh
