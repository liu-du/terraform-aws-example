init:
	terraform init

fmt:
	terraform fmt

plan: fmt
	terraform plan

apply: fmt
	terraform apply