#!/usr/bin/env bash
set -euo pipefail

[ -n "$SPARK_HOME" ] || {
  echo "The SPARK_HOME to include in the image must be specified"
  exit 2
} >&2

rm -rf docker-image-context
mkdir docker-image-context

cp Dockerfile docker-image-context/
cp -R "$SPARK_HOME" docker-image-context/spark
cp spark-load-test.jar docker-image-context/

docker build --tag spark:load-test docker-image-context

rm -rf docker-image-context
