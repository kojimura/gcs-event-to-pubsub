FROM python:3.10-slim

WORKDIR /app
COPY . .

RUN pip install --no-cache-dir -r requirements.txt

ENV PORT 8080
CMD ["gunicorn", "-b", ":8080", "--timeout", "120", "main:app"]