#!/bin/bash

# Aktiviere virtuelles Environment
source /opt/venv/bin/activate

# Prüfe ob die benötigten Umgebungsvariablen gesetzt sind
if [ -z "$USER" ] || [ -z "$USER_EMAIL" ] || [ -z "$USER_PW" ]; then
    echo "ERROR: Required environment variables USER, USER_EMAIL, or USER_PW are not set"
    exit 1
fi

echo "Waiting for database to be ready..."

# Warte auf PostgreSQL
export PGPASSWORD=postgres
until psql -h "db" -U "postgres" -d "postgres" -c '\l' 2>/dev/null; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 1
done

echo "PostgreSQL is up - checking database"

# Prüfe, ob die Datenbank existiert, wenn nicht, erstelle sie
psql -h "db" -U "postgres" -d "postgres" -c "SELECT 1 FROM pg_database WHERE datname = 'horilla'" | grep -q 1 || psql -h "db" -U "postgres" -d "postgres" -c "CREATE DATABASE horilla"

echo "Database is ready - running migrations"

# Führe Migrationen aus
python3 manage.py makemigrations
python3 manage.py migrate
python3 manage.py collectstatic --noinput --no-input

# Erstelle Superuser nur wenn er noch nicht existiert
echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.filter(username='$USER').exists() or User.objects.create_superuser('$USER', '$USER_EMAIL', '$USER_PW')" | python3 manage.py shell

echo "Starting Gunicorn..."
exec gunicorn \
    --bind 0.0.0.0:8000 \
    --workers 2 \
    --threads 4 \
    --timeout 120 \
    --log-level debug \
    --access-logfile - \
    --error-logfile - \
    horilla.wsgi:application