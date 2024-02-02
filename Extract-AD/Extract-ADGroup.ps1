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
        $details = "" | Select-Object GroupName, MemberName, MemberSamAccountName, MemberType
        $details.GroupName = $GroupName
        $details.MemberName = $member.Name
        $details.MemberSamAccountName = $member.SamAccountName
        $details.MemberType = $member.objectClass
        
        if ($member.objectClass -eq 'group') {
            Get-ADGroupMembersRecursive -GroupName $member.Name
        }
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
    $groupMembersDetails = Get-ADGroupMembersRecursive -GroupName $groupName
    
    # Exporter les informations dans un fichier CSV pour chaque groupe
    $csvPath = "Group_${groupName}_Members.csv"
    $groupMembersDetails | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Host "Les membres du groupe $groupName et de ses sous-groupes ont été exportés dans '$csvPath'."
}