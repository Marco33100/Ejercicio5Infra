# Evaluación del rendimiento

Prueba de carga controlada con **k6 1.1.0** contra el despliegue propio en AWS (`m7i-flex.large`, 2 vCPU, 8 GB, us-east-2). No se probó ningún servicio de terceros.

## Escenario

Script: [carga.js](carga.js). Cada usuario virtual repite el flujo real de la aplicación:

1. `GET /login`: página de inicio de sesión.
2. `POST /verificarLogin`: cliente → API → MySQL.
3. `GET /inicio`: página principal.
4. `POST /consultarProyectos`: cliente → API → MySQL.

Hay pausas de 1-2 s entre pasos (tiempo de lectura de una persona), lo que da unos 4.4 s por iteración.

| Etapa | Duración | Usuarios virtuales |
|---|---|---|
| Subida | 1 min | 0 → 10 |
| Subida | 1 min | 10 → 30 |
| Carga sostenida | 3 min | 30 |
| Bajada | 30 s | 30 → 0 |

Umbrales de aceptación: errores < 1 %, p95 < 800 ms, checks > 99 %.

Ejecución: `.\iac.ps1 carga`, desde Windows (México) hacia Ohio. La latencia incluye el viaje por Internet.

## Resultados (21/11/2026, 17:23-17:30)

| Métrica | Resultado | Umbral |
|---|---|---|
| Peticiones totales | 6 553 | |
| Throughput promedio | 19.6 req/s (≈ 30 req/s con 30 usuarios) | |
| Iteraciones completas | 1 638 | |
| Latencia mediana | 79 ms | |
| Latencia p90 | 155 ms | |
| **Latencia p95** | **255 ms** | < 800 ms ✅ |
| Latencia p99 | 626 ms | |
| **Tasa de error** | **0.01 % (1 de 6 553)** | < 1 % ✅ |
| Checks | 99.98 % (9 827 de 9 828) | > 99 % ✅ |

Reportes originales:
- [reporte_2026-11-21_1723.html](resultados/reporte_2026-11-21_1723.html): tablero exportado de k6, para abrir en el navegador.
- [resumen_2026-11-21_1723.json](resultados/resumen_2026-11-21_1723.json): métricas completas.
- [consola_2026-11-21_1723.txt](resultados/consola_2026-11-21_1723.txt): salida de la terminal.

Vista desde Grafana durante la prueba: las peticiones subieron a ~28 req/s en el cliente y ~14 req/s en la API, la CPU de la VM no pasó de ~15 %, la memoria se mantuvo en ~25 %, no hubo respuestas 4xx/5xx y ninguna alerta se disparó.

## Análisis

- **Capacidad sobrada.** Con 30 usuarios concurrentes la VM usó ~15 % de CPU. El cuello de botella no es el servidor: la mediana de 79 ms es casi toda latencia de red México-Ohio, porque la prueba de humo con 1 usuario dio 84 ms.
- **Cola de latencia.** El p99 (626 ms) es mucho mayor que la mediana. Coincide con picos de recolección de basura: el heap de la API sube y baja con más frecuencia bajo carga, como se ve en el panel *Memoria heap JVM*. Además, cada consulta registra el SQL en el log (`spring.jpa.show-sql=true`), lo que agrega trabajo por petición.
- **La única falla** fue un `connection refused` en `GET /login` a las 17:28:30, junto con una petición de 26 s (el máximo). Se revisó la VM después de la prueba: ningún contenedor se reinició (`RestartCount=0`), no hubo OOM y el cliente llevaba 48 min arriba. Se atribuye a un corte transitorio de red entre el equipo de pruebas y AWS. No se reprodujo y no afecta los umbrales.

## Conclusiones

1. El sistema cumple los tres umbrales con margen: el p95 de 255 ms está muy por debajo de los 800 ms y los errores son 100 veces menores que el límite.
2. Para la carga esperada de un gestor de proyectos escolar, la VM está sobredimensionada. Un tipo más pequeño bastaría para la app, aunque el monitoreo (Prometheus, Loki, Grafana) también consume memoria.
3. Mejoras posibles: desactivar `show-sql` en producción, ejecutar la prueba desde la misma región de AWS para aislar la latencia de red, y una prueba de estrés (más de 100 usuarios) para encontrar el punto de saturación.

## Limitaciones

- La prueba sale de una sola máquina con conexión doméstica, así que la red influye en las cifras.
- Los datos de la base son mínimos (1 usuario, sin proyectos). Con miles de registros, `consultarProyectos` sería más lento porque no tiene paginación.
- La duración (6.5 min) no detecta fugas de memoria de largo plazo.
