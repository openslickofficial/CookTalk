FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY agent.py .
COPY recipes.json .
COPY generated_dishes.json .
COPY fallback_error_24k.wav .

# Expose port (if needed for health checks)
EXPOSE 8080

# Run the agent
CMD ["python", "agent.py", "start"]
