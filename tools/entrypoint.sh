#!/bin/sh
set -e
# Los montajes desde Windows dan permisos 777 y ssh rechaza llaves así; se copia con 600.
if [ -f /work/.ssh/ejercicio5.pem ]; then
  install -m 600 /work/.ssh/ejercicio5.pem /root/.ssh/ejercicio5.pem
fi
exec "$@"
