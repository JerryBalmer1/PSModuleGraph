function ConvertTo-DotId {
    param([string]$Id)
    $safe = ($Id -replace '[^A-Za-z0-9_]', '_')
    if ($safe -match '^[0-9]') { $safe = "n_$safe" }
    return $safe
}
