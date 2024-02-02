<#
.SYNOPSIS
    Script de scan group AD

.DESCRIPTION
    Script PowerShell qui va scanner les groupes est utilisateurs présent dans un groupe du domaine

.AUTHOR
    BOURGEOIS-ROMAIN Anthony, ingénieur sécurité PAM
    Contact : anthony.bourgeois-romain@protonmail.com

.VERSION
    1.0.0

.LINK
    GitHub : https://github.com/PS-Anth0/PS-AD-Toolkit

.EXAMPLE
    ./Create-ADUsersFromCSV.ps1 -ADPath "OU=Utilisateurs,DC=toto,DC=corp" -PasswordLength 20 -Enabled $true 

.NOTES
    02/02/2024 : Init du script
#>

# Params
param(
    [Parameter(Mandatory=$true)]
    [string]$groupFilter
)

function Get-ADGroupMembersRecursive {
    param(
        [string]$GroupName
    )

    $groupMembers = Get-ADGroupMember -Identity $GroupName

    foreach ($member in $groupMembers) {
        $details = New-Object PSObject -Property @{
            GroupName = $GroupName
            MemberName = $member.Name
            MemberSamAccountName = $member.SamAccountName
            MemberType = $member.objectClass
        }

        $details

        if ($member.objectClass -eq 'group') {
            Get-ADGroupMembersRecursive -GroupName $member.Name
        }
    }
}

function Get-ADGroupMemberOfRecursive {
    param(
        [string]$GroupName
    )

    $memberOf = Get-ADGroup -Identity $GroupName -Properties MemberOf | Select-Object -ExpandProperty MemberOf

    foreach ($parentGroupDN in $memberOf) {
        $parentGroupName = (Get-ADGroup -Identity $parentGroupDN).Name
        Get-ADGroupMembersRecursive -GroupName $parentGroupName
        Get-ADGroupMemberOfRecursive -GroupName $parentGroupName
    }
}

# Vérifier si le module ActiveDirectory est disponible
if (-not(Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "Le module ActiveDirectory est nécessaire mais n'est pas installé. Veuillez l'installer à l'aide de 'Install-WindowsFeature RSAT-AD-PowerShell' sur un serveur ou télécharger pour un poste client." -ForegroundColor Red
    exit
}

# Récupérer tous les groupes correspondant au filtre
$groups = Get-ADGroup -Filter "Name -like '$groupFilter'"
if ($null -eq $groups -or $groups.Count -eq 0) {
    Write-Error "Aucun groupe trouvé avec le filtre $groupFilter."
    exit
}

foreach ($group in $groups) {
    $groupName = $group.Name
    $allGroupDetails = @()

    # Obtenir les détails des membres du groupe
    $groupMembersDetails = Get-ADGroupMembersRecursive -GroupName $groupName
    $allGroupDetails += $groupMembersDetails

    # Obtenir les détails des groupes "memberOf" de manière récursive
    $groupMemberOfDetails = Get-ADGroupMemberOfRecursive -GroupName $groupName
    $allGroupDetails += $groupMemberOfDetails

    # Exporter les informations dans un fichier CSV pour chaque groupe
    $csvPath = "Group_${groupName}_Members.csv"
    $allGroupDetails | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Host "Les membres du groupe $groupName, ainsi que les informations des groupes 'memberOf' et leurs membres, ont été exportés dans '$csvPath'."
}