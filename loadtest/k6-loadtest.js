/**
 * Script k6 — Test de charge WorldCup 2026
 *
 * Déclenche le HPA en saturant /api/compute (CPU-bound)
 * et génère du trafic mixte sur /api/vote pour simuler l'usage réel.
 *
 * Usage :
 *   k6 run --vus 20 --duration 2m loadtest/k6-loadtest.js
 *   k6 run -e BASE_URL=https://worldcup.mondomaine.fr loadtest/k6-loadtest.js
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

// Métriques personnalisées
const errorRate = new Rate('error_rate');
const computeDuration = new Trend('compute_duration_ms');

export const options = {
  stages: [
    { duration: '30s', target: 5 },   // montée progressive
    { duration: '60s', target: 20 },  // charge soutenue (déclenche HPA)
    { duration: '30s', target: 5 },   // descente
    { duration: '20s', target: 0 },   // refroidissement
  ],
  thresholds: {
    http_req_failed: ['rate<0.05'],           // < 5% d'erreurs
    http_req_duration: ['p(95)<10000'],       // p95 < 10s (compute prend 2-3s)
    error_rate: ['rate<0.05'],
  },
};

// IDs des équipes disponibles (1-48)
const TEAM_IDS = Array.from({ length: 48 }, (_, i) => i + 1);

export default function () {
  const scenario = Math.random();

  if (scenario < 0.6) {
    // 60% du trafic : CPU compute (déclenche le HPA)
    const start = Date.now();
    const res = http.get(`${BASE_URL}/api/compute`, {
      timeout: '15s',
    });
    computeDuration.add(Date.now() - start);

    const ok = check(res, {
      'compute status 200': (r) => r.status === 200,
      'compute has result': (r) => {
        try {
          return JSON.parse(r.body).result > 0;
        } catch {
          return false;
        }
      },
    });
    errorRate.add(!ok);

  } else if (scenario < 0.85) {
    // 25% : votes
    const teamId = TEAM_IDS[Math.floor(Math.random() * TEAM_IDS.length)];
    const res = http.post(
      `${BASE_URL}/api/vote`,
      JSON.stringify({ team_id: teamId }),
      { headers: { 'Content-Type': 'application/json' } }
    );
    const ok = check(res, {
      'vote status 201': (r) => r.status === 201,
    });
    errorRate.add(!ok);

  } else {
    // 15% : health check et métriques (trafic de fond)
    const healthRes = http.get(`${BASE_URL}/api/health/db`);
    check(healthRes, {
      'health db ok': (r) => r.status === 200,
    });

    http.get(`${BASE_URL}/api/votes/results`);
  }

  // Pause entre 0.1 et 0.5s pour simuler un usage réaliste
  sleep(0.1 + Math.random() * 0.4);
}
