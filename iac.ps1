<#
  Ejecuta Terraform y Ansible dentro del contenedor de herramientas.
  Uso: .\iac.ps1 <init|plan|apply|deploy|up|destroy|ssh|carga>
    up    = apply + deploy (crea la infraestructura y despliega la aplicación en un solo paso)
    carga = prueba de carga k6 contra el despliegue; guarda el reporte en performance/resultados/
#>
param(
    [Parameter(Mandatory)]
    [ValidateSet('init', 'plan', 'apply', 'deploy', 'up', 'destroy', 'ssh', 'carga')]
    [string]$Accion
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

if (-not (Test-Path "$root\secrets.env")) {
    throw "Falta secrets.env. Copia secrets.env.example a secrets.env y completa los valores."
}

docker build -q -t ejercicio5-iac "$root\tools" | Out-Null
if ($LASTEXITCODE -ne 0) { throw "No se pudo construir la imagen de herramientas." }

$run = @('run', '--rm', '-it', '-v', "${root}:/work", '--env-file', "$root\secrets.env", 'ejercicio5-iac')

function Invoke-Herramienta {
    docker @run @args
    if ($LASTEXITCODE -ne 0) { throw "Fallo: $($args -join ' ')" }
}

switch ($Accion) {
    'init'    { Invoke-Herramienta terraform -chdir=terraform init }
    'plan'    { Invoke-Herramienta terraform -chdir=terraform plan }
    'apply'   { Invoke-Herramienta terraform -chdir=terraform apply }
    'deploy'  { Invoke-Herramienta ansible-playbook -i ansible/inventory.ini ansible/playbook.yml }
    'up'      {
        Invoke-Herramienta terraform -chdir=terraform apply -auto-approve
        Invoke-Herramienta ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
    }
    'destroy' { Invoke-Herramienta terraform -chdir=terraform destroy }
    'ssh'     {
        $ip = (docker run --rm -v "${root}:/work" ejercicio5-iac terraform -chdir=terraform output -raw ip_publica).Trim()
        Invoke-Herramienta ssh -o StrictHostKeyChecking=no -i /root/.ssh/ejercicio5.pem "ubuntu@$ip"
    }
    'carga'   {
        $ip = (docker run --rm -v "${root}:/work" ejercicio5-iac terraform -chdir=terraform output -raw ip_publica).Trim()
        # A k6 solo se le pasan las credenciales de la app, no las llaves de AWS.
        $vars = @{}
        Get-Content "$root\secrets.env" | Where-Object { $_ -match '^(ADMIN_EMAIL|ADMIN_PASSWORD)=(.*)$' } |
            ForEach-Object { $vars[$Matches[1]] = $Matches[2] }
        $fecha = Get-Date -Format 'yyyy-MM-dd_HHmm'
        New-Item -ItemType Directory -Force "$root\performance\resultados" | Out-Null
        docker run --rm -it -v "${root}\performance:/perf" `
            -e "BASE_URL=http://$ip" -e "ADMIN_EMAIL=$($vars.ADMIN_EMAIL)" -e "ADMIN_PASSWORD=$($vars.ADMIN_PASSWORD)" `
            -e K6_WEB_DASHBOARD=true -e "K6_WEB_DASHBOARD_EXPORT=/perf/resultados/reporte_$fecha.html" `
            grafana/k6:1.1.0 run --summary-export "/perf/resultados/resumen_$fecha.json" /perf/carga.js
        # k6 sale con código 99 si no se cumplen los umbrales: el reporte se guarda igual.
        Write-Host "Reporte: performance\resultados\reporte_$fecha.html"
    }
}
