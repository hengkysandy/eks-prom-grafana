// Initialize tracing first
require('./tracing');

const express = require('express');
const promClient = require('prom-client');
const winston = require('winston');
const LokiTransport = require('winston-loki');

const app = express();
const PORT = process.env.PORT || 3000;

// Winston logger with Loki transport
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  defaultMeta: { service: 'nodejs-catalog' },
  transports: [
    new winston.transports.Console(),
    new LokiTransport({
      host: process.env.LOKI_HOST || 'http://loki.monitoring.svc.cluster.local:3100',
      labels: { app: 'nodejs-catalog', namespace: 'ecommerce-poc' },
      json: true,
      format: winston.format.json(),
      replaceTimestamp: true,
      onConnectionError: (err) => console.error('Loki connection error:', err)
    })
  ],
});

// Prometheus metrics
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

const httpRequestTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

const httpErrorsTotal = new promClient.Counter({
  name: 'http_errors_total',
  help: 'Total number of HTTP errors',
  labelNames: ['method', 'route', 'status_code', 'error_type'],
  registers: [register]
});

// In-memory product catalog
const products = [
  { id: 1, name: 'Laptop', price: 999.99, stock: 10 },
  { id: 2, name: 'Mouse', price: 29.99, stock: 50 },
  { id: 3, name: 'Keyboard', price: 79.99, stock: 30 }
];

app.use(express.json());

// Middleware to track metrics and log requests
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    httpRequestDuration.labels(req.method, req.path, res.statusCode).observe(duration);
    httpRequestTotal.labels(req.method, req.path, res.statusCode).inc();
    
    logger.info('HTTP Request', {
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      duration: duration,
      userAgent: req.get('user-agent')
    });
    
    if (res.statusCode >= 400) {
      httpErrorsTotal.labels(req.method, req.path, res.statusCode, 'http_error').inc();
    }
  });
  
  next();
});

// Health endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', service: 'nodejs-catalog' });
});

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Products endpoints
app.get('/products', (req, res) => {
  logger.info('Fetching all products', { count: products.length });
  res.json({ products, count: products.length });
});

app.get('/products/:id', (req, res) => {
  const product = products.find(p => p.id === parseInt(req.params.id));
  if (!product) {
    logger.warn('Product not found', { productId: req.params.id });
    return res.status(404).json({ error: 'Product not found' });
  }
  logger.info('Product fetched', { productId: product.id, productName: product.name });
  res.json(product);
});

// Check product availability (calls inventory service)
app.get('/products/:id/availability', async (req, res) => {
  try {
    const productId = req.params.id;
    const product = products.find(p => p.id === parseInt(productId));
    
    if (!product) {
      logger.warn('Product not found for availability check', { productId });
      return res.status(404).json({ error: 'Product not found' });
    }

    logger.info('Checking inventory', { productId, service: 'go-inventory' });
    
    // Call Go inventory service
    const inventoryResponse = await fetch(`http://go-inventory.ecommerce-poc.svc.cluster.local:8080/inventory/${productId}`);
    
    if (!inventoryResponse.ok) {
      logger.error('Inventory service error', { 
        productId, 
        status: inventoryResponse.status,
        service: 'go-inventory'
      });
      httpErrorsTotal.labels(req.method, req.path, 503, 'downstream_service_error').inc();
      return res.status(503).json({ error: 'Inventory service unavailable' });
    }

    const inventory = await inventoryResponse.json();
    logger.info('Inventory checked', { productId, available: inventory.available });
    
    res.json({
      product: product,
      inventory: inventory,
      canOrder: inventory.available
    });
  } catch (error) {
    logger.error('Failed to check availability', { 
      error: error.message,
      productId: req.params.id 
    });
    httpErrorsTotal.labels(req.method, req.path, 500, 'service_call_failed').inc();
    res.status(500).json({ error: 'Failed to check availability' });
  }
});

// Create order (calls both inventory and orders services)
app.post('/products/:id/order', async (req, res) => {
  try {
    const productId = req.params.id;
    const { quantity = 1 } = req.body;
    const product = products.find(p => p.id === parseInt(productId));
    
    if (!product) {
      logger.warn('Product not found for order', { productId });
      return res.status(404).json({ error: 'Product not found' });
    }

    logger.info('Creating order', { productId, quantity, service: 'multi-service-call' });

    // Step 1: Check inventory
    const inventoryResponse = await fetch(`http://go-inventory.ecommerce-poc.svc.cluster.local:8080/inventory/${productId}`);
    if (!inventoryResponse.ok) {
      logger.error('Inventory check failed', { productId, status: inventoryResponse.status });
      httpErrorsTotal.labels(req.method, req.path, 503, 'inventory_service_error').inc();
      return res.status(503).json({ error: 'Inventory service unavailable' });
    }

    const inventory = await inventoryResponse.json();
    if (!inventory.available || inventory.quantity < quantity) {
      logger.warn('Insufficient inventory', { productId, requested: quantity, available: inventory.quantity });
      return res.status(400).json({ error: 'Insufficient inventory' });
    }

    // Step 2: Create order in orders service
    const orderResponse = await fetch('http://python-orders.ecommerce-poc.svc.cluster.local:5000/orders', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        product_id: productId,
        product_name: product.name,
        quantity: quantity,
        price: product.price
      })
    });

    if (!orderResponse.ok) {
      logger.error('Order creation failed', { productId, status: orderResponse.status });
      httpErrorsTotal.labels(req.method, req.path, 503, 'orders_service_error').inc();
      return res.status(503).json({ error: 'Orders service unavailable' });
    }

    const order = await orderResponse.json();
    logger.info('Order created successfully', { 
      productId, 
      orderId: order.id,
      quantity,
      services: ['nodejs-catalog', 'go-inventory', 'python-orders']
    });

    res.status(201).json({
      message: 'Order created successfully',
      order: order,
      product: product
    });
  } catch (error) {
    logger.error('Order creation failed', { 
      error: error.message,
      stack: error.stack,
      productId: req.params.id 
    });
    httpErrorsTotal.labels(req.method, req.path, 500, 'order_creation_failed').inc();
    res.status(500).json({ error: 'Failed to create order' });
  }
});

app.post('/products', (req, res) => {
  const { name, price, stock } = req.body;
  const newProduct = {
    id: products.length + 1,
    name,
    price: parseFloat(price),
    stock: parseInt(stock)
  };
  products.push(newProduct);
  logger.info('Product created', { productId: newProduct.id, productName: newProduct.name });
  res.status(201).json(newProduct);
});

// Error test endpoints
app.get('/error/500', (req, res) => {
  logger.error('Simulated 500 error', { endpoint: '/error/500' });
  httpErrorsTotal.labels(req.method, req.path, 500, 'internal_server_error').inc();
  res.status(500).json({ error: 'Internal Server Error', message: 'Simulated error for testing' });
});

app.get('/error/timeout', async (req, res) => {
  logger.warn('Simulated timeout', { endpoint: '/error/timeout' });
  await new Promise(resolve => setTimeout(resolve, 5000));
  res.status(504).json({ error: 'Gateway Timeout', message: 'Request took too long' });
});

app.get('/error/crash', (req, res) => {
  logger.error('Simulated crash', { endpoint: '/error/crash' });
  httpErrorsTotal.labels(req.method, req.path, 500, 'crash').inc();
  throw new Error('Simulated application crash');
});

app.get('/error/db', (req, res) => {
  logger.error('Simulated database error', { endpoint: '/error/db', errorType: 'connection_failed' });
  httpErrorsTotal.labels(req.method, req.path, 503, 'database_error').inc();
  res.status(503).json({ error: 'Service Unavailable', message: 'Database connection failed' });
});

// Global error handler
app.use((err, req, res, next) => {
  logger.error('Unhandled error', {
    error: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method
  });
  httpErrorsTotal.labels(req.method, req.path, 500, 'unhandled_exception').inc();
  res.status(500).json({ error: 'Internal Server Error', message: err.message });
});

app.listen(PORT, () => {
  logger.info('Service started', { port: PORT, service: 'nodejs-catalog' });
  console.log(`Node.js Catalog Service listening on port ${PORT}`);
});
