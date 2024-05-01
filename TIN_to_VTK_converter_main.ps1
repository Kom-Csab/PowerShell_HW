param (
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FilesFromParam,

    [Parameter(Mandatory = $true)]
    [string]$OutputFile
)

$outputContent = @()

foreach ($file in $FilesFromParam){
    if (-not (Test-Path $file)){
        Write-Error "A bemeneti fajl nem talalhato: $file"
        continue
    }

    $title = ""
    $isVertProc = $false
    $isTriProc = $false
    $vert_amount = 0
    $tri_amount = 0
    $tri_size = 0
    $vert_numbers= @()
    $tri_numbers = @()

    $data = Get-Content $file

    foreach ($line in $data){
        if ($line -match '^TNAM') {
            $isTriProc = $false
            $title = $line.Split(' ')[1]
        }
        elseif ($line -match '^VERT'){
            $vert_amount = $line.Split(' ')[1]
            $vert_numbers = @()
            $isVertProc = $true
        }
        elseif ($isVertProc -and $line -notmatch '^(BEGT|TNAM|MAT|TRI|ENDT|TIN)') {
            $numbers = $line.Split(' ')
            for ($i = 0; $i -lt 3; $i ++){
                $vert_numbers += $numbers[$i]
            }
        }
        elseif ($line -match '^TRI') {
            $isVertProc = $false
            [int]$tri_amount = $line.Split(' ')[1]
            $tri_size = $tri_amount * 4
            $tri_numbers = @()
            $isTriProc = $true
        }
        elseif ($isTriProc -and $line -notmatch '^(BEGT|TNAM|MAT|TRI|ENDT|TIN)') {
            $tri_numbers += $line.Split(' ')
        }
        else{if ($line -match "^ENDT") {
            if ($title -eq ""){
                $title = "vtk output"
            }
        }}
    }

    $outputContent += @"
# vtk DataFile Version 3.0
$title
ASCII
DATASET UNSTRUCTURED_GRID

POINTS $vert_amount float
"@

    foreach ($num in $vert_numbers){
        $vert_line += "$num "
        $count++
        if (($count % 3) -eq 0){
            $outputContent += "$vert_line"
            $vert_line = ""
            $count = 0
        }
    }

    $outputContent += ""
    $outputContent += "CELLS $tri_amount $tri_size"
    for ($i = 0; $i -lt $tri_amount; $i++){
        $tri_line += "3 "
        for ($j = 0; $j -lt 3; $j++){
            $tri_line += "$($tri_numbers[$i * 3 + $j]) "
        }
        $outputContent += $tri_line
        $tri_line = ""
    }

    $outputContent += ""
    $outputContent += "CELL_TYPES $tri_amount"
    for ($i = 0; $i -lt $tri_amount; $i++){
        $outputContent += "5"
    }
}

$outputContent | Set-Content -Path $OutputFile
Write-Host "A kimeneti fajl sikeresen letrehozva: $OutputFile"