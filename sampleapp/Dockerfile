FROM python:3.11-slim

RUN pip install gunicorn~=20.1
COPY app.py .

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--backlog", "0", "app:application"]
