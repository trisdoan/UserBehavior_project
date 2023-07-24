get-data:
	rm -rf ./data && rm -rf data.zip* && wget https://start-data-engg.s3.amazonaws.com/data.zip && unzip -o data.zip && chmod -R u=rwx,g=rwx,o=rwx data

docker-up:
	docker compose --env-file env up airflow-init && docker compose --env-file env up --build -d

perms:
	mkdir -p logs plugins temp && sudo chmod -R u=rwx,g=rwx,o=rwx logs plugins temp

up: get-data perms docker-up


down:
	docker compose down
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