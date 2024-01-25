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
