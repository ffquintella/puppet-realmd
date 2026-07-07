# *File originally created by PDQTest*
SHELL := /bin/bash

FORGE_API := https://forgeapi.puppet.com/v3/releases
MODULE    := ffquintella-realmd

all:
	cd .pdqtest && bundle exec pdqtest all

fast:
	cd .pdqtest && bundle exec pdqtest fast

acceptance:
	cd .pdqtest && bundle exec pdqtest acceptance

shell:
	cd .pdqtest && bundle exec pdqtest --keep-container acceptance

setup:
	cd .pdqtest && bundle exec pdqtest setup

shellnopuppet:
	cd .pdqtest && bundle exec pdqtest shell

logical:
	cd .pdqtest && bundle exec pdqtest logical

pdqtestbundle:
	# Install all gems into _normal world_ bundle so we can use all of em
	cd .pdqtest && pwd && bundle install

docs:
	cd .pdqtest && pwd && bundle exec "cd ..&& puppet strings generate --format markdown"


Gemfile.local:
	echo "[🐌] Creating symlink and running pdk bundle..."
	ln -s Gemfile.project Gemfile.local
	$(MAKE) pdkbundle

pdkbundle:
	pdk bundle install

# Run the unit test suite with regent
test:
	regent test --detail

# Build the module package (pkg/$(MODULE)-<version>.tar.gz) with regent
build:
	regent build

# Full release: bump patch -> build -> publish to Puppet Forge -> commit -> tag -> push.
# The Forge API key is prompted for at run time (never stored on disk or in the repo).
publish:
	@set -euo pipefail; \
	if [ -n "$$(git status --porcelain)" ]; then \
		echo "✗ Working tree is not clean. Commit or stash changes before publishing."; \
		git status --short; \
		exit 1; \
	fi; \
	CUR=$$(sed -n -E 's/.*"version"[[:space:]]*:[[:space:]]*"([0-9]+\.[0-9]+\.[0-9]+)".*/\1/p' metadata.json); \
	if [ -z "$$CUR" ]; then echo "✗ Could not read version from metadata.json"; exit 1; fi; \
	NEW=$$(echo "$$CUR" | awk -F. '{printf "%s.%s.%d", $$1, $$2, $$3+1}'); \
	echo "→ Bumping version $$CUR → $$NEW"; \
	sed -i '' -E "s/\"version\": \"$$CUR\"/\"version\": \"$$NEW\"/" metadata.json; \
	echo "→ Building package with regent"; \
	regent build; \
	TARBALL="pkg/$(MODULE)-$$NEW.tar.gz"; \
	if [ ! -f "$$TARBALL" ]; then echo "✗ Expected artifact not found: $$TARBALL"; git checkout -- metadata.json; exit 1; fi; \
	read -rsp 'Puppet Forge API key: ' FORGE_API_KEY; echo; \
	if [ -z "$$FORGE_API_KEY" ]; then echo "✗ No API key provided"; git checkout -- metadata.json; exit 1; fi; \
	echo "→ Publishing $$TARBALL to Puppet Forge"; \
	TMPJSON=$$(mktemp); RESP=$$(mktemp); \
	printf '{"file":"%s"}' "$$(base64 < "$$TARBALL" | tr -d '\n')" > "$$TMPJSON"; \
	CODE=$$(curl -sS -o "$$RESP" -w '%{http_code}' -X POST "$(FORGE_API)" \
		-H "Authorization: Bearer $$FORGE_API_KEY" \
		-H "Content-Type: application/json" \
		--data @"$$TMPJSON"); \
	rm -f "$$TMPJSON"; \
	if [ "$$CODE" != "201" ] && [ "$$CODE" != "200" ]; then \
		echo "✗ Forge publish failed (HTTP $$CODE):"; cat "$$RESP"; echo; rm -f "$$RESP"; \
		git checkout -- metadata.json; exit 1; \
	fi; \
	rm -f "$$RESP"; \
	echo "✓ Published $(MODULE) $$NEW to Puppet Forge (HTTP $$CODE)"; \
	echo "→ Committing, tagging and pushing"; \
	git add metadata.json; \
	git commit -m "Release $$NEW"; \
	git tag -a "v$$NEW" -m "Release $$NEW"; \
	git push origin HEAD; \
	git push origin "v$$NEW"; \
	echo "✓ Release $$NEW committed, tagged and pushed"

clean:
	rm -rf pkg
	rm -rf spec/fixtures/modules

.PHONY: all fast acceptance shell setup shellnopuppet logical pdqtestbundle docs pdkbundle test build publish clean
