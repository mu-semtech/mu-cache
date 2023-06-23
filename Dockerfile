FROM madnificent/elixir-server:1.12.0

ENV PROXY_PORT 80
ADD . /app

RUN sh /setup.sh
