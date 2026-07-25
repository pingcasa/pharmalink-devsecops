
# Étape 1 : Build (installation des dépendances)
FROM python:3.12-slim AS builder

# Répertoire de travail
WORKDIR /app

# Installer les dépendances système nécessaires
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc \
    && rm -rf /var/lib/apt/lists/*

# Copier les requirements et installer
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Étape 2 : Runtime (image finale plus légère)
FROM python:3.12-slim

WORKDIR /app

# Créer un utilisateur non-root
RUN useradd -m appuser
USER appuser

# Copier les dépendances et le code
COPY --from=builder /usr/local /usr/local
COPY . .

# Commande de démarrage
CMD ["python", "app.py"]
