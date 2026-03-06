/* @bruin
name: staging.trips
type: bq.sql
connection: my-gcp-db

depends:
  - ingestion.trips
  - ingestion.payment_lookup

materialization:
  type: table
  strategy: time_interval
  incremental_key: pickup_datetime
  time_granularity: timestamp

columns:
  - name: pickup_datetime
    type: timestamp
    description: "Trip start time"
    primary_key: true
    checks:
      - name: not_null
  - name: dropoff_datetime
    type: timestamp
    description: "Trip end time"
    primary_key: true
    checks:
      - name: not_null
  - name: pickup_location_id
    type: integer
    description: "Pickup location ID"
    primary_key: true
    checks:
      - name: not_null
  - name: dropoff_location_id
    type: integer
    description: "Dropoff location ID"
    checks:
      - name: not_null
  - name: fare_amount
    type: float
    description: "Base fare in USD"
    primary_key: true
    checks:
      - name: not_null
  - name: vendorid
    type: integer
    description: "Vendor ID (1=Creative Mobile Tech, 2=VeriFone)"
    checks:
      - name: not_null
  - name: payment_type_name
    type: string
    description: "Payment method name (enriched from lookup)"

custom_checks:
  - name: row_count_greater_than_zero
    query: |
      SELECT CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END
      FROM staging.trips
    value: 1
@bruin */

WITH filtered_trips AS (
    SELECT
        t.tpep_pickup_datetime,
        t.tpep_dropoff_datetime,
        t.pu_location_id,
        t.do_location_id,
        t.fare_amount,
        t.vendor_id,
        t.payment_type,
        p.payment_type_name
    FROM ingestion.trips t
    LEFT JOIN ingestion.payment_lookup p
        ON t.payment_type = p.payment_type_id
    WHERE t.tpep_pickup_datetime >= '{{ start_datetime }}'
      AND t.tpep_pickup_datetime < '{{ end_datetime }}'
),

deduped_trips AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY 
                tpep_pickup_datetime,
                tpep_dropoff_datetime,
                pu_location_id,
                do_location_id,
                fare_amount
            ORDER BY tpep_pickup_datetime
        ) AS rn
    FROM filtered_trips
)

SELECT
    tpep_pickup_datetime     AS pickup_datetime,
    tpep_dropoff_datetime    AS dropoff_datetime,
    pu_location_id           AS pickup_location_id,
    do_location_id           AS dropoff_location_id,
    fare_amount,
    vendor_id                AS vendorid,
    payment_type_name
FROM deduped_trips
WHERE rn = 1