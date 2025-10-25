// Performance monitoring middleware

const performanceMonitor = (req, res, next) => {
  const start = Date.now();

  // Capture the original res.end to measure response time
  const originalEnd = res.end;
  
  res.end = function(chunk, encoding) {
    const responseTime = Date.now() - start;
    
    // Log slow requests (those taking more than 500ms)
    if (responseTime > 500) {
      console.log(`Slow request: ${req.method} ${req.url} - ${responseTime}ms`);
    }
    
    // Add response time header in development
    if (process.env.NODE_ENV === 'development') {
      res.set('X-Response-Time', `${responseTime}ms`);
    }
    
    // Log performance metrics (only for API routes)
    if (req.url.startsWith('/api/')) {
      console.log(`${req.method} ${req.url} - ${responseTime}ms`);
    }
    
    return originalEnd.call(this, chunk, encoding);
  };
  
  next();
};

// Memory usage monitoring
const memoryMonitor = () => {
  const used = process.memoryUsage();
  console.log('Memory Usage:');
  for (let key in used) {
    console.log(`${key}: ${Math.round(used[key] / 1024 / 1024 * 100) / 100} MB`);
  }
};

// Health check endpoint
const healthCheck = (req, res) => {
  const uptime = process.uptime();
  const memory = process.memoryUsage();
  const load = {
    rss: Math.round(memory.rss / 1024 / 1024 * 100) / 100,
    heapTotal: Math.round(memory.heapTotal / 1024 / 1024 * 100) / 100,
    heapUsed: Math.round(memory.heapUsed / 1024 / 1024 * 100) / 100,
  };
  
  res.json({
    status: 'OK',
    uptime: Math.round(uptime),
    memory: load,
    timestamp: new Date().toISOString()
  });
};

module.exports = {
  performanceMonitor,
  memoryMonitor,
  healthCheck
};