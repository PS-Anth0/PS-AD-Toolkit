﻿<#
.SYNOPSIS
    Script de scan user AD

.DESCRIPTION
    Script PowerShell qui va scanner les groupes auxquels appartient un utilisateur du domaine

.AUTHOR
    BOURGEOIS-ROMAIN Anthony, ingénieur sécurité PAM
    Contact : anthony.bourgeois-romain@protonmail.com

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
    [string]$userName
)

# Vérifier si le module ActiveDirectory est disponible
if (-not(Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "Le module ActiveDirectory est nécessaire mais n'est pas installé. Veuillez l'installer à l'aide de 'Install-WindowsFeature RSAT-AD-PowerShell' sur un serveur ou télécharger pour un poste client." -ForegroundColor Red
    exit
}

try {
    $user = Get-ADUser -Identity $userName -Properties MemberOf -ErrorAction Stop
} catch {
    Write-Error "Aucun utilisateur trouvé avec le nom $userName."
    exit
}

$userGroups = $user | Select-Object -ExpandProperty MemberOf
if ($null -eq $userGroups -or $userGroups.Count -eq 0) {
    Write-Error "Aucun groupe trouvé pour l'utilisateur $userName."
    exit
}

# Créer une liste pour stocker les informations des groupes
$groupInfoList = @()

foreach ($group in $userGroups) {
    $groupObj = Get-ADGroup -Identity $group -Properties *
    $groupInfo = New-Object PSObject -Property @{
        GroupName = $groupObj.Name
        Description = $groupObj.Description
        DistinguishedName = $groupObj.DistinguishedName
    }
    $groupInfoList += $groupInfo
}

# Exporter les informations dans un fichier CSV
$groupInfoList | Export-Csv -Path "User_${userName}_Groups.csv" -NoTypeInformation

Write-Host "Les groupes de l'utilisateur $userName ont été exportés dans 'User_${userName}_Groups.csv'." -ForegroundColor Green