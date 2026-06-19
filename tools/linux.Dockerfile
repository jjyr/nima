FROM nimlang/nim:2.2.10

ENV PATH="/opt/nim/bin:${PATH}"

RUN apt-get update \
  && apt-get install -y --no-install-recommends gcc g++ ca-certificates file libsdl3-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /deps
COPY nima.nimble /deps/nima.nimble
RUN nimble install -dy

WORKDIR /workspace
COPY . /workspace
