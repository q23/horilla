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

# Bereinige die Datenbank und erstelle den Superuser mit Employee-Profil
python3 manage.py shell << END
from django.contrib.auth.models import User
from auditlog.models import LogEntry
from django.db import connection
from base.models import Company, Department, JobPosition
from employee.models import Employee
import datetime

# Lösche alle Audit-Logs
LogEntry.objects.all().delete()

# Lösche alle bestehenden Benutzer
User.objects.all().delete()

# Setze die Sequenz für die User-ID zurück
with connection.cursor() as cursor:
    cursor.execute("ALTER SEQUENCE auth_user_id_seq RESTART WITH 1")

# Erstelle den neuen Superuser
if not User.objects.filter(username='$USER').exists():
    user = User.objects.create_superuser('$USER', '$USER_EMAIL', '$USER_PW')
    
    # Erstelle Grunddaten
    company = Company.objects.create(
        company_name='Q23',
        address='Company Address',
        country='Germany',
        email='$USER_EMAIL',
        phone='1234567890',
        website='https://q23.de'
    )
    
    dept = Department.objects.create(
        department='IT',
        company=company
    )
    
    position = JobPosition.objects.create(
        job_position='Admin',
        department=dept
    )
    
    # Erstelle Employee-Profil
    if not Employee.objects.filter(user=user).exists():
        Employee.objects.create(
            employee_first_name='Aimo',
            employee_last_name='Hindriks',
            email='a.hindriks@q23.de',
            phone='1234567890',
            user=user,
            department=dept,
            job_position=position,
            employee_profile_image='',
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