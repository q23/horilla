#!/bin/bash

# Überprüfe und setze Standardwerte für fehlende Umgebungsvariablen
if [ -z "$DATABASE_URL" ]; then
    echo "WARNING: DATABASE_URL is not set, using default: postgresql://postgres:postgres@db:5432/horilla"
    export DATABASE_URL="postgresql://postgres:postgres@db:5432/horilla"
fi

if [ -z "$DEBUG" ]; then
    echo "WARNING: DEBUG is not set, using default: True"
    export DEBUG="True"
fi

if [ -z "$ALLOWED_HOSTS" ]; then
    echo "WARNING: ALLOWED_HOSTS is not set, using default: *"
    export ALLOWED_HOSTS="*"
fi

if [ -z "$CSRF_TRUSTED_ORIGINS" ]; then
    echo "WARNING: CSRF_TRUSTED_ORIGINS is not set, using default: https://horilla.dev-ff.q23.de"
    export CSRF_TRUSTED_ORIGINS="https://horilla.dev-ff.q23.de"
fi

# Debug-Ausgabe der Umgebungsvariablen (ohne Passwörter)
echo "DEBUG is set to: $DEBUG"
echo "DATABASE_URL is set to: ${DATABASE_URL//:*@/:***@}"
echo "ALLOWED_HOSTS is set to: $ALLOWED_HOSTS"
echo "CSRF_TRUSTED_ORIGINS is set to: $CSRF_TRUSTED_ORIGINS"

echo "Waiting for database to be ready..."
# Versuche die Datenbankverbindung mit Django zu testen
python3 << END
import os
import sys
import django
from django.db import connections
from django.db.utils import OperationalError

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'horilla.settings')
django.setup()

try:
    connections['default'].ensure_connection()
    print("Database connection successful!")
except OperationalError as e:
    print(f"Database connection failed! Error: {e}")
    sys.exit(1)
END

if [ $? -ne 0 ]; then
    echo "Failed to connect to the database. Exiting..."
    exit 1
fi

echo "Running migrations..."
python3 manage.py makemigrations
python3 manage.py migrate
python3 manage.py collectstatic --noinput
python3 manage.py createhorillauser --first_name admin --last_name admin --username admin --password admin --email admin@example.com --phone 1234567890

echo "Starting Gunicorn..."
gunicorn --bind 0.0.0.0:8000 horilla.wsgi:application --log-level debug