# Compile the Rocq development with the Windows Rocq Platform (no WSL needed).
#   powershell -ExecutionPolicy Bypass -File scripts\build_proofs.ps1 [-Clean]
param([switch]$Clean)
$root = Split-Path -Parent $PSScriptRoot
$rq = "C:\Rocq-Platform~9.0~2025.08"
$env:Path = "$rq\bin;" + $env:Path
$log = Join-Path $root "output\rebase"
New-Item -ItemType Directory -Force $log | Out-Null
Set-Location (Join-Path $root "proof")
if ($Clean) { Remove-Item *.vo,*.vok,*.vos,*.glob -ErrorAction SilentlyContinue }
$files = @(
 "MTL_to_TBA_Shared_Clock_Derived_Strict_Direct_Core",
 "EncodingCorrect_Shared_Clock_Derived_Strict_Direct_Proof",
 "MTL_to_TBA_Invariants",
 "MTL_to_TBA_Optimizations",
 "MTL_to_TBA_Export",
 "MTL_to_TBA_Initialization",
 "MTL_to_TBA_Simplify",
 "MTL_to_TBA_Symbolic",
 "MTL_to_TBA_Negation",
 "MTL_to_TBA_Weak",
 "MTL_to_TBA_Recur",
 "LTL_to_PBA_Sound",
 "LTL_to_PBA_Pack",
 "LTL_to_PBA_Concrete",
 "LTL_to_PBA_Complete",
 "LTL_to_PBA_Final",
 "MTL_to_TBA_Verified_End_to_End",
 "Extract_Optim")
$summary = @()
foreach ($f in $files) {
  $t = Get-Date
  $out = & "$rq\bin\coqc.exe" -w -deprecated-missing-stdlib -w -extraction-opaque-accessed -w -extraction-axiom-to-realize -w -extraction-default-directory "$f.v" 2>&1 | Out-String
  $rc = $LASTEXITCODE
  $out | Set-Content (Join-Path $log "$f.log") -Encoding utf8
  $secs = [int]((Get-Date) - $t).TotalSeconds
  $ok = (Test-Path "$f.vo")
  $summary += "{0,-60} vo={1} rc={2} {3}s" -f $f, $ok, $rc, $secs
  if (-not $ok) { $summary += "   first error: " + (($out -split "`n" | Select-String -Pattern "Error" -Context 0,3 | Select-Object -First 1 | Out-String).Trim()) }
}
$summary | Set-Content (Join-Path $log "summary.txt") -Encoding utf8
"done" | Add-Content (Join-Path $log "summary.txt")
