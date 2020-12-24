
up:
	docker-compose up -d

down:
	docker-compose down -v

ssh:
	docker exec -it internal-utils-postgres /bin/bash

install:
	docker exec internal-utils-postgres /sql-bin/install.sh

meta:
	@cd packages/db_meta && lql plan && lql package 
	@cd packages/db_meta_modules && lql plan && lql package 
	$(MAKE) install
