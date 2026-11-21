<#
  Ejecuta Terraform y Ansible dentro del contenedor de herramientas.
  Uso: .\iac.ps1 <init|plan|apply|deploy|up|destroy|ssh>
    up = apply + deploy (crea la infraestructura y despliega la aplicación en un solo paso)
#>
param(
    [Parameter(Mandatory)]
    [ValidateSet('init', 'plan', 'apply', 'deploy', 'up', 'destroy', 'ssh')]
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
}
