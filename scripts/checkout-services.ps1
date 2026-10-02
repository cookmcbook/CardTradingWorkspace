$ErrorActionPreference = 'Stop'

$workspaceRoot = Split-Path -Parent $PSScriptRoot

$repositories = @{
  CardTradingPOC = 'https://github.com/cookmcbook/CardTradingPOC.git'
  CardTradingBackend = 'https://github.com/cookmcbook/CardTradingBackend.git'
  AuthenticationService = 'https://github.com/cookmcbook/AuthenticationService.git'
}

foreach ($name in $repositories.Keys) {
  $path = Join-Path $workspaceRoot $name
  if (Test-Path (Join-Path $path '.git')) {
    Write-Host "Updating $name"
    git -C $path pull --ff-only
  } else {
    Write-Host "Cloning $name"
    git clone $repositories[$name] $path
  }
}
