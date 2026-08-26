# PSCorpus database.
#
# pgvector rather than plain postgres, and pinned to a digest-stable tag. The
# corpus exists to be trained on, which means it will be embedded, which means
# the vectors want to live beside the rows they came from rather than in a
# second store that can disagree with this one.
#
# Nothing is compiled here. Files copied into /docker-entrypoint-initdb.d run
# once, in filename order, on FIRST START ONLY - an existing volume is left
# alone. That is a footgun worth naming: editing 01-schema.sql and running
# `docker compose up` again changes nothing until the volume is dropped, and it
# looks exactly like a schema that failed to apply.
FROM pgvector/pgvector:pg16

LABEL org.opencontainers.image.title="pscorpus-db" \
      org.opencontainers.image.description="Postgres + pgvector holding the PSModuleGraph development corpus" \
      org.opencontainers.image.source="https://github.com/JerryBalmer1/PSModuleGraph"

# Order matters: tables, then the views that read them.
COPY init/01-schema.sql /docker-entrypoint-initdb.d/01-schema.sql
COPY init/02-views.sql  /docker-entrypoint-initdb.d/02-views.sql

# Reject a connection that is not from the compose network on a bad password,
# rather than trusting anything on the bridge. The default image is happy to
# trust local connections; this corpus contains a developer's own working
# record and should not be the thing that teaches a habit of trust-auth.
ENV POSTGRES_INITDB_ARGS="--auth-host=scram-sha-256 --auth-local=scram-sha-256"

HEALTHCHECK --interval=5s --timeout=3s --start-period=20s --retries=10 \
    CMD pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" || exit 1
