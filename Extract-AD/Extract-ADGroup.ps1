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
        $parentGroup = Get-ADGroup -Identity $parentGroupDN
        $details = New-Object PSObject -Property @{
            ChildGroupName = $GroupName
            ParentGroupName = $parentGroup.Name
            ParentGroupSamAccountName = $parentGroup.SamAccountName
            ParentGroupType = $parentGroup.GroupCategory
        }
        
        $details

        Get-ADGroupMemberOfRecursive -GroupName $parentGroup.Name
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
    
    # Exporter les membres du groupe dans un fichier CSV
    $groupMembersDetails = Get-ADGroupMembersRecursive -GroupName $groupName
    $membersCsvPath = "Group_${groupName}_Members.csv"
    $groupMembersDetails | Export-Csv -Path $membersCsvPath -NoTypeInformation
    Write-Host "Les membres du groupe $groupName ont été exportés dans '$membersCsvPath'."

    # Exporter les groupes dont le groupe est membre dans un autre fichier CSV
    $groupMemberOfDetails = Get-ADGroupMemberOfRecursive -GroupName $groupName
    $memberOfCsvPath = "Group_${groupName}_MemberOf.csv"
    $groupMemberOfDetails | Export-Csv -Path $memberOfCsvPath -NoTypeInformation
    Write-Host "Les groupes dont le groupe $groupName est membre ont été exportés dans '$memberOfCsvPath'."
}