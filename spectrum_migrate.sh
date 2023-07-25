#!/bin/bash
rm -rf spectrum_query_to_run
mkdir spectrum_query_to_run

# todo loop through all queries in ./containers/spectrum_tables/create_staging_tables.sql

echo 'Generating query to be run from create_staging_tables.sql'
cat ./containers/spectrum_tables/create_staging_tables.sql | sed s/data-lake-bucket/$(terraform -chdir=./terraform output -raw bucket_name)/ > ./spectrum_query_to_run/create_staging_tables.sql

echo 'Running query ./spectrum_query_to_run/create_staging_tables.sql'
psql -f ./spectrum_query_to_run/create_staging_tables.sql postgres://$(terraform -chdir=./terraform output -raw redshift_user):$(terraform -chdir=./terraform output -raw redshift_password)@$(terraform -chdir=./terraform output -raw redshift_dns_name):5439/dev

rm -rf spectrum_query_to_run