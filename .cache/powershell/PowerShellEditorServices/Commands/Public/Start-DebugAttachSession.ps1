# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

using namespace System.Collections
using namespace System.Management.Automation
using namespace System.Reflection
using namespace System.Threading
using namespace System.Threading.Tasks

function Start-DebugAttachSession {
    <#
    .EXTERNALHELP ..\PowerShellEditorServices.Commands-help.xml
    #>
    [OutputType([System.Management.Automation.Job2])]
    [CmdletBinding(DefaultParameterSetName = 'ProcessId')]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter(ParameterSetName = 'ProcessId')]
        [int]
        $ProcessId,

        [Parameter(ParameterSetName = 'CustomPipeName')]
        [string]
        $CustomPipeName,

        [Parameter()]
        [string]
        $RunspaceName,

        [Parameter()]
        [int]
        $RunspaceId,

        [Parameter()]
        [string]
        $ComputerName,

        [Parameter()]
        [ValidateSet('Close', 'Hide', 'Keep')]
        [string]
        $WindowActionOnEnd,

        [Parameter()]
        [IDictionary[]]
        $PathMapping,

        [Parameter()]
        [switch]
        $AsJob
    )

    $ErrorActionPreference = 'Stop'

    try {
        if ($PSBoundParameters.ContainsKey('RunspaceId') -and $RunspaceName) {
            $err = [ErrorRecord]::new(
                [ArgumentException]::new("Cannot specify both RunspaceId and RunspaceName parameters"),
                "InvalidRunspaceParameters",
                [ErrorCategory]::InvalidArgument,
                $null)
            $err.ErrorDetails = [ErrorDetails]::new("")
            $err.ErrorDetails.RecommendedAction = 'Specify only one of RunspaceId or RunspaceName.'
            $PSCmdlet.WriteError($err)
            return
        }

        # Var will be set by PSES in configurationDone before launching script
        $debugServer = Get-Variable -Name __psEditorServices_DebugServer -ValueOnly -ErrorAction Ignore
        if (-not $debugServer) {
            $err = [ErrorRecord]::new(
                [Exception]::new("Cannot start a new attach debug session unless running in an existing launch debug session not in a temporary console"),
                "NoDebugSession",
                [ErrorCategory]::InvalidOperation,
                $null)
            $err.ErrorDetails = [ErrorDetails]::new("")
            $err.ErrorDetails.RecommendedAction = 'Launch script with debugging to ensure the debug session is available.'
            $PSCmdlet.WriteError($err)
            return
        }

        if ($AsJob -and -not (Get-Command -Name Start-ThreadJob -ErrorAction Ignore)) {
            $err = [ErrorRecord]::new(
                [Exception]::new("Cannot use the -AsJob parameter unless running on PowerShell 7+ or the ThreadJob module is present"),
                "NoThreadJob",
                [ErrorCategory]::InvalidArgument,
                $null)
            $err.ErrorDetails = [ErrorDetails]::new("")
            $err.ErrorDetails.RecommendedAction = 'Install the ThreadJob module or run on PowerShell 7+.'
            $PSCmdlet.WriteError($err)
            return
        }

        $configuration = @{
            type = 'PowerShell'
            request = 'attach'
            # A temp console is also needed as the current one is busy running
            # this code. Failing to set this will cause a deadlock.
            createTemporaryIntegratedConsole = $true
        }

        if ($ProcessId) {
            if ($ProcessId -eq $PID) {
                $err = [ErrorRecord]::new(
                    [ArgumentException]::new("PSES does not support attaching to the current editor process"),
                    "AttachToCurrentProcess",
                    [ErrorCategory]::InvalidArgument,
                    $PID)
                $err.ErrorDetails = [ErrorDetails]::new("")
                $err.ErrorDetails.RecommendedAction = 'Specify a different process id.'
                $PSCmdlet.WriteError($err)
                return
            }

            if ($Name) {
                $configuration.name = $Name
            }
            else {
                $configuration.name = "Attach Process $ProcessId"
            }
            $configuration.processId = $ProcessId
        }
        elseif ($CustomPipeName) {
            if ($Name) {
                $configuration.name = $Name
            }
            else {
                $configuration.name = "Attach Pipe $CustomPipeName"
            }
            $configuration.customPipeName = $CustomPipeName
        }
        else {
            $configuration.name = 'Attach Session'
        }

        if ($ComputerName) {
            $configuration.computerName = $ComputerName
        }

        if ($PSBoundParameters.ContainsKey('RunspaceId')) {
            $configuration.runspaceId = $RunspaceId
        }
        elseif ($RunspaceName) {
            $configuration.runspaceName = $RunspaceName
        }

        if ($WindowActionOnEnd) {
            $configuration.temporaryConsoleWindowActionOnDebugEnd = $WindowActionOnEnd.ToLowerInvariant()
        }

        if ($PathMapping) {
            $configuration.pathMappings = $PathMapping
        }

        # https://microsoft.github.io/debug-adapter-protocol/specification#Reverse_Requests_StartDebugging
        $resp = $debugServer.SendRequest(
            'startDebugging',
            @{
                configuration = $configuration
                request = 'attach'
            }
        )

        # PipelineStopToken added in pwsh 7.6
        $cancelToken = if ($PSCmdlet.PipelineStopToken) {
            $PSCmdlet.PipelineStopToken
        }
        else {
            [CancellationToken]::new($false)
        }

        # There is no response for a startDebugging request
        $task = $resp.ReturningVoid($cancelToken)

        $waitTask = {
            [CmdletBinding()]
            param ([Parameter(Mandatory)][Task]$Task)

            while (-not $Task.AsyncWaitHandle.WaitOne(300)) {}
            $null = $Task.GetAwaiter().GetResult()
        }

        if ($AsJob) {
            # Using the Ast to build the scriptblock allows the job to inherit
            # the using namespace entries and include the proper line/script
            # paths in any error traces that are emitted.
            Start-ThreadJob -ScriptBlock {
                & ($args[0]).Ast.GetScriptBlock() $args[1]
            } -ArgumentList $waitTask, $task
        }
        else {
            & $waitTask $task
        }
    }
    catch {
        $PSCmdlet.WriteError($_)
        return
    }
}
# SIG # Begin signature block
# MIIoUgYJKoZIhvcNAQcCoIIoQzCCKD8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDdZ9zGYaknA4wm
# 1HANP/bBuZfAEEn3kdJuU1CEZ+7qdaCCDYUwggYDMIID66ADAgECAhMzAAAEhJji
# EuB4ozFdAAAAAASEMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjUwNjE5MTgyMTM1WhcNMjYwNjE3MTgyMTM1WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDtekqMKDnzfsyc1T1QpHfFtr+rkir8ldzLPKmMXbRDouVXAsvBfd6E82tPj4Yz
# aSluGDQoX3NpMKooKeVFjjNRq37yyT/h1QTLMB8dpmsZ/70UM+U/sYxvt1PWWxLj
# MNIXqzB8PjG6i7H2YFgk4YOhfGSekvnzW13dLAtfjD0wiwREPvCNlilRz7XoFde5
# KO01eFiWeteh48qUOqUaAkIznC4XB3sFd1LWUmupXHK05QfJSmnei9qZJBYTt8Zh
# ArGDh7nQn+Y1jOA3oBiCUJ4n1CMaWdDhrgdMuu026oWAbfC3prqkUn8LWp28H+2S
# LetNG5KQZZwvy3Zcn7+PQGl5AgMBAAGjggGCMIIBfjAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUBN/0b6Fh6nMdE4FAxYG9kWCpbYUw
# VAYDVR0RBE0wS6RJMEcxLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJh
# dGlvbnMgTGltaXRlZDEWMBQGA1UEBRMNMjMwMDEyKzUwNTM2MjAfBgNVHSMEGDAW
# gBRIbmTlUAXTgqoXNzcitW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIw
# MTEtMDctMDguY3JsMGEGCCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDEx
# XzIwMTEtMDctMDguY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIB
# AGLQps1XU4RTcoDIDLP6QG3NnRE3p/WSMp61Cs8Z+JUv3xJWGtBzYmCINmHVFv6i
# 8pYF/e79FNK6P1oKjduxqHSicBdg8Mj0k8kDFA/0eU26bPBRQUIaiWrhsDOrXWdL
# m7Zmu516oQoUWcINs4jBfjDEVV4bmgQYfe+4/MUJwQJ9h6mfE+kcCP4HlP4ChIQB
# UHoSymakcTBvZw+Qst7sbdt5KnQKkSEN01CzPG1awClCI6zLKf/vKIwnqHw/+Wvc
# Ar7gwKlWNmLwTNi807r9rWsXQep1Q8YMkIuGmZ0a1qCd3GuOkSRznz2/0ojeZVYh
# ZyohCQi1Bs+xfRkv/fy0HfV3mNyO22dFUvHzBZgqE5FbGjmUnrSr1x8lCrK+s4A+
# bOGp2IejOphWoZEPGOco/HEznZ5Lk6w6W+E2Jy3PHoFE0Y8TtkSE4/80Y2lBJhLj
# 27d8ueJ8IdQhSpL/WzTjjnuYH7Dx5o9pWdIGSaFNYuSqOYxrVW7N4AEQVRDZeqDc
# fqPG3O6r5SNsxXbd71DCIQURtUKss53ON+vrlV0rjiKBIdwvMNLQ9zK0jy77owDy
# XXoYkQxakN2uFIBO1UNAvCYXjs4rw3SRmBX9qiZ5ENxcn/pLMkiyb68QdwHUXz+1
# fI6ea3/jjpNPz6Dlc/RMcXIWeMMkhup/XEbwu73U+uz/MIIHejCCBWKgAwIBAgIK
# YQ6Q0gAAAAAAAzANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlm
# aWNhdGUgQXV0aG9yaXR5IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEw
# OTA5WjB+MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYD
# VQQDEx9NaWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG
# 9w0BAQEFAAOCAg8AMIICCgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+la
# UKq4BjgaBEm6f8MMHt03a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc
# 6Whe0t+bU7IKLMOv2akrrnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4D
# dato88tt8zpcoRb0RrrgOGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+
# lD3v++MrWhAfTVYoonpy4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nk
# kDstrjNYxbc+/jLTswM9sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6
# A4aN91/w0FK/jJSHvMAhdCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmd
# X4jiJV3TIUs+UsS1Vz8kA/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL
# 5zmhD+kjSbwYuER8ReTBw3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zd
# sGbiwZeBe+3W7UvnSSmnEyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3
# T8HhhUSJxAlMxdSlQy90lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS
# 4NaIjAsCAwEAAaOCAe0wggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRI
# bmTlUAXTgqoXNzcitW2oynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAL
# BgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBD
# uRQFTuHqp8cx0SOJNDBaBgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jv
# c29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFf
# MDNfMjIuY3JsMF4GCCsGAQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFf
# MDNfMjIuY3J0MIGfBgNVHSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEF
# BQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1h
# cnljcHMuaHRtMEAGCCsGAQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkA
# YwB5AF8AcwB0AGEAdABlAG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn
# 8oalmOBUeRou09h0ZyKbC5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7
# v0epo/Np22O/IjWll11lhJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0b
# pdS1HXeUOeLpZMlEPXh6I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/
# KmtYSWMfCWluWpiW5IP0wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvy
# CInWH8MyGOLwxS3OW560STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBp
# mLJZiWhub6e3dMNABQamASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJi
# hsMdYzaXht/a8/jyFqGaJ+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYb
# BL7fQccOKO7eZS/sl/ahXJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbS
# oqKfenoi+kiVH6v7RyOA9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sL
# gOppO6/8MO0ETI7f33VtY5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtX
# cVZOSEXAQsmbdlsKgEhr/Xmfwb1tbWrJUnMTDXpQzTGCGiMwghofAgEBMIGVMH4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01p
# Y3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTECEzMAAASEmOIS4HijMV0AAAAA
# BIQwDQYJYIZIAWUDBAIBBQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIF67
# cQS99mCILNc5BcCNfW3V7RK2J4XhfL2ENG3xq3cSMEIGCisGAQQBgjcCAQwxNDAy
# oBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20wDQYJKoZIhvcNAQEBBQAEggEAp0yf6uD60zld+FOmaibwJooFGpbPJRbPck7l
# cWHcdQT9+QB8jRgy9fSDmuyIFv/d1JyKAWFPjwMGmJ2HfrEtU8uOHAGgygmeKfoD
# 6ZFkXCJp5oubTYyJdwk62fjUU/oi2Sq72QRVifC8RpGOoV2dnQM9W5/SC4bzLiaZ
# Tww7OzLhrOfh+hACcb/Ij4kOH8B9oD6dkJHRO5tQJCvwxMTHso4Yd8vuhNT5hTu6
# 5vo7If9cBVmAKPl4pJkiAUHq55cfzMUgsy1TlbsaelYbtTcPcxcCFZTekggPP9Ze
# xeNtatleLpgo34aMf0TzCmcHfB/Br7eZl4SzAFavAOcYM/QcPqGCF60wghepBgor
# BgEEAYI3AwMBMYIXmTCCF5UGCSqGSIb3DQEHAqCCF4YwgheCAgEDMQ8wDQYJYIZI
# AWUDBAIBBQAwggFaBgsqhkiG9w0BCRABBKCCAUkEggFFMIIBQQIBAQYKKwYBBAGE
# WQoDATAxMA0GCWCGSAFlAwQCAQUABCCE9ZOq5ZaWQHkd5/tAyPAknlL6jKSxZotB
# Ba9Y2pRaAQIGabw/VoYTGBMyMDI2MDQwODIyNDUwNC4xMzZaMASAAgH0oIHZpIHW
# MIHTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQL
# EyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJzAlBgNVBAsT
# Hm5TaGllbGQgVFNTIEVTTjozMjFBLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9z
# b2Z0IFRpbWUtU3RhbXAgU2VydmljZaCCEfswggcoMIIFEKADAgECAhMzAAACGqmg
# HQagD0OqAAEAAAIaMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFBDQSAyMDEwMB4XDTI1MDgxNDE4NDgyOFoXDTI2MTExMzE4NDgyOFowgdMxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1pY3Jv
# c29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUGA1UECxMeblNoaWVs
# ZCBUU1MgRVNOOjMyMUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBTZXJ2aWNlMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA
# mYEAwSTz79q2V3ZWzQ5Ev7RKgadQtMBy7+V3XQ8R0NL8R9mupxcqJQ/KPeZGJTER
# +9Qq/t7HOQfBbDy6e0TepvBFV/RY3w+LOPMKn0Uoh2/8IvdSbJ8qAWRVoz2S9VrJ
# zZpB8/f5rQcRETgX/t8N66D2JlEXv4fZQB7XzcJMXr1puhuXbOt9RYEyN1Q3Z7Yj
# RkhfBsRc+SD/C9F4iwZqfQgo82GG4wguIhjJU7+XMfrv4vxAFNVg3mn1PoMWGZWi
# o+e14+PGYPVLKlad+0IhdHK5AgPyXKkqAhEZpYhYYVEItHOOvqrwukxVAJXMvWA3
# GatWkRZn33WDJVtghCW6XPLi1cDKiGE5UcXZSV4OjQIUB8vp2LUMRXud5I49FIBc
# E9nT00z8A+EekrPM+OAk07aDfwZbdmZ56j7ub5fNDLf8yIb8QxZ8Mr4RwWy/czBu
# V5rkWQQ+msjJ5AKtYZxJdnaZehUgUNArU/u36SH1eXKMQGRXr/xeKFGI8vvv5Jl1
# knZ8UqEQr9PxDbis7OXp2WSMK5lLGdYVH8VownYF3sbOiRkx5Q5GaEyTehOQp2Sf
# dbsJZlg0SXmHphGnoW1/gQ/5P6BgSq4PAWIZaDJj6AvLLCdbURgR5apNQQed2zYU
# gUbjACA/TomA8Ll7Arrv2oZGiUO5Vdi4xxtA3BRTQTUCAwEAAaOCAUkwggFFMB0G
# A1UdDgQWBBTwqyIJ3QMoPasDcGdGovbaY8IlNjAfBgNVHSMEGDAWgBSfpxVdAF5i
# XYP05dJlpxtTNRnpcjBfBgNVHR8EWDBWMFSgUqBQhk5odHRwOi8vd3d3Lm1pY3Jv
# c29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENB
# JTIwMjAxMCgxKS5jcmwwbAYIKwYBBQUHAQEEYDBeMFwGCCsGAQUFBzAChlBodHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFRp
# bWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNydDAMBgNVHRMBAf8EAjAAMBYGA1Ud
# JQEB/wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIHgDANBgkqhkiG9w0BAQsF
# AAOCAgEA1a72WFq7B6bJT3VOJ21nnToPJ9O/q51bw1bhPfQy67uy+f8x8akipzNL
# 2k5b6mtxuPbZGpBqpBKguDwQmxVpX8cGmafeo3wGr4a8Yk6Sy09tEh/Nwwlsyq7B
# RrJNn6bGOB8iG4OTy+pmMUh7FejNPRgvgeo/OPytm4NNrMMg98UVlrZxGNOYsifp
# RJFg5jE/Yu6lqFa1lTm9cHuPYxWa2oEwC0sEAsTFb69iKpN0sO19xBZCr0h5ClU9
# Pgo6ekiJb7QJoDzrDoPQHwbNA87Cto7TLuphj0m9l/I70gLjEq53SHjuURzwpmNx
# dm18Qg+rlkaMC6Y2KukOfJ7oCSu9vcNGQM+inl9gsNgirZ6yJk9VsXEsoTtoR7fM
# NU6Py6ufJQGMTmq6ZCq2eIGOXWMBb79ZF6tiKTa4qami3US0mTY41J129XmAglVy
# +ujSZkHu2lHJDRHs7FjnIXZVUE5pl6yUIl23jG50fRTLQcStdwY/LvJUgEHCIzjv
# lLTqLt6JVR5bcs5aN4Dh0YPG95B9iDMZrq4rli5SnGNWev5LLsDY1fbrK6uVpD+p
# svSLsNpht27QcHRsYdAMALXM+HNsz2LZ8xiOfwt6rOsVWXoiHV86/TeMy5TZFUl7
# qB59INoMSJgDRladVXeT9fwOuirFIoqgjKGk3vO2bELrYMN0QVwwggdxMIIFWaAD
# AgECAhMzAAAAFcXna54Cm0mZAAAAAAAVMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYD
# VQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEe
# MBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3Nv
# ZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAxMDAeFw0yMTA5MzAxODIy
# MjVaFw0zMDA5MzAxODMyMjVaMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEw
# MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA5OGmTOe0ciELeaLL1yR5
# vQ7VgtP97pwHB9KpbE51yMo1V/YBf2xK4OK9uT4XYDP/XE/HZveVU3Fa4n5KWv64
# NmeFRiMMtY0Tz3cywBAY6GB9alKDRLemjkZrBxTzxXb1hlDcwUTIcVxRMTegCjhu
# je3XD9gmU3w5YQJ6xKr9cmmvHaus9ja+NSZk2pg7uhp7M62AW36MEBydUv626GIl
# 3GoPz130/o5Tz9bshVZN7928jaTjkY+yOSxRnOlwaQ3KNi1wjjHINSi947SHJMPg
# yY9+tVSP3PoFVZhtaDuaRr3tpK56KTesy+uDRedGbsoy1cCGMFxPLOJiss254o2I
# 5JasAUq7vnGpF1tnYN74kpEeHT39IM9zfUGaRnXNxF803RKJ1v2lIH1+/NmeRd+2
# ci/bfV+AutuqfjbsNkz2K26oElHovwUDo9Fzpk03dJQcNIIP8BDyt0cY7afomXw/
# TNuvXsLz1dhzPUNOwTM5TI4CvEJoLhDqhFFG4tG9ahhaYQFzymeiXtcodgLiMxhy
# 16cg8ML6EgrXY28MyTZki1ugpoMhXV8wdJGUlNi5UPkLiWHzNgY1GIRH29wb0f2y
# 1BzFa/ZcUlFdEtsluq9QBXpsxREdcu+N+VLEhReTwDwV2xo3xwgVGD94q0W29R6H
# XtqPnhZyacaue7e3PmriLq0CAwEAAaOCAd0wggHZMBIGCSsGAQQBgjcVAQQFAgMB
# AAEwIwYJKwYBBAGCNxUCBBYEFCqnUv5kxJq+gpE8RjUpzxD/LwTuMB0GA1UdDgQW
# BBSfpxVdAF5iXYP05dJlpxtTNRnpcjBcBgNVHSAEVTBTMFEGDCsGAQQBgjdMg30B
# ATBBMD8GCCsGAQUFBwIBFjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3Bz
# L0RvY3MvUmVwb3NpdG9yeS5odG0wEwYDVR0lBAwwCgYIKwYBBQUHAwgwGQYJKwYB
# BAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMB
# Af8wHwYDVR0jBBgwFoAU1fZWy4/oolxiaNE9lJBb186aGMQwVgYDVR0fBE8wTTBL
# oEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMv
# TWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggr
# BgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNS
# b29DZXJBdXRfMjAxMC0wNi0yMy5jcnQwDQYJKoZIhvcNAQELBQADggIBAJ1Vffwq
# reEsH2cBMSRb4Z5yS/ypb+pcFLY+TkdkeLEGk5c9MTO1OdfCcTY/2mRsfNB1OW27
# DzHkwo/7bNGhlBgi7ulmZzpTTd2YurYeeNg2LpypglYAA7AFvonoaeC6Ce5732pv
# vinLbtg/SHUB2RjebYIM9W0jVOR4U3UkV7ndn/OOPcbzaN9l9qRWqveVtihVJ9Ak
# vUCgvxm2EhIRXT0n4ECWOKz3+SmJw7wXsFSFQrP8DJ6LGYnn8AtqgcKBGUIZUnWK
# NsIdw2FzLixre24/LAl4FOmRsqlb30mjdAy87JGA0j3mSj5mO0+7hvoyGtmW9I/2
# kQH2zsZ0/fZMcm8Qq3UwxTSwethQ/gpY3UA8x1RtnWN0SCyxTkctwRQEcb9k+SS+
# c23Kjgm9swFXSVRk2XPXfx5bRAGOWhmRaw2fpCjcZxkoJLo4S5pu+yFUa2pFEUep
# 8beuyOiJXk+d0tBMdrVXVAmxaQFEfnyhYWxz/gq77EFmPWn9y8FBSX5+k77L+Dvk
# txW/tM4+pTFRhLy/AsGConsXHRWJjXD+57XQKBqJC4822rpM+Zv/Cuk0+CQ1Zyvg
# DbjmjJnW4SLq8CdCPSWU5nR0W2rRnj7tfqAxM328y+l7vzhwRNGQ8cirOoo6CGJ/
# 2XBjU02N7oJtpQUQwXEGahC0HVUzWLOhcGbyoYIDVjCCAj4CAQEwggEBoYHZpIHW
# MIHTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQL
# EyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJzAlBgNVBAsT
# Hm5TaGllbGQgVFNTIEVTTjozMjFBLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9z
# b2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcGBSsOAwIaAxUA8YrutmKpSrub
# CaAYsU4pt1Ft8DaggYMwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAx
# MDANBgkqhkiG9w0BAQsFAAIFAO2BGjUwIhgPMjAyNjA0MDgxODE3MjVaGA8yMDI2
# MDQwOTE4MTcyNVowdDA6BgorBgEEAYRZCgQBMSwwKjAKAgUA7YEaNQIBADAHAgEA
# AgIDKzAHAgEAAgITCTAKAgUA7YJrtQIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgor
# BgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBCwUA
# A4IBAQAdcr/16rg3qCsnCXj3TfWF0PY5xZR+sSkRb3svAzIJUZxfjGcF7U/MMIWZ
# QEkkjYWuCVdoFp3yHRDWexGfoEPYTLo9592ODAM0Wk7f3Nl8tMxdrZ+AhnO+lEsn
# f9oXrYODBeRHDABx4fdBRJm+QhHcj9U+W942gX1ji0SKVkDqixqIMTkUnVE0I26W
# u1be4q6PCWQi3prE01Kvqp3j8bB/aElpMseNiqUMKQcVxZ1cdNe5v/ttjq/NbGSr
# d6cWwBwkh6mG4VYE4odfYx6ycojJx8Rxnho+sAtnyDlMqF6QJ4mFlSLXb6UMe0RE
# K7itD0cpgnVldwzmNP8IAg3TqGQHMYIEDTCCBAkCAQEwgZMwfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTACEzMAAAIaqaAdBqAPQ6oAAQAAAhowDQYJYIZIAWUD
# BAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0B
# CQQxIgQgoOV+Wx8Pupy6am6V/Di5AVjlYXCi5sJhECJmr7bUMnMwgfoGCyqGSIb3
# DQEJEAIvMYHqMIHnMIHkMIG9BCCdeiHHrbtpKcwB20doVU89WHIOH8S7w37uaHcD
# memK+zCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAC
# GqmgHQagD0OqAAEAAAIaMCIEICLVjA7srdNQFnSrEEqs8MuWxmtsGKzXsAuPKyT5
# HIY6MA0GCSqGSIb3DQEBCwUABIICAALc/hwOtPhysn1IKWRVLB4b72IH4SM4TOwb
# uPFSdjfZjFe6lmkr32RaIs5ZVqoLu0RW10JMn6ueR3rFgx26Y+vE0ILgd4ZNBIZH
# WEMHbGEL5xInIHipQr5lspHtjG6cuNtvgPX436Fi6SRqjLbFGPUuIfwlzy1+tRqH
# PWyAZxcqHH1MxG0GWurt30fRM5btjRBIvFRt861AguQjanNANWuFFiH7aGsIroLL
# VI8tzNPq1Z3m9L7E4Ix35mQM0Z/pCvYtNWkN8pupVeUgNLAvqN4gfcrXu2/XviN3
# 0x0es8I5HsB9IoL8zRRSA9ConVAVQ82fXqBf1SVrn1Up63Y/MP8vILbEQto5z6Up
# UnCTqv+lOL/oUm+uQqsU/vswuXabG5LETYY9z413GE4m+4oJQMsOcuFMXdOdUfNe
# m3AcP1TQo0+hsTJIXr4tt60W/LcsBaR152nzVj9FACLVXanW63g9xtQgMLPHPJnb
# blGcRZfNkHCDWLfz1LdHS6BgvCXItFGd0GxLDudxmo1stFEuLP6DZBWpnGXzQQf0
# SX2QBikgUreyDU8qcjC6DOdfVI0fLtoPc5NU91oqCrstOmOJhrQ+y0g8ddjqhGNP
# qex1IzuZJBGKJHbc9VAixwhJpoktWoIZKueF9091O8eZRYSRUj70bcOd3L/RTF+5
# amvf84zL
# SIG # End signature block
