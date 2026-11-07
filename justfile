# Run from the repo root. `just` lists recipes.

gcp_project := "story-line-nra"
gcp_region := "us-central1"

# List recipes
default:
    @just --list

# Install pinned tools from mise.toml
setup:
    mise install

# flutter test in apps/tell_me_a_story
test:
    cd apps/tell_me_a_story && flutter test

# Live client tests against a running `just server` (start it first)
test-live:
    cd apps/tell_me_a_story && flutter test --tags live --run-skipped test/live

alias web := run

# Flutter web-server on 127.0.0.1:3000 (MAPBOX_ACCESS_TOKEN=pk... just run)
run:
    #!/usr/bin/env sh
    set -- flutter run -d web-server --web-hostname=127.0.0.1 --web-port=3000 \
        --dart-define=SERVER_URL=http://127.0.0.1:8080 \
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

# dart format check: app and server (the generated client package is not checked)
fmt-check:
    cd apps/tell_me_a_story && dart format --output=none --set-exit-if-changed .
    cd apps/server && dart format --output=none --set-exit-if-changed .

# flutter analyze in apps/tell_me_a_story: any error fails, and at most `ceiling` other issues
analyze ceiling="6":
    #!/usr/bin/env bash
    set -uo pipefail
    cd apps/tell_me_a_story
    out="$(mktemp)"
    trap 'rm -f "$out"' EXIT
    flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1 | tee "$out"
    rc=${PIPESTATUS[0]}
    if grep -qF 'error •' "$out"; then
        echo "analyze: errors found (exit $rc)" >&2
        exit 1
    fi
    if grep -qF 'No issues found!' "$out"; then
        count=0
    else
        count=$( { grep -vF '•' "$out" | grep -Eo '[0-9]+ issues? found\.' | tail -n 1 | grep -Eo '^[0-9]+'; } || true )
    fi
    case "{{ceiling}}" in
        ''|*[!0-9]*) echo "analyze: ceiling must be a whole number, got '{{ceiling}}'" >&2; exit 1 ;;
    esac
    if [ -z "$count" ]; then
        echo "analyze: no issue count in the output (exit $rc)" >&2
        exit 1
    fi
    echo "analyze: $count issues (ceiling {{ceiling}})"
    if [ "$count" -gt {{ceiling}} ]; then
        echo "analyze: $count issues is over the ceiling of {{ceiling}}" >&2
        exit 1
    fi
    if [ "$rc" -ne 0 ]; then
        echo "analyze: exit $rc with no error lines" >&2
        exit 1
    fi

# dart analyze in apps/server; any issue fails
server-analyze:
    cd apps/server && dart analyze --fatal-infos

# Every local gate: format, analyze, app tests, server analyze and server tests
check: fmt-check analyze test server-analyze server-test

# One-time GCP project + state bucket + Resend secrets (RESEND_API_KEY=… RESEND_FROM=… just gcp-bootstrap)
gcp-bootstrap:
    PROJECT_ID={{gcp_project}} infra/gcp/bootstrap.sh

# terraform init + apply for infra/gcp
gcp-infra:
    cd infra/gcp && terraform init && terraform apply

# Build the server image on Cloud Build and roll it out to Cloud Run
deploy-server:
    #!/usr/bin/env sh
    set -eu
    tag=$(git rev-parse --short HEAD)
    image={{gcp_region}}-docker.pkg.dev/{{gcp_project}}/story-line/server:$tag
    gcloud builds submit apps/server --tag "$image" --project {{gcp_project}}
    gcloud run deploy story-line-api --image "$image" --region {{gcp_region}} --project {{gcp_project}}

# Build Flutter web against the Cloud Run API and deploy to Firebase Hosting (MAPBOX_ACCESS_TOKEN optional)
deploy-web:
    #!/usr/bin/env sh
    set -eu
    num=$(gcloud projects describe {{gcp_project}} --format='value(projectNumber)')
    api="https://story-line-api-$num.{{gcp_region}}.run.app"
    origin="https://{{gcp_project}}.web.app"
    set -- flutter build web --release \
        --dart-define=SERVER_URL="$api" \
        --dart-define=INVITE_APP_ORIGIN="$origin"
    if [ -n "${MAPBOX_ACCESS_TOKEN:-}" ]; then
        set -- "$@" --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_ACCESS_TOKEN"
    fi
    (cd apps/tell_me_a_story && "$@")
    firebase deploy --only hosting --project {{gcp_project}}
