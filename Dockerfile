FROM python:3.10-slim-bullseye

ENV PYTHONUNBUFFERED 1

# System-Abhängigkeiten installieren
RUN apt-get update && apt-get install -y libcairo2-dev gcc

WORKDIR /app/

# Projektdateien kopieren
COPY . .

# Entrypoint-Script ausführbar machen
RUN chmod +x /app/entrypoint.sh

# Python-Abhängigkeiten installieren
RUN pip install -r requirements.txt

EXPOSE 8000

# Entrypoint-Script als Startpunkt verwenden
CMD ["/app/entrypoint.sh"]
