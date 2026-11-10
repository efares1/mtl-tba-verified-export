$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    function Invoke-CheckedTool {
        param(
            [Parameter(Mandatory = $true)][string]$Name,
            [Parameter(Mandatory = $true)][string[]]$Arguments
        )

        $tool = Get-Command $Name -ErrorAction Stop
        Write-Host "Running $Name $($Arguments -join ' ')"
        $previousErrorAction = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            & $tool.Source @Arguments 2>&1 | ForEach-Object { Write-Host $_ }
            $exitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousErrorAction
        }
        if ($exitCode -ne 0) {
            throw "$Name failed with exit code $exitCode"
        }
    }

    # Keep the revised article within the requested 18--20-page limit.
    $latexArgs = @('-interaction=nonstopmode', '-halt-on-error', '-file-line-error')
    New-Item -ItemType Directory -Force 'output/pdf' | Out-Null
    Invoke-CheckedTool 'pdflatex' ($latexArgs + 'paper2.tex')
    Invoke-CheckedTool 'bibtex' @('paper2')
    Invoke-CheckedTool 'pdflatex' ($latexArgs + 'paper2.tex')
    Invoke-CheckedTool 'pdflatex' ($latexArgs + 'paper2.tex')
    Invoke-CheckedTool 'pdflatex' ($latexArgs + 'paper2.tex')

    Invoke-CheckedTool 'pdflatex' ($latexArgs + 'paper2_supp.tex')
    Invoke-CheckedTool 'bibtex' @('paper2_supp')
    Invoke-CheckedTool 'pdflatex' ($latexArgs + 'paper2_supp.tex')
    Invoke-CheckedTool 'pdflatex' ($latexArgs + 'paper2_supp.tex')

    Copy-Item -LiteralPath 'paper2.pdf' -Destination 'output/pdf/paper2.pdf' -Force
    Copy-Item -LiteralPath 'paper2_supp.pdf' -Destination 'output/pdf/paper2_supp.pdf' -Force

    $pdfinfo = Get-Command 'pdfinfo' -ErrorAction SilentlyContinue
    if ($pdfinfo) {
        $previousErrorAction = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $info = & $pdfinfo.Source 'output/pdf/paper2.pdf' 2>&1
            $infoExitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousErrorAction
        }
        if ($infoExitCode -ne 0) {
            throw "pdfinfo failed with exit code $infoExitCode"
        }
        $pageLine = $info | Where-Object { $_.ToString() -match '^Pages:\s+' } | Select-Object -First 1
        if ($pageLine -match '^Pages:\s+(\d+)') {
            $pages = [int]$Matches[1]
            Write-Host "output/pdf/paper2.pdf: $pages pages (18-20-page limit)."
            if ($pages -lt 18 -or $pages -gt 20) {
                Write-Warning "The current manuscript is $pages pages; the accepted range is 18-20 pages. Review content fit before submission."
            }
        }
    }
    else {
        Write-Host 'pdfinfo is unavailable; check paper2.pdf page count manually.'
    }
}
finally {
    Pop-Location
}
