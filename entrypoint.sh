#!/bin/bash

# Warten bis die Datenbank wirklich bereit ist
echo "Waiting for database to be ready..."
while ! python3 manage.py check --database default > /dev/null 2>&1; do
    echo "Database is unavailable - waiting..."
    sleep 2
done

echo "Database is ready!"

# Migrationen ausführen
echo "Running migrations..."
python3 manage.py makemigrations
python3 manage.py migrate

# Statische Dateien sammeln
echo "Collecting static files..."
python3 manage.py collectstatic --noinput

# Admin-Benutzer erstellen (nur wenn noch keiner existiert)
echo "Creating admin user if not exists..."
python3 manage.py createhorillauser --first_name admin --last_name admin --username admin --password admin --email admin@example.com --phone 1234567890 || true

# Server starten
echo "Starting server..."
gunicorn --bind 0.0.0.0:8000 horilla.wsgi:application
