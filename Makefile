# Convenience targets (Linux/macOS/WSL/Git Bash). Windows PowerShell users can run the python commands directly.
PY ?= python

setup:        ## install Python dependencies
	$(PY) -m pip install -r requirements.txt

db-up:        ## start PostgreSQL in Docker (needs .env)
	docker compose up -d

generate:     ## create the raw CSV files (add SCALE=0.1 for a fast demo)
	$(PY) scripts/generate_data.py --scale $(or $(SCALE),1.0)

build:        ## load + clean + model + check + index (data must exist)
	$(PY) scripts/run_pipeline.py

all:          ## generate data then build everything
	$(PY) scripts/run_pipeline.py --generate --scale $(or $(SCALE),1.0)

queries:      ## run all 81 analytical queries
	$(PY) scripts/run_queries.py

docs:         ## regenerate generated docs and diagrams
	$(PY) scripts/generate_data_dictionary.py
	$(PY) scripts/generate_model_doc.py
	$(PY) scripts/generate_diagrams.py
	$(PY) scripts/kpi_reference.py

.PHONY: setup db-up generate build all queries docs
