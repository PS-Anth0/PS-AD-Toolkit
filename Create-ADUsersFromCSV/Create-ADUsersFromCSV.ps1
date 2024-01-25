<#
.SYNOPSIS
    Script de création d'utilisateur AD

.DESCRIPTION
    Script PowerShell de création en masse d'utilisateurs dans un domain Active Directory au travers d'un fichier CSV.

.AUTHOR
    BOURGEOIS-ROMAIN Anthony, ingénieur sécurité PAM
    Contact : anthony.bourgeois-romain@protonmail.com

.VERSION
    1.0.0

.LINK
    GitHub : https://github.com/Lacrim0sa/PS-AD-Toolkit

.EXAMPLE
    ./Create-ADUsersFromCSV.ps1 -PasswordLength 20

.NOTES
    01/2024 : Init du script
#>

# Params
param (
    [Parameter(Mandatory=$true)]
    [string]$ADPath,
    [int]$PasswordLength,

    [Parameter(Mandatory=$false)]
    [Nullable[bool]]$AccountNotDelegated,
    [Nullable[bool]]$AllowReversiblePasswordEncryption,
    [Nullable[bool]]$CannotChangePassword,
    [Nullable[bool]]$ChangePasswordAtLogon,
    [Nullable[bool]]$CompoundIdentitySupported,
    [Nullable[bool]]$Enabled,
    [Nullable[bool]]$PasswordNeverExpires,
    [Nullable[bool]]$PasswordNotRequired,
    [Nullable[bool]]$SmartcardLogonRequired
    
)
# Fonctions
Function Write-Log {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -Append -FilePath $logPath
}

Function New-Password {
    param (
        [int]$length = 10
    )

    $characters = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNOPQRSTUVWXYZ0123456789!@$?_-'
    $password = For ($i=0; $i -lt $length; $i++) {
        $characters[(Get-Random -Maximum $characters.Length)]
    }

    return [String]::Join('', $password)
}

# Main Script
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Host "Le module Active Directory n'est pas installé sur cette machine. Veuillez installer le module pour continuer : Import-Module ActiveDirectory" -ForegroundColor Red
    exit
}

$logFileName = "Log_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".txt"
$logPath = "$PSScriptRoot\" + $logFileName
"--------- Start Job ---------" | Set-Content $logPath
Write-Log "[INFO] Initialisation du script."

Add-Type -AssemblyName System.Windows.Forms

$openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
$openFileDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")
$openFileDialog.Filter = "CSV files (*.csv)|*.csv"
$openFileDialog.ShowDialog() | Out-Null
$csvPath = $openFileDialog.FileName

if (-not (Test-Path $csvPath)) {
    Write-Host "[WARN] Fichier CSV non sélectionné ou introuvable."
    Write-Log "[WARN] Fichier CSV non sélectionné ou introuvable."
    exit
}

Write-Host "[INFO] Fichier CSV sélectionné : $csvPath"
Write-Log "[INFO] Fichier CSV sélectionné : $csvPath"

$exportPath = ""
"Login,Nom,Password,ADPath" | Set-Content $exportPath

$users = Import-Csv -Path $csvPath

foreach ($user in $users) {
    $login = $user.matricule
    $name = $user.nom
    $country = $user.country
    $phone = $user.telephone
    $passwordText = Generate-Password -length $PasswordLength
    $password = $passwordText | ConvertTo-SecureString -AsPlainText -Force

    $userParams = @{
        SamAccountName = $login
        Name = $name
        AccountPassword = $password
        Country = $country
        MobilePhone = $phone
    }

    if ($null -ne $AccountNotDelegated) {
        $userParams['AccountNotDelegated'] = $AccountNotDelegated
    }
    
    if ($null -ne $AllowReversiblePasswordEncryption) {
        $userParams['AllowReversiblePasswordEncryption'] = $AllowReversiblePasswordEncryption
    }
    
    if ($null -ne $CannotChangePassword) {
        $userParams['CannotChangePassword'] = $CannotChangePassword
    }

    if ($null -ne $ChangePasswordAtLogon) {
        $userParams['ChangePasswordAtLogon'] = $ChangePasswordAtLogon
    }
    
    if ($null -ne $CompoundIdentitySupported) {
        $userParams['CompoundIdentitySupported'] = $CompoundIdentitySupported
    }
    
    if ($null -ne $Enabled) {
        $userParams['Enabled'] = $Enabled
    }

    if ($null -ne $PasswordNeverExpires) {
        $userParams['PasswordNeverExpires'] = $PasswordNeverExpires
    }
    
    if ($null -ne $PasswordNotRequired) {
        $userParams['PasswordNotRequired'] = $PasswordNotRequired
    }
    
    if ($null -ne $SmartcardLogonRequired) {
        $userParams['SmartcardLogonRequired'] = $SmartcardLogonRequired
    }

    try {
        Write-Host "[INFO] Création de l'utilisateur : $($user.login)"
        Write-Log "[INFO] Création de l'utilisateur : $($user.login)"
        New-ADUser @userParams -ErrorAction Stop

        if(Get-ADUser -Filter { SamAccountName -eq $login }) {
            "$login,$name,$passwordText,$ADPath" | Out-File -Append $exportPath
        } else {
            Write-Host "[WARN] L'utilisateur n'a pas pu être vérifié dans l'AD : $($user.login)"
            Write-Log "[WARN] L'utilisateur n'a pas pu être vérifié dans l'AD : $($user.login)"
        }
    } catch {
        Write-Host "[ERROR] Erreur lors de la création de l'utilisateur : $($user.login)"
        Write-Log "[ERROR] Erreur lors de la création de l'utilisateur : $($user.login) - $($_.Exception.Message)"
    }
}

# SIG # Begin signature block
# MIIFoQYJKoZIhvcNAQcCoIIFkjCCBY4CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU2OXrR2CjMMVdwjzwze0HXllA
# qfygggM2MIIDMjCCAhqgAwIBAgIQOtpNws3e/4tFK9lux+936jANBgkqhkiG9w0B
# AQsFADAgMR4wHAYDVQQDDBVDcmVhdGUtQURVc2Vyc0Zyb21DU1YwHhcNMjQwMTI1
# MTQxNDI1WhcNMjUwMTI1MTQzNDI1WjAgMR4wHAYDVQQDDBVDcmVhdGUtQURVc2Vy
# c0Zyb21DU1YwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCvRwPJ24Dd
# 2NBVkL6wcKkz6u+F7dYJYQ4e1n1LJ9Jruu/B9vwu07RT/ba7UxofATwQ3J93PWAY
# yXtT6Fs+69eMzRVItjORrVWHrqpfICWjRNfWD7pAYI/Qz1Ob901odQ2JF0GIEesF
# 2LcJVm9QVYPXnkr5YMRGraMWha8IQAjS0oKlarUeZoIEhVehbrtaU1hrjeipjJ0S
# IdpkZWBkjnFZwLFdrCXLef+9kNN2Zj8Oye+GYlpW9VQdkR5wmuTKmHGTU/1dcueV
# SsT+5hs76FtsiiXOiSYCUeOwsSXF55gJasZqXVuBI800IWmA9RJFfnOWgYKj24Vw
# aBuW8bO+2P7ZAgMBAAGjaDBmMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUEDDAKBggr
# BgEFBQcDAzAgBgNVHREEGTAXghVDcmVhdGUtQURVc2Vyc0Zyb21DU1YwHQYDVR0O
# BBYEFJ0WTS9kPE60DDWftUBFCuvZhC0mMA0GCSqGSIb3DQEBCwUAA4IBAQBS9089
# UZ3sjpH6Xzu8olXlHquO3QuYZUZ8v9wxuG2crn35VXbZsYB7oLkFsXdOVYCHVwMz
# YjbXKq88Ex4qAT44T2fE40OCAJQHmLij4IR4r0ZVTL7I9wQ3RQ/LfX4M08k/6lzZ
# JLkxPtnlDlqXzz7Rb6xLmsftBgxfCQIt/h3VuO9jBk/CCN4zXt6dnAuogzf+9mey
# MJPVb2/d31CEaSEylgqHWSwjVJvY7rOQREd6iyZWnrPX1DcS5ARJV+Y1faf0MP0H
# IOS87tRXBTj5HDcDAEsjjDn3WQa3wllfxbUNENWWk34qBVBZ68dwT7tHRnGglcfm
# O+T8/WlKJC1aALAWMYIB1TCCAdECAQEwNDAgMR4wHAYDVQQDDBVDcmVhdGUtQURV
# c2Vyc0Zyb21DU1YCEDraTcLN3v+LRSvZbsfvd+owCQYFKw4DAhoFAKB4MBgGCisG
# AQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFLiC
# iSLnNJGE78bGJW9S9leONX+mMA0GCSqGSIb3DQEBAQUABIIBAGz0XU7JwavOZ04O
# kaysUVgmSt5l31AcbIi8JiVoTZxmC/o6psi/WYEZDk0YqBHtAwvg81OHAk+UpaJP
# 9Z3njI+UCmanAWLJ0qH3qqRGNY/2fUVXBrudy/brKg+LhRLGl9yTtBEGsij5NqJC
# tf4sSYsfSOGbMtVKKc430JZP+A6iBO33GFQuNfc6opqr/+YN41VrsxqKBvUd5M2W
# ND2ZXlGz86wehoMmEz3pxrzn/IMBw8LGXal2IVOhe/Uc8sQ9zfoUvI5cF6a6TyNo
# 7LNbUzib6M/fi2yeYdTgOTg8Y6UVuT+cU9+hjv1no8u56HoXFUyiwkfho1jS4owR
# t7ukv+0=
# SIG # End signature block
