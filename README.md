# fleet-product-docs

Building using local playbook, UI fetching, and link validation using log-level `info`:

`npx antora --fetch fleet-local-playbook.yml --log-level info`

Build content only after initial UI fetch:

`npx antora fleet-local-playbook.yml`

Running site using local playbook:

`npx http-server build/site -c-1`
