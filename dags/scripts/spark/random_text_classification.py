# pyspark
import argparse

from pyspark.ml.feature import StopWordsRemover, Tokenizer
from pyspark.sql import SparkSession
from pyspark.sql.functions import array_contains, lit


def random_text_classifier(
        input_loc,
        output_loc,
        run_id
):
    df_raw = spark.read.option("header", True).csv(input_loc)

    # Tokenize text
    tokenizer = Tokenizer(inputCol="review_str", outputCol="review_token")
    df_tokens = tokenizer.transform(df_raw).select("cid", "review_token")


    # Remove stop words
    remover = StopWordsRemover(
        inputCol="review_token", outputCol="review_clean"
    )

    df_clean = remover.transform(df_tokens).select("cid", "review_clean")

    # function to check presence of good
    df_out = df_clean.select(
        'cid',
        array_contains(df_clean.review_clean, "good").alias("positive_review"),
    )

    final_df = df_out.withColumn("insert_date", lit(run_id))

    final_df.write.mode("overwrite").parquet(output_loc)

if __name__=="__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input", type=str, help="HDFS input", default="/movie"
    )
    parser.add_argument(
        "--output", type=str, help="HDFS output", default="/output"
    )
    parser.add_argument("--run-id", type=str, help="run id")
    args = parser.parse_args()
    spark = SparkSession.builder.appName(
        "Random Text Classifier"
    ).getOrCreate()
    random_text_classifier(
        input_loc=args.input, output_loc=args.output, run_id=args.run_id
    )
