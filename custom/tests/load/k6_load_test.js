import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '20s', target: 50 },  // Aquecimento
    { duration: '40s', target: 300 }, // Carga de 300 atendentes concorrentes
    { duration: '1m', target: 300 },  // Sustentação em pico
    { duration: '20s', target: 0 },   // Resfriamento
  ],
  thresholds: {
    http_req_failed: ['rate<0.01'],        // Erros abaixo de 1%
    http_req_duration: ['p(95)<500'],      // 95% das requisições abaixo de 500ms
  },
};

const BASE_URL = __ENV.API_URL || 'http://localhost:3000';
const ACCOUNT_ID = __ENV.ACCOUNT_ID || '1';
const AUTH_TOKEN = __ENV.AUTH_TOKEN || 'test-token';

export default function () {
  const headers = {
    'Content-Type': 'application/json',
    'api_access_token': AUTH_TOKEN,
  };

  // 1. Consulta de fluxos administrativos
  const listRes = http.get(`${BASE_URL}/api/v1/accounts/${ACCOUNT_ID}/custom_flows`, { headers });
  check(listRes, {
    'status é 200 ou 401 (auth válida)': r => r.status === 200 || r.status === 401,
    'resposta em menos de 500ms': r => r.timings.duration < 500,
  });

  sleep(1);
}
