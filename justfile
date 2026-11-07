# Run from the repo root. `just` lists recipes.

demo_api_url := "http://127.0.0.1:57321"
demo_anon_key := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"

# List recipes
default:
    @just --list

# Install pinned tools from mise.toml
setup:
    mise install

# supabase start
supabase-start:
    supabase start

# supabase db reset (wipes the local database)
db-reset:
    @echo "supabase db reset wipes the local database."
    supabase db reset

# supabase test db
db-test:
    supabase test db

# flutter test in apps/tell_me_a_story
test:
    cd apps/tell_me_a_story && flutter test

# Live client tests against a running `just server` (start it first)
test-live:
    cd apps/tell_me_a_story && flutter test --tags live --run-skipped test/live

# supabase functions serve --env-file supabase/.env.local
functions-serve:
    supabase functions serve --env-file supabase/.env.local

alias web := run

# Flutter web-server on 127.0.0.1:3000 (MAPBOX_ACCESS_TOKEN=pk... just run)
run:
    #!/usr/bin/env sh
    api_url='{{demo_api_url}}'
    anon_key='{{demo_anon_key}}'
    err_file=$(mktemp)
    trap 'rm -f "$err_file"' EXIT
    if out=$(supabase status -o env 2>"$err_file"); then
        url=$(printf '%s\n' "$out" | awk '/^[[:space:]]*(export[[:space:]]+)?API_URL=/ { sub(/^[[:space:]]*(export[[:space:]]+)?API_URL=/, ""); print; exit }' | tr -d "'\"")
        key=$(printf '%s\n' "$out" | awk '/^[[:space:]]*(export[[:space:]]+)?ANON_KEY=/ { sub(/^[[:space:]]*(export[[:space:]]+)?ANON_KEY=/, ""); print; exit }' | tr -d "'\"")
        if [ -n "$url" ] && [ -n "$key" ]; then
            api_url=$url
            anon_key=$key
        else
            echo "supabase status had no API_URL or ANON_KEY. Using the README local demo values." >&2
        fi
        unset out
    else
        echo "supabase status failed. Using the README local demo values ($api_url)." >&2
        echo "Start the stack with: just supabase-start" >&2
        cat "$err_file" >&2
    fi
    set -- flutter run -d web-server --web-hostname=127.0.0.1 --web-port=3000 \
        --dart-define=SUPABASE_URL="$api_url" \
        --dart-define=SUPABASE_ANON_KEY="$anon_key" \
        --dart-define=INVITE_APP_ORIGIN=http://127.0.0.1:3000
    if [ -n "$MAPBOX_ACCESS_TOKEN" ]; then
        set -- "$@" --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_ACCESS_TOKEN"
    fi
    cd apps/tell_me_a_story && exec "$@"

# Install serverpod_cli 4.1.1 and fetch server/client packages; create local passwords if missing
server-setup:
    dart pub global activate serverpod_cli 4.1.1
    cd apps/server && dart pub get
    cd packages/tell_me_a_story_client && dart pub get
    just server-passwords

# Write apps/server/config/passwords.yaml with random development/test secrets (no-op if it exists)
server-passwords:
    #!/usr/bin/env sh
    set -eu
    umask 077
    file=apps/server/config/passwords.yaml
    if [ -f "$file" ]; then echo "$file exists; leaving it alone."; exit 0; fi
    tmp="$file.tmp"
    trap 'rm -f "$tmp"' EXIT
    : > "$tmp"
    for mode in development test; do
        database=$(openssl rand -hex 16)
        service_secret=$(openssl rand -hex 32)
        email_pepper=$(openssl rand -hex 32)
        jwt_key=$(openssl rand -hex 64)
        refresh_pepper=$(openssl rand -hex 32)
        {
            echo "$mode:"
            echo "  database: \"$database\""
            echo "  serviceSecret: \"$service_secret\""
            echo "  emailSecretHashPepper: \"$email_pepper\""
            echo "  jwtHmacSha512PrivateKey: \"$jwt_key\""
            echo "  jwtRefreshTokenHashPepper: \"$refresh_pepper\""
        } >> "$tmp"
    done
    mv "$tmp" "$file"
    echo "Wrote $file"

# Regenerate server protocol, client package and test tools after model/endpoint changes
server-generate:
    cd apps/server && dart pub global run serverpod_cli generate

# Create a migration from model changes: just server-migration <tag>
server-migration tag:
    cd apps/server && dart pub global run serverpod_cli create-migration --tag {{tag}}

# Run the API server on :8080 (embedded Postgres, migrations applied, login code 111111)
server:
    cd apps/server && dart run bin/main.dart --apply-migrations

# Backend integration tests (embedded Postgres)
server-test:
    cd apps/server && dart test
