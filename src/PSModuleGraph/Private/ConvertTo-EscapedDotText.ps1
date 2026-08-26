function ConvertTo-EscapedDotText {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    return ($Text -replace '\\', '\\\\' -replace '"', '\"')
}
