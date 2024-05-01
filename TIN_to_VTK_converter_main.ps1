param (
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FilesFromParam
)

foreach ($file in $FilesFromParam){
    if (-not (Test-Path $file)){
        Write-Error "A bemeneti fajl nem talalhato: $inputFile"
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
    }

    $output = @"
# vtk DataFile Version 3.0
$title
ASCII
DATASET UNSTRUCTURED_GRID

POINTS $vert_amount float
"@

    Write-Host $output
    foreach ($vert_num in $vert_numbers){
        Write-Host -NoNewline "$vert_num "
        $count ++
        if ($count -eq 3){
            Write-Host ""
            $count = 0
        }
    }

    Write-Host ""
    Write-Host "CELLS $tri_amount $tri_size"
    for ($i = 0; $i -lt $tri_amount; $i++){
        Write-Host -NoNewline "3 "
        for ($j = 0; $j -lt 3; $j++){
            Write-Host -NoNewline $tri_numbers[$i * 3 + $j]
            Write-Host -NoNewline " "
        }
        Write-Host ""
    }

    Write-Host ""
    Write-Host "CELL_TYPES $tri_amount"
    for ($i = 0; $i -lt $tri_amount; $i++){
        Write-Host 5
    }
}