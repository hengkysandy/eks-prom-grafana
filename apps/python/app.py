from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, generate_latest, REGISTRY
import time
import logging
import json
import sys

app = Flask(__name__)

# Configure JSON logging
class JsonFormatter(logging.Formatter):
    def format(self, record):
        log_data = {
            'timestamp': self.formatTime(record),
            'level': record.levelname.lower(),
            'message': record.getMessage(),
            'service': 'python-orders',
            'method': getattr(record, 'method', None),
            'path': getattr(record, 'path', None),
            'status_code': getattr(record, 'status_code', None),
        }
        return json.dumps({k: v for k, v in log_data.items() if v is not None})

handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JsonFormatter())
logger = logging.getLogger('python-orders')
logger.addHandler(handler)
logger.setLevel(logging.INFO)

# Prometheus metrics
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'HTTP request duration', ['method', 'endpoint'])
ERROR_COUNT = Counter('http_errors_total', 'Total HTTP errors', ['method', 'endpoint', 'status', 'error_type'])

# In-memory orders
orders = [
    {'id': 1, 'product_id': 1, 'product_name': 'Laptop', 'quantity': 2, 'price': 999.99, 'status': 'completed'},
    {'id': 2, 'product_id': 2, 'product_name': 'Mouse', 'quantity': 1, 'price': 29.99, 'status': 'pending'}
]

@app.before_request
def before_request():
    request.start_time = time.time()

@app.after_request
def after_request(response):
    if hasattr(request, 'start_time'):
        duration = time.time() - request.start_time
        REQUEST_DURATION.labels(request.method, request.path).observe(duration)
        REQUEST_COUNT.labels(request.method, request.path, response.status_code).inc()
        
        # Log request
        log_record = logger.makeRecord(
            logger.name, logging.INFO, '', 0, 'HTTP Request', (), None
        )
        log_record.method = request.method
        log_record.path = request.path
        log_record.status_code = response.status_code
        logger.handle(log_record)
        
        if response.status_code >= 400:
            ERROR_COUNT.labels(request.method, request.path, response.status_code, 'http_error').inc()
    
    return response

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'python-orders'}), 200

@app.route('/metrics', methods=['GET'])
def metrics():
    return generate_latest(REGISTRY), 200, {'Content-Type': 'text/plain; charset=utf-8'}

@app.route('/orders', methods=['GET'])
def get_orders():
    logger.info(f'Fetching all orders, count: {len(orders)}')
    return jsonify({'orders': orders, 'count': len(orders)}), 200

@app.route('/orders/<int:order_id>', methods=['GET'])
def get_order(order_id):
    order = next((o for o in orders if o['id'] == order_id), None)
    if not order:
        logger.warning(f'Order not found: {order_id}')
        return jsonify({'error': 'Order not found'}), 404
    logger.info(f'Order fetched: {order_id}')
    return jsonify(order), 200

@app.route('/orders', methods=['POST'])
def create_order():
    data = request.get_json()
    new_order = {
        'id': len(orders) + 1,
        'product_id': data.get('product_id'),
        'product_name': data.get('product_name', 'Unknown'),
        'quantity': data.get('quantity', 1),
        'price': data.get('price', 0),
        'status': 'pending'
    }
    orders.append(new_order)
    logger.info(f'Order created: {new_order["id"]}, product: {new_order["product_name"]}')
    return jsonify(new_order), 201

# Error test endpoints
@app.route('/error/500', methods=['GET'])
def error_500():
    logger.error('Simulated 500 error', extra={'endpoint': '/error/500'})
    ERROR_COUNT.labels(request.method, request.path, 500, 'internal_server_error').inc()
    return jsonify({'error': 'Internal Server Error', 'message': 'Simulated error'}), 500

@app.route('/error/db', methods=['GET'])
def error_db():
    logger.error('Simulated database error', extra={'endpoint': '/error/db', 'error_type': 'connection_failed'})
    ERROR_COUNT.labels(request.method, request.path, 503, 'database_error').inc()
    return jsonify({'error': 'Service Unavailable', 'message': 'Database connection failed'}), 503

@app.route('/error/timeout', methods=['GET'])
def error_timeout():
    logger.warning('Simulated timeout', extra={'endpoint': '/error/timeout'})
    time.sleep(5)
    return jsonify({'error': 'Gateway Timeout', 'message': 'Request took too long'}), 504

if __name__ == '__main__':
    logger.info('Starting Python Orders Service on port 5000')
    app.run(host='0.0.0.0', port=5000)
