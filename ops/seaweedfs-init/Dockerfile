FROM python:3.11-slim-bookworm
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 PYTHONDONTWRITEBYTECODE=1
RUN pip install --no-cache-dir 'boto3>=1.34,<2'
COPY init_bucket.py /usr/local/bin/init_bucket.py
ENTRYPOINT ["python", "/usr/local/bin/init_bucket.py"]
