// Prueba de carga controlada contra el despliegue propio en AWS (nunca contra servicios de terceros).
// Flujo de un usuario: abrir login -> iniciar sesión -> abrir inicio -> consultar proyectos.
import http from 'k6/http';
import { check, group, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL;
const CREDENCIALES = JSON.stringify({
  correo_electronico: __ENV.ADMIN_EMAIL,
  contrasena: __ENV.ADMIN_PASSWORD,
});
const JSON_HEADERS = { headers: { 'Content-Type': 'application/json' } };

export const options = {
  // Rampa de subida, carga sostenida y bajada: máximo 30 usuarios virtuales concurrentes.
  stages: [
    { duration: '1m', target: 10 },
    { duration: '1m', target: 30 },
    { duration: '3m', target: 30 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_failed: ['rate<0.01'], // menos del 1 % de errores
    http_req_duration: ['p(95)<800'], // p95 por debajo de 800 ms
    checks: ['rate>0.99'],
  },
  summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
};

export function setup() {
  if (!BASE_URL) throw new Error('Falta BASE_URL');
  const res = http.post(`${BASE_URL}/verificarLogin`, CREDENCIALES, JSON_HEADERS);
  if (res.status !== 200 || res.json('nombre') === '000') {
    throw new Error(`El usuario de prueba no puede iniciar sesión (HTTP ${res.status})`);
  }
}

export default function () {
  group('01 Abrir login', () => {
    const res = http.get(`${BASE_URL}/login`, { tags: { paso: 'login_page' } });
    check(res, { 'login 200': (r) => r.status === 200 });
  });
  sleep(1);

  group('02 Iniciar sesion', () => {
    const res = http.post(`${BASE_URL}/verificarLogin`, CREDENCIALES, { ...JSON_HEADERS, tags: { paso: 'verificar_login' } });
    check(res, {
      'login 200': (r) => r.status === 200,
      'credenciales aceptadas': (r) => r.json('nombre') !== '000',
    });
  });
  sleep(1);

  group('03 Abrir inicio', () => {
    const res = http.get(`${BASE_URL}/inicio`, { tags: { paso: 'inicio_page' } });
    check(res, { 'inicio 200': (r) => r.status === 200 });
  });

  group('04 Consultar proyectos', () => {
    const res = http.post(`${BASE_URL}/consultarProyectos`, null, { tags: { paso: 'consultar_proyectos' } });
    check(res, {
      'proyectos 200': (r) => r.status === 200,
      'respuesta JSON': (r) => Array.isArray(r.json()),
    });
  });
  sleep(2);
}
