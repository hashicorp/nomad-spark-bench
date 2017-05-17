#!/usr/bin/env bash
set -euo pipefail

sbt -batch package

mv target/scala-2.11/spark-load-test_2.11-0.1-SNAPSHOT.jar spark-load-test.jar
