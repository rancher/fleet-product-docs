ANTORA       = npx antora
ANTORA_OPTS  = --stacktrace --log-format=pretty --log-level=info

# Playbooks
FLEET_COMMUNITY_PLAYBOOK = fleet-community-local-playbook.yml
FLEET_PRODUCT_PLAYBOOK   = fleet-product-local-playbook.yml

FLEET_COMMUNITY_REMOTE_PLAYBOOK = playbook-remote-fleet-community.yml
FLEET_PRODUCT_REMOTE_PLAYBOOK   = playbook-remote-fleet-product.yml

# Output dirs for single-source repo
BUILD_DIR          = build
FLEET_COMMUNITY_OUT = $(BUILD_DIR)/site-community
FLEET_PRODUCT_OUT   = $(BUILD_DIR)/site

.PHONY: local local-fleet local-product remote remote-fleet remote-product clean environment preview-community preview-product

## ---- Local builds (no npm ci) -----------------------------------------

local: local-fleet local-product

local-fleet:
	mkdir -p tmp
	$(ANTORA) --version
	$(ANTORA) $(ANTORA_OPTS) \
		--to-dir $(FLEET_COMMUNITY_OUT) \
		$(FLEET_COMMUNITY_PLAYBOOK) \
		2>&1 | tee tmp/local-fleet-build.log 2>&1

local-product:
	mkdir -p tmp
	$(ANTORA) --version
	$(ANTORA) $(ANTORA_OPTS) \
		--to-dir $(FLEET_PRODUCT_OUT) \
		$(FLEET_PRODUCT_PLAYBOOK) \
		2>&1 | tee tmp/local-product-build.log 2>&1

## ---- Remote / CI builds (with npm ci) ---------------------------------

remote: remote-fleet remote-product

remote-fleet:
	mkdir -p tmp
	npm ci
	$(ANTORA) --version
	$(ANTORA) $(ANTORA_OPTS) \
		--to-dir $(FLEET_COMMUNITY_OUT) \
		$(FLEET_COMMUNITY_REMOTE_PLAYBOOK) \
		2>&1 | tee tmp/remote-fleet-build.log 2>&1

remote-product:
	mkdir -p tmp
	npm ci
	$(ANTORA) --version
	$(ANTORA) $(ANTORA_OPTS) \
		--to-dir $(FLEET_PRODUCT_OUT) \
		$(FLEET_PRODUCT_REMOTE_PLAYBOOK) \
		2>&1 | tee tmp/remote-product-build.log 2>&1

## ---- Utility targets --------------------------------------------------

clean:
	rm -rf build tmp

environment:
	npm ci

preview-community:
	npx http-server $(FLEET_COMMUNITY_OUT)/site -c-1

preview-product:
	npx http-server $(FLEET_PRODUCT_OUT)/site -c-1
