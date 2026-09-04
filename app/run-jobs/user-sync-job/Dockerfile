# ビルドコンテキストはリポジトリルート。共有ライブラリ app/common を同梱するため。
#   docker build -f app/run-jobs/user-sync-job/Dockerfile -t <image> .
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

COPY app/run-jobs/user-sync-job/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY app/common ./common
COPY app/run-jobs/user-sync-job/main.py ./main.py
COPY app/run-jobs/user-sync-job/schema.json ./schema.json

# Cloud Run Jobs は非rootで動かす
RUN useradd --create-home --uid 1000 appuser
USER appuser

ENTRYPOINT ["python", "main.py"]
