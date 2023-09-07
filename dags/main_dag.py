import json
from datetime import datetime, timedelta

##Airflow import###
from airflow import DAG
from airflow.contrib.operators.emr_add_steps_operator import (
    EmrAddStepsOperator,
)
from airflow.contrib.sensors.emr_step_sensor import EmrStepSensor
from airflow.models import Variable
from airflow.operators.dummy_operator import DummyOperator
from airflow.operators.postgres_operator import PostgresOperator
from airflow.operators.python import PythonOperator

##custom util##
from utils.utils import _local_to_s3, run_redshift_external_query


#Config
BUCKET_NAME = Variable.get("BUCKET")
EMR_ID = Variable.get("EMR_ID")
EMR_STEPS = {}
with open("./dags/scripts/emr/clean_movie_review.json") as file:
    EMR_STEPS = json.load(file)

#DAG Definition
default_args = {
    "owner": "airflow",
    "depends_on_past": True,
    "wait_for_downstream": True,
    "start_date": datetime(2022, 7, 25),
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=1),
}

dag = DAG(
    "main_dag",
    default_args=default_args,
    schedule_interval="0 0 * * *",
    max_active_runs = 1
)

extract_user_purchase_data = PostgresOperator(
    dag=dag,
    task_id="extract_user_purchase_data",
    sql="./scripts/sql/unload_user_purchase.sql",
    postgres_conn_id="postgres_default",
    params={"user_purchase": "/temp/user_purchase.csv"},
    depends_on_past=True,
    wait_for_downstream=True,
)

user_purchase_to_stage_data_lake = PythonOperator(
    dag=dag,
    task_id="user_purchase_to_stage_data_lake",
    python_callable=_local_to_s3,
    op_kwargs={
        "file_name": "/opt/airflow/temp/user_purchase.csv",
        "key": "stage/user_purchase/{{ ds }}/user_purchase.csv",
        "bucket_name": BUCKET_NAME,
        "remove_local": "true",
    },
)
    
user_purchase_stage_data_lake_to_stage_tbl = PythonOperator(
    dag=dag,
    task_id="user_purchase_stage_data_lake_to_stage_tbl",
    python_callable=run_redshift_external_query,
    op_kwargs={
        "qry": "alter tabke spectrum.user_purchase_staging add \
            if not exists partition(insert_date='{{ ds }}') \
                location 's3://'"
        + BUCKET_NAME
        + "/stage/user_purchase/{{ ds }}",
    },
    
)

movie_review_to_data_lake = PythonOperator(
    dag=dag,
    task_id="movie_review_to_data_lake",
    python_callable=_local_to_s3,
    op_kwargs={
        "file_name": "/opt/airflow/data/movie_review.csv",
        "key": "raw/movie_review/{{ ds }}/movie.csv",
        "bucket_name": BUCKET_NAME,
    }
)

spark_script_to_s3 = PythonOperator(
    dag=dag,
    task_id="spark_script_to_s3",
    python_callable=_local_to_s3,
    op_kwargs={
        "file_name": "./dags/scripts/spark/random_text_classification.py",
        "key": "scripts/random_text_classification.py",
        "bucket_name": BUCKET_NAME,
    }
)

start_emr_movie_classification_script = EmrAddStepsOperator(
    dag=dag,
    task_id="start_emr_movie_classification_script",
    job_flow_id=EMR_ID,
    aws_conn_id="aws_default",
    steps=EMR_STEPS,
    params= {
        "BUCKET_NAME": BUCKET_NAME,
        "raw_movie_review": "raw/movie_review",
        "text_classifier_script": "scripts/random_text_classifier.py",
        "stage_movie_review": "stage/movie_review",
    }
)
last_step = len(EMR_STEPS) - 1

wait_for_movie_classification_transform =  EmrStepSensor(
    dag=dag,
    task_id="wait_for_movie_classification_transform",
    job_flow_id=EMR_ID,
    step_id='{{ task_instance.xcom_pull\
        ("start_emr_movie_classification_script", key="return_value")['
        + str(last_step)
        + "]}}",
        depends_on_past=True,
)
    
generate_user_behavior_metric = PostgresOperator(
    dag=dag,
    task_id="generate_user_behavior_metric",
    sql="./scripts/sql/unload_user_purchase.sql",
    postgres_conn_id="redshift",
)

end_of_pipeline = DummyOperator(task_id = "end_of_pipeline", dag=dag)

(
    extract_user_purchase_data
    >> user_purchase_to_stage_data_lake
    >> user_purchase_stage_data_lake_to_stage_tbl
)

(
    [
        movie_review_to_data_lake,
        spark_script_to_s3,
    ]
    >> start_emr_movie_classification_script
    >> wait_for_movie_classification_transform
)

(
    [
        user_purchase_stage_data_lake_to_stage_tbl,
        wait_for_movie_classification_transform
    ]
    >> generate_user_behavior_metric
    >> end_of_pipeline
)
