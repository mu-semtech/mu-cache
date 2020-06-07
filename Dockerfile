# FROM elixir-server
FROM madnificent/elixir-server:latest

ENV MU_SPARQL_ENDPOINT 'http://database:8890/sparql'
ENV SOURCE_URI 'http://semantic.works/services/mu-cache/default'

ADD . /app

RUN sh /setup.sh
