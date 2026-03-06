/* @bruin
name: setup.create_datasets
type: bq.sql
connection: my-gcp-db

# ensure the landing datasets exist before any ingestion runs
@bruin */

create schema if not exists ingestion;
create schema if not exists staging;
create schema if not exists reports;
