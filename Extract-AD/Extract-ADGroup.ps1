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
    [string]$groupFilter,
    [Parameter(Mandatory=$true)]
    [int]$recursionLevel = 1
)

function Get-ADGroupMembersRecursive {
    param(
        [string]$GroupName,
        [int]$currentLevel
    )
    
    if ($currentLevel -le 0) {
        return
    }
    
    $groupMembers = Get-ADGroupMember -Identity $GroupName
    
    $results = @()
    foreach ($member in $groupMembers) {
        $details = New-Object PSObject -Property @{
            GroupName = $GroupName
            MemberName = $member.Name
            MemberSamAccountName = $member.SamAccountName
            MemberType = $member.objectClass
            RecursionLevel = $recursionLevel - $currentLevel + 1
        }
        
        $results += $details

        if ($member.objectClass -eq 'group') {
            $results += Get-ADGroupMembersRecursive -GroupName $member.Name -currentLevel ($currentLevel - 1)
        }
    }

    return $results
}

function Get-ADGroupMemberOfRecursive {
    param(
        [string]$GroupName,
        [int]$currentLevel
    )
    
    if ($currentLevel -le 0) {
        return
    }
    
    $memberOf = Get-ADGroup -Identity $GroupName -Properties MemberOf | Select-Object -ExpandProperty MemberOf

    $results = @()
    foreach ($parentGroupDN in $memberOf) {
        $parentGroup = Get-ADGroup -Identity $parentGroupDN
        $details = New-Object PSObject -Property @{
            ChildGroupName = $GroupName
            ParentGroupName = $parentGroup.Name
            ParentGroupSamAccountName = $parentGroup.SamAccountName
            ParentGroupType = $parentGroup.GroupCategory
            RecursionLevel = $recursionLevel - $currentLevel + 1
        }
        
        $results += $details

        $results += Get-ADGroupMemberOfRecursive -GroupName $parentGroup.Name -currentLevel ($currentLevel - 1)
    }

    return $results
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
    $groupMembersDetails = Get-ADGroupMembersRecursive -GroupName $groupName -currentLevel $recursionLevel
    $membersCsvPath = "Group_${groupName}_Members_Level${recursionLevel}.csv"
    $groupMembersDetails | Export-Csv -Path $membersCsvPath -NoTypeInformation
    Write-Host "Les membres du groupe $groupName jusqu'au niveau de récursivité $recursionLevel ont été exportés dans '$membersCsvPath'."

    # Exporter les groupes dont le groupe est membre dans un autre fichier CSV
    $groupMemberOfDetails = Get-ADGroupMemberOfRecursive -GroupName $groupName -currentLevel $recursionLevel
    $memberOfCsvPath = "Group_${groupName}_MemberOf_Level${recursionLevel}.csv"
    $groupMemberOfDetails | Export-Csv -Path $memberOfCsvPath -NoTypeInformation
    Write-Host "Les groupes dont le groupe $groupName est membre jusqu'au niveau de récursivité $recursionLevel ont été exportés dans '$memberOfCsvPath'."
}
