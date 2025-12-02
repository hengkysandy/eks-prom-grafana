from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, generate_latest, REGISTRY
import time

app = Flask(__name__)

# Prometheus metrics
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'HTTP request duration', ['method', 'endpoint'])

# In-memory orders
orders = [
    {'id': 1, 'product_id': 1, 'quantity': 2, 'status': 'completed'},
    {'id': 2, 'product_id': 2, 'quantity': 1, 'status': 'pending'}
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
    return response

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'python-orders'}), 200

@app.route('/metrics', methods=['GET'])
def metrics():
    return generate_latest(REGISTRY), 200, {'Content-Type': 'text/plain; charset=utf-8'}

@app.route('/orders', methods=['GET'])
def get_orders():
    return jsonify({'orders': orders, 'count': len(orders)}), 200

@app.route('/orders/<int:order_id>', methods=['GET'])
def get_order(order_id):
    order = next((o for o in orders if o['id'] == order_id), None)
    if not order:
        return jsonify({'error': 'Order not found'}), 404
    return jsonify(order), 200

@app.route('/orders', methods=['POST'])
def create_order():
    data = request.get_json()
    new_order = {
        'id': len(orders) + 1,
        'product_id': data.get('product_id'),
        'quantity': data.get('quantity', 1),
        'status': 'pending'
    }
    orders.append(new_order)
    return jsonify(new_order), 201

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
