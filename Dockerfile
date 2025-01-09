FROM python:3.10-slim-bullseye

ENV PYTHONUNBUFFERED 1
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# System-Abhängigkeiten installieren
RUN apt-get update && apt-get install -y \
    libcairo2-dev \
    gcc \
    postgresql-client

# Erstelle nicht-root Benutzer
RUN useradd -m -s /bin/bash app && \
    mkdir -p /app /opt/venv && \
    chown -R app:app /app /opt/venv

# Wechsle zum nicht-root Benutzer
USER app

# Erstelle und aktiviere virtuelles Environment
RUN python -m venv $VIRTUAL_ENV

WORKDIR /app/

# Kopiere requirements.txt zuerst für besseres Caching
COPY --chown=app:app requirements.txt .

# Installiere Python-Abhängigkeiten im virtuellen Environment
RUN pip install --no-cache-dir -r requirements.txt

# Kopiere den Rest der Anwendung
COPY --chown=app:app . .

# Mache entrypoint.sh ausführbar
RUN chmod +x /app/entrypoint.sh

EXPOSE 8000

# Entrypoint-Script als Startpunkt verwenden
CMD ["/app/entrypoint.sh"]
