# Build e execução da app simulacoes_visuais com banco (TimescaleDB).
# Uso: docker compose up --build app

FROM elixir:1.15-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    nodejs \
    npm \
    git \
    inotify-tools \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

RUN mix local.hex --force && mix local.rebar --force

WORKDIR /app/apps/simulacoes_visuais
RUN mix deps.get
RUN mix compile --no-protocol-consolidation
RUN mix assets.deploy

EXPOSE 4000

# Migrations e servidor (DATABASE_URL vem do docker-compose)
CMD ["sh", "-c", "mix ecto.migrate && mix phx.server"]
