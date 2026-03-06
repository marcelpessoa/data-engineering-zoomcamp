"""@bruin
name: ingestion.trips
type: python
image: python:3.11
connection: my-gcp-db

depends:
  - setup.create_datasets

materialization:
  type: table
  strategy: append # create+replace

columns:
  - name: pickup_datetime
    type: timestamp
    description: "When the meter was engaged"
  - name: dropoff_datetime
    type: timestamp
    description: "When the meter is disengaged"
@bruin"""

import os
import json
import pandas as pd

def materialize():
    # parse the configured time window and taxi types variable
    start_date = pd.to_datetime(os.environ["BRUIN_START_DATE"])
    end_date = pd.to_datetime(os.environ["BRUIN_END_DATE"])
    taxi_types = json.loads(os.environ["BRUIN_VARS"]).get("taxi_types", ["yellow"])

    # build a list of year-month strings (e.g. 2022-03) covering the interval
    months = pd.date_range(start=start_date, end=end_date, freq="MS").strftime("%Y-%m").tolist()

    dfs = []
    for taxi in taxi_types:
        for m in months:
            url = f"https://d37ci6vzurychx.cloudfront.net/trip-data/{taxi}_tripdata_{m}.parquet"
            # pandas can read directly from HTTP(s) parquet
            try:
                df = pd.read_parquet(url)
            except Exception as e:
                # if the file doesn't exist for that month/taxi type, skip it
                # (TLC sometimes omits months at the end of their dataset)
                continue
            dfs.append(df)

    if len(dfs) == 0:
        # no data in range; return empty frame with no columns
        return pd.DataFrame()

    final_dataframe = pd.concat(dfs, ignore_index=True)
    return final_dataframe