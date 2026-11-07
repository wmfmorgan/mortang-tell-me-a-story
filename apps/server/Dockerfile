FROM dart:3.13.5 AS build
WORKDIR /src
COPY pubspec.yaml pubspec.lock ./
RUN dart pub get --enforce-lockfile
COPY . .
RUN dart build cli -t bin/main.dart -o /out

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
# Serverpod resolves config/ and migrations/ from the working directory.
WORKDIR /app
COPY --from=build /out/bundle/ /app/bundle/
COPY --from=build /src/config/ /app/config/
COPY --from=build /src/migrations/ /app/migrations/
EXPOSE 8080
ENTRYPOINT ["/app/bundle/bin/main", "--mode", "production", "--apply-migrations"]
