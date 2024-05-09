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

    function AmountValidator {
        param (
            $value,
            $index,
            $file
        )
        
        if (-not (($value -match "^[0-9]+$"))){
            throw "Hiba! Szintaxis hiba van a megadott fajlban: $file`nEllenorizze az adott fajl kovetkezo sorat: $index`n"
        }
    }

    function SyntaxChecker {
        param (
            $Numbers,
            $Amount
        )

        if (-not ($Numbers.Count / 3 -eq $Amount)){
            return 1
        }else{
            return 0
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

        if ($data[0] -notmatch '^TIN'){
            Write-Error "Hibas fajl! Kerem ellenorizze a megadott fajlt: $file"
            continue
        }

        for ($i = 0; $i -lt $data.Count; $i++){
            if ($data[$i] -match '^TNAM') {
                $isTriProc = $false
                $title = $data[$i].Split(' ')[1]
            }
            elseif ($data[$i] -match '^VERT'){
                $vert_amount = $data[$i].Split(' ')[1]
                AmountValidator -value $vert_amount -index ([int]$i+1) -file $file
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
                AmountValidator -value $tri_amount -index ([int]$i+1) -file $file
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

        if((SyntaxChecker -Numbers $vert_numbers -Amount $vert_amount) -or (SyntaxChecker -Numbers $tri_numbers -Amount $tri_amount)){
            Write-Error "Hiba tortent a fajl feldolgozasa kozben! Kerem ellenorizze, hogy megfelelo koordinata adatok vannak megadva! Fajl: $file"
            continue
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