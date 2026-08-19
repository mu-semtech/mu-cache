FROM madnificent/elixir-server:1.13.0

ENV PROXY_PORT=80
ADD . /app

RUN sh /setup.sh
