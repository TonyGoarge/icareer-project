const http = require('http');

const PORT = 5001;
const baseUrl = `http://localhost:${PORT}/api`;

const makeRequest = (method, path, body = null, token = null) => {
  return new Promise((resolve, reject) => {
    const dataString = body ? JSON.stringify(body) : '';
    
    const options = {
      hostname: 'localhost',
      port: PORT,
      path: `/api${path}`,
      method: method,
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(dataString)
      }
    };

    if (token) {
      options.headers['Authorization'] = `Bearer ${token}`;
    }

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        try {
          resolve({
            statusCode: res.statusCode,
            body: JSON.parse(data)
          });
        } catch (e) {
          resolve({
            statusCode: res.statusCode,
            body: data
          });
        }
      });
    });

    req.on('error', (err) => {
      reject(err);
    });

    if (body) {
      req.write(dataString);
    }
    req.end();
  });
};

const runTests = async () => {
  console.log('--- STARTING BACKEND INTEGRATION TESTS ---');
  
  // 1. Register a test user
  const email = `test_${Date.now()}@example.com`;
  const password = 'password123';
  
  console.log('\n1. Testing Register...');
  const regRes = await makeRequest('POST', '/auth/register', { email, password });
  console.log('Status Code:', regRes.statusCode);
  console.log('Body:', regRes.body);
  
  if (regRes.statusCode !== 201 || !regRes.body.token) {
    throw new Error('Registration failed');
  }
  
  const token = regRes.body.token;

  // 2. Login
  console.log('\n2. Testing Login...');
  const loginRes = await makeRequest('POST', '/auth/login', { email, password });
  console.log('Status Code:', loginRes.statusCode);
  console.log('Body:', loginRes.body);
  
  if (loginRes.statusCode !== 200 || !loginRes.body.token) {
    throw new Error('Login failed');
  }

  // 3. Request a ride
  console.log('\n3. Testing Request Ride...');
  const requestRes = await makeRequest('POST', '/rides/request', {
    pickup: '123 Main St',
    destination: '456 Tech Ave'
  }, token);
  console.log('Status Code:', requestRes.statusCode);
  console.log('Body:', requestRes.body);
  
  if (requestRes.statusCode !== 201 || requestRes.body.status !== 'Searching') {
    throw new Error('Ride request failed');
  }
  
  const rideId = requestRes.body._id;

  // 4. Get active ride
  console.log('\n4. Testing Get Active Ride...');
  const activeRes = await makeRequest('GET', '/rides/active', null, token);
  console.log('Status Code:', activeRes.statusCode);
  console.log('Body:', activeRes.body);
  
  if (activeRes.statusCode !== 200 || activeRes.body._id !== rideId) {
    throw new Error('Get active ride failed');
  }

  // 5. Poll status after a short delay (verify Searching / Driver Found state transitions)
  console.log('\n5. Waiting 11 seconds to simulate Driver Found transition...');
  await new Promise((resolve) => setTimeout(resolve, 11000));
  
  const statusRes = await makeRequest('GET', `/rides/${rideId}/status`, null, token);
  console.log('Status Code:', statusRes.statusCode);
  console.log('Body:', statusRes.body);
  
  if (statusRes.body.status !== 'Driver Found' || !statusRes.body.driverName) {
    throw new Error('Driver Found status simulation failed');
  }

  // 6. Test cancellation
  console.log('\n6. Testing Request another Ride to Cancel it...');
  const requestRes2 = await makeRequest('POST', '/rides/request', {
    pickup: 'Start Hill',
    destination: 'End Valley'
  }, token);
  const rideId2 = requestRes2.body._id;
  
  console.log('Cancelling the new ride...');
  const cancelRes = await makeRequest('POST', `/rides/${rideId2}/cancel`, null, token);
  console.log('Status Code:', cancelRes.statusCode);
  console.log('Body:', cancelRes.body);
  
  if (cancelRes.statusCode !== 200 || cancelRes.body.status !== 'Cancelled') {
    throw new Error('Ride cancellation failed');
  }

  console.log('\n--- ALL BACKEND INTEGRATION TESTS PASSED SUCCESSFULLY! ---');
};

runTests().catch((err) => {
  console.error('\nTest suite failed:', err);
  process.exit(1);
});
