import os
from flask import Flask, jsonify

app = Flask(__name__)

@app.get('/')
def home():
    return jsonify(message='Automated release version 1 deployed successfully', version=os.getenv('APP_VERSION', 'local'))

@app.get('/health')
def health():
    return jsonify(status='ok', version=os.getenv('APP_VERSION', 'local'))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
