function ConvertTo-EscapedCsvField {
    param($Value)
    $s = if ($null -eq $Value) { '' } else { [string]$Value }
    if ($s -match '[,"\r\n]') {
        return '"' + ($s -replace '"', '""') + '"'
    }
    return $s
}
