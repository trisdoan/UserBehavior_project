get-data:
	rm -rf ./data && rm -rf data.zip* && wget https://start-data-engg.s3.amazonaws.com/data.zip && unzip -o data.zip && chmod -R u=rwx,g=rwx,o=rwx data

docker-up:
	docker compose --env-file env up airflow-init && docker compose --env-file env up --build -d

perms:
	mkdir -p logs plugins temp && sudo chmod -R u=rwx,g=rwx,o=rwx logs plugins temp migrations

up: get-data perms docker-up


down:
	docker compose down

sh:
	docker exec -ti webserver bash
####################################################################################################################
# Set up cloud infrastructure
tf-init:
	terraform -chdir=./terraform init

infra-up:
	terraform -chdir=./terraform apply

infra-down:
	terraform -chdir=./terraform destroy

infra-config:
	terraform -chdir=./terraform output
####################################################################################################################
# Port forwarding to local machine
cloud-airflow:
	terraform -chdir=./terraform output -raw private_key > private_key.pem && chmod 600 private_key.pem && ssh -o "IdentitiesOnly yes" -i private_key.pem ubuntu@$$(terraform -chdir=./terraform output -raw ec2_public_dns) -N -f -L 8080:$$(terraform -chdir=./terraform output -raw ec2_public_dns):8080 && open http://localhost:8080 && rm private_key.pem

cloud-metabase:
	terraform -chdir=./terraform output -raw private_key > private_key.pem && chmod 600 private_key.pem && ssh -o "IdentitiesOnly yes" -i private_key.pem ubuntu@$$(terraform -chdir=./terraform output -raw ec2_public_dns) -N -f -L 3000:$$(terraform -chdir=./terraform output -raw ec2_public_dns):3000 && open http://localhost:3000 && rm private_key.pem


# Create tables in Warehouse
spectrum-migration:
	./spectrum_migrate.sh

db-migration:
	@read -p "Enter migration name:" migration_name; docker exec webserver yoyo new ./migrations -m "$$migration_name"

redshift-migration:
	docker exec -ti webserver yoyo apply --no-config-file --database redshift://$$(terraform -chdir=./terraform output -raw redshift_user):$$(terraform -chdir=./terraform output -raw redshift_password)@$$(terraform -chdir=./terraform output -raw redshift_dns_name):5439/dev ./migrations

redshift-rollback:
	docker exec -ti webserver yoyo rollback --no-config-file --database redshift://$$(terraform -chdir=./terraform output -raw redshift_user):$$(terraform -chdir=./terraform output -raw redshift_password)@$$(terraform -chdir=./terraform output -raw redshift_dns_name):5439/dev ./migrations

warehouse-data-migration: spectrum-migration redshift-migration

####################################################################################################################
# Helpers

ssh-ec2:
	terraform -chdir=./terraform output -raw private_key > private_key.pem && chmod 600 private_key.pem && ssh -o StrictHostKeyChecking=no -o IdentitiesOnly=yes -i private_key.pem ubuntu@$$(terraform -chdir=./terraform output -raw ec2_public_dns) && rm private_key.pem