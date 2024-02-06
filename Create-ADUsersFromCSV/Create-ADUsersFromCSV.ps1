<#
.SYNOPSIS
    Script de création d'utilisateurs AD

.DESCRIPTION
    Script PowerShell de création en masse d'utilisateurs dans un domaine Active Directory au travers d'un fichier CSV.

.AUTHOR
    BOURGEOIS-ROMAIN Anthony, ingénieur sécurité PAM
    Contact :

.VERSION
    1.0.0

.LINK
    GitHub : https://github.com/PS-Anth0/PS-AD-Toolkit

.EXAMPLE
    ./Create-ADUsersFromCSV.ps1 -ADPath "OU=Utilisateurs,DC=toto,DC=corp" -PasswordLength 20 -Enabled $true 

.NOTES
    01/2024 : Init du script
#>

# Params
param (
    [Parameter(Mandatory=$true)]
    [string]$ADPath,
    [int]$PasswordLength,

    [Parameter(Mandatory=$false)]
    [Nullable[DateTime]]$AccountExpirationDate,
    [Nullable[bool]]$AccountNotDelegated,
    [Nullable[SecureString]]$AccountPassword,
    [Nullable[bool]]$AllowReversiblePasswordEncryption,
    [Nullable[ADAuthenticationPolicy]]$AuthenticationPolicy,
    [Nullable[ADAuthenticationPolicy]]$AuthenticationPolicySilo,
    
    [ValidateSet("Negotiate", "Basic")]
    [Nullable[ADAuthType]]$AuthType,

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
        [int]$length = 20
    )

    $characters = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNOPQRSTUVWXYZ0123456789!@$?_-*/\:;.,&#([{}])=^'
    $password = For ($i=0; $i -lt $length; $i++) {
        $characters[(Get-Random -Maximum $characters.Length)]
    }

    return [String]::Join('', $password)
}

# Main Script
Write-Host "
 _____    _____                    _____           _______                _  _     _  _   
|  __ \  / ____|            /\    |  __ \         |__   __|              | || |   (_)| |  
| |__) || (___   ______    /  \   | |  | | ______    | |     ___    ___  | || | __ _ | |_ 
|  ___/  \___ \ |______|  / /\ \  | |  | ||______|   | |    / _ \  / _ \ | || |/ /| || __|
| |      ____) |         / ____ \ | |__| |           | |   | (_) || (_) || ||   < | || |_ 
|_|     |_____/         /_/    \_\|_____/            |_|    \___/  \___/ |_||_|\_\|_| \__|                                                                            
" -BackgroundColor Black -ForegroundColor DarkGreen

if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Host "Le module Active Directory n'est pas installé sur cette machine. Veuillez installer le module pour continuer" -ForegroundColor Red
    exit
}

$logFileName = "Log_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".txt"
$logPath = "$PSScriptRoot\" + $logFileName
"--------- Start Job ---------" | Set-Content $logPath -Encoding Unicode
Write-Log "[INFO] Initialisation du script."

Add-Type -AssemblyName System.Windows.Forms

$openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
$openFileDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")
$openFileDialog.Filter = "CSV files (*.csv)|*.csv"
$openFileDialog.ShowDialog() | Out-Null
$csvPath = $openFileDialog.FileName

if (-not (Test-Path $csvPath)) {
    Write-Host "[WARN] Fichier CSV non sélectionné ou introuvable." -ForegroundColor Red
    Write-Log "[WARN] Fichier CSV non sélectionné ou introuvable."
    exit
}

Write-Host "[INFO] Fichier CSV sélectionné : $csvPath"
Write-Log "[INFO] Fichier CSV sélectionné : $csvPath"

$exportPath = "$PSScriptRoot\Result.csv"
"Login,Nom,Password,ADPath" | Set-Content $exportPath -Encoding Unicode

$users = Import-Csv -Path $csvPath

foreach ($user in $users) {
    [string]$login = $user.matricule
    [string]$name = $user.nom
    #[string]$country = $user.country
    [string]$phone = $user.telephone
    $passwordText = New-Password -length $PasswordLength
    $password = $passwordText | ConvertTo-SecureString -AsPlainText -Force

    $userParams = @{
        Path = $ADPath
        SamAccountName = $login
        Name = $name
        DisplayName = $name
        AccountPassword = $password
        #Country = $country
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
        Write-Host "[INFO] Création de l'utilisateur : $($login)"
        Write-Log "[INFO] Création de l'utilisateur : $($login)"
        New-ADUser @userParams -ErrorAction Stop

        if(Get-ADUser -Filter { SamAccountName -eq $login }) {
            "$login,$name,$passwordText,$ADPath" | Out-File -Append $exportPath
        } else {
            Write-Host "[WARN] L'utilisateur n'a pas pu etre vérifié dans l'AD : $($login)"
            Write-Log "[WARN] L'utilisateur n'a pas pu etre vérifié dans l'AD : $($login)"
        }
    } catch {
        Write-Host "[ERROR] Erreur lors de la création de l'utilisateur : $($login)"
        Write-Log "[ERROR] Erreur lors de la création de l'utilisateur : $($login) - $($_.Exception.Message)"
    }
}