#!/bin/sh
set -e

echo "Running Flyway baseline..."
flyway baseline

echo "Running Flyway migrations..."
flyway migrate
