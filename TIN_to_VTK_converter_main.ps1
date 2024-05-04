param (
    [Parameter(ValueFromPipeline = $true)]
    [System.IO.FileInfo[]]$FileObjFromPipe,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FilesFromParam,

    [Parameter(Mandatory = $true)]
    [string]$OutputFile
)

begin {
    $Files = @()

    function Validator {
        param (
            $value,
            $index
        )
        
        if (-not (($value -match "^[0-9]+$"))){
            throw "Error! There is a syntax error in the input file! Check line: $index"
        }
    }
}

process {
    if ($null -eq $FileObjFromPipe){
        foreach ($FileName in $FilesFromParam){
            $Files += $FileName
        }
    }
    else {
        foreach ($File in $FileObjFromPipe){
            $Files += $File.FullName
        }
    }
}

end {
    $outputContent = @()

    foreach ($file in $Files){
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

        $data = @((Get-Content $file).Split("`n"))

        for ($i = 0; $i -lt $data.Count; $i++){
            if ($data[$i] -match '^TNAM') {
                $isTriProc = $false
                $title = $data[$i].Split(' ')[1]
            }
            elseif ($data[$i] -match '^VERT'){
                $vert_amount = $data[$i].Split(' ')[1]
                Validator -value $vert_amount -index ([int]$i+1)
                $vert_numbers = @()
                $isVertProc = $true
            }
            elseif ($isVertProc -and $data[$i] -notmatch '^(BEGT|TNAM|MAT|TRI|ENDT|TIN)') {
                $numbers = $data[$i].Split(' ')
                for ($j = 0; $j -lt 3; $j ++){
                    $vert_numbers += $numbers[$j]
                }
            }
            elseif ($data[$i] -match '^TRI') {
                $isVertProc = $false
                $tri_amount = $data[$i].Split(' ')[1]
                $tri_size = [int]$tri_amount * 4
                Validator -value $tri_amount -index ([int]$i+1)
                $tri_numbers = @()
                $isTriProc = $true
            }
            elseif ($isTriProc -and $data[$i] -notmatch '^(BEGT|TNAM|MAT|TRI|ENDT|TIN)') {
                $tri_numbers += $data[$i].Split(' ')
            }
            elseif ($data[$i] -match "^ENDT") {
                if ($title -eq ""){
                    $title = "vtk output"
                }
            }
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
    Write-Host "`nA kimeneti fajl sikeresen letrehozva: $OutputFile`n"
}