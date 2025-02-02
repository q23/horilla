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
psql -h "db" -U "postgres" -d "postgres" -c "DROP DATABASE IF EXISTS horilla;"
psql -h "db" -U "postgres" -d "postgres" -c "CREATE DATABASE horilla;"

echo "Database is ready - running migrations"

# Führe Migrationen aus
python3 manage.py makemigrations
python3 manage.py migrate

# Lade Testdaten
echo "Loading test data..."
python3 manage.py loaddata base/fixtures/country.json
python3 manage.py loaddata base/fixtures/company.json
python3 manage.py loaddata base/fixtures/department.json
python3 manage.py loaddata base/fixtures/job_position.json
python3 manage.py loaddata base/fixtures/job_role.json
python3 manage.py loaddata base/fixtures/work_type.json
python3 manage.py loaddata base/fixtures/rotating_shift.json
python3 manage.py loaddata base/fixtures/rotating_shift_settings.json
python3 manage.py loaddata base/fixtures/shift.json
python3 manage.py loaddata base/fixtures/shift_settings.json
python3 manage.py loaddata employee/fixtures/employee.json
python3 manage.py loaddata employee/fixtures/employee_workinfo.json
python3 manage.py loaddata horilla_documents/fixtures/document_type.json
python3 manage.py loaddata leave/fixtures/leave_type.json
python3 manage.py loaddata recruitment/fixtures/candidate_source.json
python3 manage.py loaddata recruitment/fixtures/stage.json

# Sammle statische Dateien
echo "Collecting static files..."
python3 manage.py collectstatic --noinput --clear
python3 manage.py collectstatic --noinput

# Lösche bestehende Benutzer
echo "Setting up users..."
python3 manage.py shell << END
from django.contrib.auth.models import User
User.objects.all().delete()
END

# Erstelle Horilla-Benutzer
echo "Creating Horilla user..."
python3 manage.py createhorillauser \
    --username "$USER" \
    --password "$USER_PW" \
    --email "$USER_EMAIL" \
    --first_name "Aimo" \
    --last_name "Hindriks" \
    --phone "1234567890"

# Konfiguriere E-Mail-Server
echo "Configuring mail server..."
python3 manage.py shell << END
from base.models import DynamicEmailConfiguration
DynamicEmailConfiguration.objects.all().delete()
DynamicEmailConfiguration.objects.create(
    host="$EMAIL_HOST",
    port=$EMAIL_PORT,
    username="$EMAIL_HOST_USER",
    password="$EMAIL_PASSWORD",
    use_tls=$EMAIL_USE_TLS,
    from_email="$DEFAULT_FROM_EMAIL",
    fail_silently=False,
    is_active=True
)
END

# Konfiguriere Organisation
echo "Configuring organization..."
python3 manage.py shell << END
from base.models import CompanyConfiguration
CompanyConfiguration.objects.all().delete()
CompanyConfiguration.objects.create(
    company_name="q23.medien",
    corporate_address="Kaskelstraße 29",
    company_phone="+49 30 68231633",
    company_email="$DEFAULT_FROM_EMAIL",
    company_website="https://q23.de",
    company_city="Berlin",
    company_zip="10317",
    company_state="Berlin",
    company_country="Deutschland"
)
END

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