#!/bin/bash
# Usuario inicial para iniciar sesión. MySQL solo ejecuta este script la primera vez (volumen vacío).
# shortcut: valores interpolados en SQL; usa solo letras, números, @ y . en ADMIN_EMAIL/ADMIN_PASSWORD.
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" <<SQL
INSERT INTO usuario (nombre, correo_electronico, contrasena, rol)
VALUES ('Administrador', '$ADMIN_EMAIL', '$ADMIN_PASSWORD', 'Administrador');
SQL
