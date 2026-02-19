# Example: Periodic batch job — database backup
# Runs every 6 hours, fetches DB credentials from Vault

job "db-backup" {
  datacenters = ["dc1"]
  type        = "batch"

  # Run every 6 hours
  periodic {
    cron             = "0 */6 * * * *"
    prohibit_overlap = true
    time_zone        = "UTC"
  }

  group "backup" {
    count = 1

    restart {
      attempts = 2
      interval = "30m"
      delay    = "15s"
      mode     = "fail"
    }

    task "backup" {
      driver = "docker"

      vault {
        policies = ["db-backup-policy"]
      }

      config {
        image   = "alpine:3.18"
        command = "/bin/sh"
        args    = ["/local/backup.sh"]
      }

      # Inject Vault secrets as environment variables
      template {
        data = <<EOH
{{- with secret "secret/data/database" -}}
DB_HOST={{ .Data.data.host }}
DB_PORT={{ .Data.data.port }}
DB_NAME={{ .Data.data.dbname }}
DB_USER={{ .Data.data.username }}
DB_PASSWORD={{ .Data.data.password }}
{{- end }}
BACKUP_BUCKET=my-backup-bucket
BACKUP_PATH=/tmp/backups
EOH
        destination = "secrets/.env"
        env         = true
      }

      template {
        data = <<EOH
#!/bin/sh
set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_PATH}/db_backup_${TIMESTAMP}.sql"

echo "[$(date)] Starting database backup..."

mkdir -p "${BACKUP_PATH}"

# Example: pg_dump (replace with your actual DB tool)
# pg_dump -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" > "${BACKUP_FILE}"

echo "[$(date)] Backup completed: ${BACKUP_FILE}"
echo "[$(date)] Uploading to ${BACKUP_BUCKET}..."

# Example: aws s3 cp "${BACKUP_FILE}" "s3://${BACKUP_BUCKET}/"

echo "[$(date)] Done."
EOH
        destination = "local/backup.sh"
        perms       = "0755"
      }

      resources {
        cpu    = 200
        memory = 128
      }

      logs {
        max_files     = 10
        max_file_size = 10
      }
    }
  }
}
