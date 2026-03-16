FROM python:3.10-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=utf-8

WORKDIR /app

# opencv-python runtime deps on Debian slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libgl1 \
        libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements_api.txt /app/requirements_api.txt
COPY requirements.txt /app/requirements.txt

# NOTE: On Linux, `pip install torch` may pull CUDA wheels (huge) by default.
# For a CPU-only server/container, force CPU wheels to keep the image smaller/faster to build.
RUN pip install --no-cache-dir -U pip \
    && pip install --no-cache-dir --index-url https://download.pytorch.org/whl/cpu torch==2.10.0 torchvision==0.25.0 \
    && pip install --no-cache-dir -r /app/requirements_api.txt --root-user-action=ignore

COPY . /app

# Default: single worker (OCR is CPU/memory heavy)
ENV MAX_CONCURRENT_JOBS=1

EXPOSE 8000

CMD ["python", "-m", "uvicorn", "api:app", "--host", "0.0.0.0", "--port", "8000"]
