# Build the MoonBit web demo and copy the generated JS next to index.html.
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
Push-Location $root
try {
    moon build --target js --release
    $built = Join-Path $root "_build\js\release\build\web\web.js"
    if (-not (Test-Path $built)) {
        $built = Join-Path $root "_build\js\debug\build\web\web.js"
    }
    Copy-Item $built (Join-Path $here "moonchess.js") -Force
    Write-Host "Built web\moonchess.js"
    Write-Host "Serve this folder, e.g.: python -m http.server 8000"
}
finally {
    Pop-Location
}
