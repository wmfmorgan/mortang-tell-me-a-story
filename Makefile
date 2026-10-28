SHELL := /bin/sh

DEMO_API_URL := http://127.0.0.1:57321
DEMO_ANON_KEY := eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0

help:
	@echo "Run from the repo root."
	@echo ""
	@echo "  make help              this list (default)"
	@echo "  make supabase-start    supabase start"
	@echo "  make db-reset          supabase db reset (wipes the local database)"
	@echo "  make db-test           supabase test db"
	@echo "  make run               Flutter web-server on 127.0.0.1:3000"
	@echo "  make web               same as make run"
	@echo "  make test              flutter test in apps/tell_me_a_story"
	@echo "  make functions-serve   supabase functions serve --env-file supabase/.env.local"
	@echo ""
	@echo "Mapbox is optional. The app starts without a token."
	@echo "  MAPBOX_ACCESS_TOKEN=pk... make run"

.PHONY: help supabase-start db-reset db-test run web test functions-serve

supabase-start:
	supabase start

db-reset:
	@echo "supabase db reset wipes the local database."
	supabase db reset

db-test:
	supabase test db

test:
	cd apps/tell_me_a_story && flutter test

functions-serve:
	supabase functions serve --env-file supabase/.env.local

run web:
	@api_url='$(DEMO_API_URL)'; anon_key='$(DEMO_ANON_KEY)'; \
	err_file=$$(mktemp); \
	trap 'rm -f "$$err_file"' EXIT; \
	if out=$$(supabase status -o env 2>"$$err_file"); then \
		url=$$(printf '%s\n' "$$out" | awk '/^[[:space:]]*(export[[:space:]]+)?API_URL=/ { sub(/^[[:space:]]*(export[[:space:]]+)?API_URL=/, ""); print; exit }' | tr -d "'\""); \
		key=$$(printf '%s\n' "$$out" | awk '/^[[:space:]]*(export[[:space:]]+)?ANON_KEY=/ { sub(/^[[:space:]]*(export[[:space:]]+)?ANON_KEY=/, ""); print; exit }' | tr -d "'\""); \
		if [ -n "$$url" ] && [ -n "$$key" ]; then \
			api_url=$$url; anon_key=$$key; \
		else \
			echo "supabase status had no API_URL or ANON_KEY. Using the README local demo values." >&2; \
		fi; \
		unset out; \
	else \
		echo "supabase status failed. Using the README local demo values ($$api_url)." >&2; \
		echo "Start the stack with: make supabase-start" >&2; \
		cat "$$err_file" >&2; \
	fi; \
	set -- flutter run -d web-server --web-hostname=127.0.0.1 --web-port=3000 \
		--dart-define=SUPABASE_URL="$$api_url" \
		--dart-define=SUPABASE_ANON_KEY="$$anon_key" \
		--dart-define=INVITE_APP_ORIGIN=http://127.0.0.1:3000; \
	if [ -n "$$MAPBOX_ACCESS_TOKEN" ]; then \
		set -- "$$@" --dart-define=MAPBOX_ACCESS_TOKEN="$$MAPBOX_ACCESS_TOKEN"; \
	fi; \
	cd apps/tell_me_a_story && exec "$$@"
