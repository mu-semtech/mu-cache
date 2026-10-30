FROM madnificent/elixir-server:1.14.0

ENV PROXY_PORT=80
ADD . /app


# Support running as an arbitrary UID in group 0 (OpenShift restricted SCC)
RUN chmod 755 /setup.sh /startup.sh \
 && chgrp -R 0 /root /app \
 && chmod -R g=u /root /app /etc/passwd
ENV HOME=/root

RUN sh /setup.sh
