#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSModuleGraphUnderTest

    # A real listener on loopback, not a mock. The thing under test is whether a
    # server answers and what it answers with, so mocking the transport would
    # leave nothing worth asserting. TcpListener rather than HttpListener: an
    # HttpListener prefix can need a URL ACL and therefore an elevated shell,
    # and a test that needs admin is a test that gets skipped.
    #
    # Binding to IPAddress.Loopback raises no firewall prompt, so this needs no
    # hands-off gate.
    function Start-FakeStaticServer {
        param(
            [Parameter(Mandatory)] [string] $Root,
            [Parameter()] [switch] $AnswerEverything
        )

        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $listener.Start()
        $port = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port

        $runner = [powershell]::Create()
        $null = $runner.AddScript({
                param($Listener, $Root, $AnswerEverything)

                try {
                    while ($true) {
                        $client = $Listener.AcceptTcpClient()
                        try {
                            $stream = $client.GetStream()
                            $reader = [System.IO.StreamReader]::new($stream)
                            $requestLine = $reader.ReadLine()
                            while ($true) {
                                $header = $reader.ReadLine()
                                if ([string]::IsNullOrEmpty($header)) { break }
                            }

                            $status = '404 Not Found'
                            $body = 'not found'

                            if ($requestLine -match '^GET\s+(\S+)') {
                                $target = $Matches[1]
                                if ($target -eq '/') {
                                    $status = '200 OK'
                                    $body = '<html><body>Index of /</body></html>'
                                }
                                elseif ($AnswerEverything) {
                                    # Stands in for something that is not a static
                                    # file server and says 200 to anything.
                                    $status = '200 OK'
                                    $body = '{"ok":true}'
                                }
                                else {
                                    $relative = [uri]::UnescapeDataString($target.TrimStart('/'))
                                    $file = Join-Path $Root $relative
                                    if (Test-Path -LiteralPath $file -PathType Leaf) {
                                        $status = '200 OK'
                                        $body = [System.IO.File]::ReadAllText($file)
                                    }
                                }
                            }

                            $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
                            $head = "HTTP/1.1 $status`r`nContent-Type: text/html`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n"
                            $headBytes = [System.Text.Encoding]::ASCII.GetBytes($head)
                            $stream.Write($headBytes, 0, $headBytes.Length)
                            $stream.Write($bytes, 0, $bytes.Length)
                            $stream.Flush()
                        }
                        finally { $client.Close() }
                    }
                }
                catch {
                    # Stopping the listener throws out of AcceptTcpClient. That
                    # is how this loop is meant to end.
                }
            })
        $null = $runner.AddArgument($listener).AddArgument($Root).AddArgument([bool]$AnswerEverything)
        $handle = $runner.BeginInvoke()

        [pscustomobject]@{
            Port     = $port
            Origin   = "http://127.0.0.1:$port"
            Listener = $listener
            Runner   = $runner
            Handle   = $handle
        }
    }

    function Stop-FakeStaticServer {
        param([Parameter(Mandatory)] $Server)
        try { $Server.Listener.Stop() } catch { }
        try { $Server.Runner.Dispose() } catch { }
    }

    function Get-ClosedPort {
        # Bind, read the assigned port, release it. Briefly racy and good
        # enough: the assertion is that nothing answers, and if something else
        # grabs the port in that window the test fails loudly rather than
        # passing wrongly.
        $probe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $probe.Start()
        $port = ([System.Net.IPEndPoint]$probe.LocalEndpoint).Port
        $probe.Stop()
        $port
    }

    $script:ServedRoot = Join-Path $TestDrive 'served'
    $script:ReportDir = Join-Path $script:ServedRoot 'output/reports'
    New-Item -ItemType Directory -Path $script:ReportDir -Force | Out-Null

    $script:Report = Join-Path $script:ReportDir 'SampleModule-20260826-120000.html'
    Set-Content -LiteralPath $script:Report -Encoding utf8 -NoNewline -Value (
        '<!DOCTYPE html><html><head><meta charset="utf-8"><title>SampleModule dependency graph</title>' +
        '</head><body><div id="cy"></div></body></html>')
}

Describe 'Resolve-LoopbackDocumentUrl' {

    It 'finds the exact document URL when a server is serving it' {
        # THE POINT. A static server given a directory returns a listing, and
        # clicking through it is a step the tool should have removed.
        $server = Start-FakeStaticServer -Root $script:ServedRoot
        try {
            $result = InModuleScope PSModuleGraph -Parameters @{ Path = $script:Report; Port = $server.Port } {
                param($Path, $Port)
                Resolve-LoopbackDocumentUrl -Path $Path -Port $Port -TimeoutMilliseconds 2000
            }

            $result | Should-NotBeNull
            $result.Url | Should-Be "$($server.Origin)/output/reports/SampleModule-20260826-120000.html"
            $result.Origin | Should-Be $server.Origin
            $result.RelativePath | Should-Be 'output/reports/SampleModule-20260826-120000.html'
        }
        finally { Stop-FakeStaticServer -Server $server }
    }

    It 'walks up only as far as the served root' {
        # The served root cannot be asked for, so it is inferred. Serving the
        # reports directory itself means the file sits at the top of the tree
        # and the very first ancestor matches.
        $server = Start-FakeStaticServer -Root $script:ReportDir
        try {
            $result = InModuleScope PSModuleGraph -Parameters @{ Path = $script:Report; Port = $server.Port } {
                param($Path, $Port)
                Resolve-LoopbackDocumentUrl -Path $Path -Port $Port -TimeoutMilliseconds 2000
            }

            $result.RelativePath | Should-Be 'SampleModule-20260826-120000.html'
        }
        finally { Stop-FakeStaticServer -Server $server }
    }

    It 'returns nothing when a server is running but does not serve the file' {
        $elsewhere = Join-Path $TestDrive 'elsewhere'
        New-Item -ItemType Directory -Path $elsewhere -Force | Out-Null
        $server = Start-FakeStaticServer -Root $elsewhere
        try {
            $result = InModuleScope PSModuleGraph -Parameters @{ Path = $script:Report; Port = $server.Port } {
                param($Path, $Port)
                Resolve-LoopbackDocumentUrl -Path $Path -Port $Port -TimeoutMilliseconds 2000
            }

            ($null -eq $result) | Should-BeTrue
        }
        finally { Stop-FakeStaticServer -Server $server }
    }

    It 'refuses a 200 that is not this document' {
        # A 200 says a resource exists there, not that it is ours. Something
        # answering 200 to every path - an API, a single-page app fallback -
        # would otherwise be reported as a hit and the browser sent to it.
        $server = Start-FakeStaticServer -Root $script:ServedRoot -AnswerEverything
        try {
            $result = InModuleScope PSModuleGraph -Parameters @{ Path = $script:Report; Port = $server.Port } {
                param($Path, $Port)
                Resolve-LoopbackDocumentUrl -Path $Path -Port $Port -TimeoutMilliseconds 2000
            }

            ($null -eq $result) | Should-BeTrue
        }
        finally { Stop-FakeStaticServer -Server $server }
    }

    It 'returns nothing when no server is listening' {
        $closed = Get-ClosedPort
        $result = InModuleScope PSModuleGraph -Parameters @{ Path = $script:Report; Port = $closed } {
            param($Path, $Port)
            Resolve-LoopbackDocumentUrl -Path $Path -Port $Port -TimeoutMilliseconds 250
        }

        ($null -eq $result) | Should-BeTrue
    }

    It 'uses a supplied BaseUrl instead of scanning ports' {
        $server = Start-FakeStaticServer -Root $script:ServedRoot
        try {
            $result = InModuleScope PSModuleGraph -Parameters @{ Path = $script:Report; Base = $server.Origin } {
                param($Path, $Base)
                # A port list that cannot possibly answer, to prove BaseUrl wins.
                Resolve-LoopbackDocumentUrl -Path $Path -BaseUrl $Base -Port @(1) -TimeoutMilliseconds 2000
            }

            $result.Origin | Should-Be $server.Origin
        }
        finally { Stop-FakeStaticServer -Server $server }
    }

    It 'returns nothing for a file that does not exist' {
        $result = InModuleScope PSModuleGraph -Parameters @{ Path = (Join-Path $TestDrive 'no-such.html') } {
            param($Path)
            Resolve-LoopbackDocumentUrl -Path $Path -TimeoutMilliseconds 250
        }

        ($null -eq $result) | Should-BeTrue
    }
}

Describe 'Get-LoopbackResponse' {
    It 'tells a refused connection from a 404' {
        # Three outcomes, not two. A 404 means a server is there and said no; a
        # refused connection means there is no server. Collapsing them makes
        # every closed port look like a served root missing one file, and the
        # probe walks every ancestor against nothing.
        $server = Start-FakeStaticServer -Root $script:ServedRoot
        try {
            $missing = InModuleScope PSModuleGraph -Parameters @{ Origin = $server.Origin } {
                param($Origin)
                Get-LoopbackResponse -Url "$Origin/nope.html" -TimeoutMilliseconds 2000
            }

            $missing.Answered | Should-BeTrue
            $missing.Status | Should-Be 404
        }
        finally { Stop-FakeStaticServer -Server $server }

        $closed = Get-ClosedPort
        $refused = InModuleScope PSModuleGraph -Parameters @{ Port = $closed } {
            param($Port)
            Get-LoopbackResponse -Url "http://127.0.0.1:$Port/" -TimeoutMilliseconds 250
        }

        $refused.Answered | Should-BeFalse
        $refused.Status | Should-Be 0
    }
}
