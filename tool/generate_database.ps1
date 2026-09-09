param([string]$Dart = 'dart')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$generatorRoot = Join-Path $PSScriptRoot 'db_codegen'
$schemaRoot = Join-Path $repoRoot 'lib/data/local/database'
foreach ($name in @('user_database.dart', 'users.drift')) {
    Copy-Item -LiteralPath (Join-Path $schemaRoot $name) -Destination (Join-Path $generatorRoot "lib/$name")
}
Push-Location $generatorRoot
try {
    & $Dart --suppress-analytics run build_runner build
    if ($LASTEXITCODE -ne 0) { throw 'Database generation failed' }
    Copy-Item -LiteralPath 'lib/user_database.g.dart' -Destination $schemaRoot
    & $Dart --suppress-analytics run drift_dev schema dump 'lib/user_database.dart' '../../lib/data/local/database/schemas/user'
    if ($LASTEXITCODE -ne 0) { throw 'Schema export failed' }
} finally { Pop-Location }
