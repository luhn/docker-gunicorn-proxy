FROM python:3.8-slim

RUN pip install gunicorn==20.0.4
COPY app.py .

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "app:application"]
