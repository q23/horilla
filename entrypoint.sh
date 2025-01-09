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

python3 manage.py collectstatic --noinput --no-input

# Erstelle den Admin-Benutzer
python3 manage.py shell << END
from django.contrib.auth.models import User
from employee.models import Employee
from base.models import Department, JobPosition, Company
import datetime

# Lösche bestehende Benutzer
User.objects.all().delete()

# Erstelle neuen Superuser
user = User.objects.create_superuser(
    username='$USER',
    email='$USER_EMAIL',
    password='$USER_PW'
)

# Hole das erste Unternehmen und die erste Abteilung
company = Company.objects.first()
department = Department.objects.first()
position = JobPosition.objects.first()

# Erstelle Employee-Profil
Employee.objects.create(
    employee_first_name='Aimo',
    employee_last_name='Hindriks',
    email='a.hindriks@q23.de',
    phone='1234567890',
    user=user,
    department=department,
    job_position=position,
    date_joining=datetime.date.today(),
    company=company
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