<#
.SYNOPSIS
    Script de scan user AD

.DESCRIPTION
    Script PowerShell d'analyse d'un utilisateur dans un domaine Active Directory

.AUTHOR
    BOURGEOIS-ROMAIN Anthony, ingénieur sécurité PAM
    Contact :

.VERSION
    1.0.0

.LINK
    GitHub : https://github.com/PS-Anth0/PS-AD-Toolkit

.EXAMPLE
    ./Extract-ADUser.ps1 -userName "Antho"

.NOTES
    02/02/2024 : Init du script
#>

# Params
param(
    [Parameter(Mandatory=$true)]
    [string]$userName,

    [Parameter(Mandatory=$false)]
    [switch]$ExtractToCSV

)

# Vérifier si le module ActiveDirectory est disponible
if (-not(Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "Le module ActiveDirectory est nécessaire mais n'est pas installé. Veuillez l'installer à l'aide de 'Install-WindowsFeature RSAT-AD-PowerShell' sur un serveur ou télécharger pour un poste client." -ForegroundColor Red
    exit
}

try {
    $user = Get-ADUser -Identity $userName -Properties * -ErrorAction Stop
    $details = New-Object PSObject -Property @{
        Name                  = $user.Name
        SamAccountName        = $user.SamAccountName
        DistinguishedName     = $user.DistinguishedName
        CN                    = $user.CN
        Mail                  = $user.mail
        MemberType            = $user.ObjectClass
        Enabled               = $user.Enabled
        AccountExpirationDate = $user.AccountExpirationDate
        whenChanged           = $user.whenChanged
        whenCreated           = $user.whenCreated
        
    }
} catch {
    Write-Error "Aucun utilisateur trouvé avec le nom $userName !"
    exit
}

$userGroups = $user | Select-Object -ExpandProperty MemberOf
if ($null -eq $userGroups -or $userGroups.Count -eq 0) {
    Write-Host "Aucun groupe trouvé pour l'utilisateur $userName !" -ForegroundColor DarkYellow
}

# Créer une liste pour stocker les informations des groupes
$groupInfoList = @()

foreach ($group in $userGroups) {
    $groupObj  = Get-ADGroup -Identity $group -Properties *
    $groupInfo = New-Object PSObject -Property @{
        GroupName         = $groupObj.Name
        Description       = $groupObj.Description
        DistinguishedName = $groupObj.DistinguishedName
    }
    $groupInfoList += $groupInfo
}

if ($ExtractToCSV) {
    # Exporter les informations dans des fichiers CSV
    $groupInfoList | Export-Csv -Path "User_${userName}_MemberOf.csv" -NoTypeInformation
    Write-Host "Les groupes de l'utilisateur $userName ont été exportés dans 'User_${userName}_MemberOf.csv'" -ForegroundColor Green

    $details       | Export-Csv -Path "User_${userName}_Infos.csv" -NoTypeInformation
    Write-Host "Les informations de l'utilisateur $userName ont été exportés dans 'User_${userName}_Infos.csv'" -ForegroundColor Green
}
else {
    Write-Host "`nInformations de l'utilisateur : $userName`n
        Name                  : $($user.Name)
        SamAccountName        : $($user.SamAccountName)
        DistinguishedName     : $($user.DistinguishedName)
        CN                    : $($user.CN)
        Mail                  : $($user.mail)
        MemberType            : $($user.ObjectClass)
        Enabled               : $($user.Enabled)
        AccountExpirationDate : $($user.AccountExpirationDate)
        whenChanged           : $($user.whenChanged)
        whenCreated           : $($user.whenCreated)
    "

    Write-Host "`nL'utilisateur est membre de : $groupInfoList`n"
    foreach ($groupInfo in $groupInfoList) {
        Write-Host "    GroupName         : $($groupInfo.GroupName)"
        Write-Host "    Description       : $($groupInfo.Description)"
        Write-Host "    DistinguishedName : $($groupInfo.DistinguishedName)`n"
    }
}