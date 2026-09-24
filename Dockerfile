FROM madnificent/elixir-server:1.14.0

ENV PROXY_PORT 80
ADD . /app

RUN sh /setup.sh
