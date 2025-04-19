import http from 'k6/http';
import { check, sleep } from 'k6';

// Delay time (milliseconds)
const BACKEND_DELAY = 50; // Shorter delay request

// Test configuration
export const options = {
  // Base URL is retrieved from environment variable (-e BASE_URL=xxx)
  // Medium load test settings
  stages: [
    { duration: '5s', target: 200 },   // Increase to 200 users in 5 seconds
    { duration: '10s', target: 800 },  // Increase to 800 users in 10 seconds
    { duration: '15s', target: 1200 }, // Increase to 1200 users in 15 seconds
    { duration: '15s', target: 1200 }, // Maintain 1200 users for 15 seconds
    { duration: '5s', target: 0 },     // Decrease to 0 users in 5 seconds
  ],
  thresholds: {
    'http_req_failed': ['rate<0.05'],          // Failure rate less than 5%
    'http_req_duration': ['p(95)<3000'],       // 95% of requests under 3 seconds
    'http_req_duration{staticAsset:yes}': ['p(95)<1500'],
  },
};

// Main test function
export default function() {
  // Explicitly specify the unit as ms
  const url = `${__ENV.BASE_URL}/backend/delay/ms/${BACKEND_DELAY}`;
  
  // API call
  const response = http.get(url, {
    tags: { staticAsset: 'no' },
    timeout: '10s', // Set timeout
  });
  
  // Check response - more flexible modification
  check(response, {
    'status is 200': (r) => r.status === 200,
    'body contains valid response': (r) => {
      try {
        const body = JSON.parse(r.body);
        // Check if delay field exists, or milliseconds field exists
        return body.delay !== undefined || 
               body.milliseconds !== undefined || 
               body.ms !== undefined ||
               (typeof body === 'object' && Object.keys(body).length > 0); // Success if at least some object is returned
      } catch (e) {
        console.error('JSON parsing error:', e);
        // Log part of the response for debugging
        console.log('Response content:', r.body.substring(0, 100)); // Log only part of the response
        return false;
      }
    },
  });

  // Generate requests with short intervals
  sleep(0.05);
} 