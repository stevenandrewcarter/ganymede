.PHONY: build
build:
	@cd src/director && go build -o bin/director
	@cd src/generator && go build -o bin/generator

.PHONY: clean
clean:
	@rm src/director/bin/director
	@rm src/generator/bin/generator

.PHONY: apply
apply:
	@cd dist && terraform apply -auto-approve

.PHONY: destroy
destroy:
	@cd dist && terraform destroy -auto-approve

fmt:
	@cd dist && terraform fmt