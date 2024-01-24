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
    $passwordText = Generate-Password -length $PasswordLength
    $password = $passwordText | ConvertTo-SecureString -AsPlainText -Force

    $userParams = @{
        SamAccountName = $login
        Name = $name
        AccountPassword = $password
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
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUj9HDS1c+hcB9RrvpGVE1J9/V
# GcygggM2MIIDMjCCAhqgAwIBAgIQZacPWBl3laBM1/OUX3VirjANBgkqhkiG9w0B
# AQsFADAgMR4wHAYDVQQDDBVDcmVhdGUtQURVc2Vyc0Zyb21DU1YwHhcNMjQwMTI0
# MTA1NjQ3WhcNMjUwMTI0MTExNjQ3WjAgMR4wHAYDVQQDDBVDcmVhdGUtQURVc2Vy
# c0Zyb21DU1YwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDfjPDha8mn
# wjNs048jNgPNTwfjAvRWE2OmsYZoPoSLykdyMGWNX3ng/8eom6eqbfr4fXBHtd6Y
# kKNAqOBboee3EVMsZHoNB37lxmpLP2rKsUNtLb/GvBrvBgYbk+/07OXRlKA64dzQ
# uKNjq7sF48ypE+gwkRe+q2Q149EMBFzPmOoMkc4BXpoc99xTFxi1fmyrP+9m9cqd
# x25ad4J2CnryrZ0eV3AlSFCtuQbJ1bp2cXVxVoJ5RNlSq7UwG4vnBAXgHHD4p52W
# FYHugwdP5HuhTXhg+fZ+tYhvTR3CxfXlybVD/S/08gsPwlOiJMDWHOO3BFMtA0gj
# p3kRAk91QuoJAgMBAAGjaDBmMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUEDDAKBggr
# BgEFBQcDAzAgBgNVHREEGTAXghVDcmVhdGUtQURVc2Vyc0Zyb21DU1YwHQYDVR0O
# BBYEFPYUWIm4ZmC7b+TI6Cdz33ZJB6GjMA0GCSqGSIb3DQEBCwUAA4IBAQDG8mdV
# aqL1W0juU+K4xL58wcWthZVMzdLa7wFaYkbfyV7+HtvOdUJ/gd9xbtNhIOyTViQp
# JCLeqyMvI+JVMFF73gsIBcsq4y4Iq81RvZ6/7IzsuP6JFuIsF4PbMN6HB9Bfh/E8
# hDydGPAO8VmR5tNLE8E5I+LNvMDWNXQAVRIc4l/QjJwseM0TRT146BECE5dNopp+
# 56ety2H6ItANmN23hXpTkwuCr0WWRpEMX6Y361p0Ck14dWK4QOMpvnhUY7Q60AMD
# MVIQdI/94K+GuHIApVDLYJDegLInYPpO27I3ckIwYRag4qAejcBPwDibmHRd5kaD
# LPmVNu9zW8RQkf4eMYIB1TCCAdECAQEwNDAgMR4wHAYDVQQDDBVDcmVhdGUtQURV
# c2Vyc0Zyb21DU1YCEGWnD1gZd5WgTNfzlF91Yq4wCQYFKw4DAhoFAKB4MBgGCisG
# AQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFJTa
# bB0VLqCZW/3FDtimCf1hzeXFMA0GCSqGSIb3DQEBAQUABIIBAMm10AtAbTWDWjn8
# Sw5oqTu4XSeepZ60qmnWAiaJXYFipqlQq0oKdA1Jamt8jU7kgisamHRszZ0LOv5t
# mE05rpduo06NhdvG7+MFtavLkVXAhlNzPFXM9B1AqqQOauFj3s2At4TmLihch77P
# OJDWJ1tYM2N/jIH/cpgQx+pKQp8T42K0NtXwZacjdx9eN+U1YIrkNV5k5rxLeKNW
# 0JYN7Z8tLymMuECEca24jsPttyAQvLH3/H5X+6nMuG1QncLZg/hwkjK6p12dc4rm
# bHhnQcDsLuXWg+jjHRdbqf1qq2XAi1qF/V1WQt1gqoohQN29oKcOJvyNMcSsEoU7
# KdLtKFY=
# SIG # End signature block
