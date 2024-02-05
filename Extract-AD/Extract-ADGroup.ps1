﻿<#
.SYNOPSIS
    Script de scan group AD

.DESCRIPTION
    Script PowerShell d'analyse du ou des groupes et utilisateurs présents dans un groupe ou des groupes du domaine Active Directory

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
    
    $GroupList = Get-ADGroup -Filter "name -like '$GroupName'" -Properties SamAccountName | Select-Object -ExpandProperty SamAccountName
    
    $results = @()
    foreach ($group in $GroupList) { 
        $groupMembers = Get-ADGroupMember -Identity $group
        foreach ($member in $groupMembers) {
            $group = if($currentLevel -eq 1){$group}else{$member.SamAccountName}
            if ($member.objectClass -eq 'user') {
                $memberDetails = Get-ADUser -Identity $member.SamAccountName -Properties Name, SamAccountName, mail, CN, objectClass, Enabled
                $details = New-Object PSObject -Property @{
                    GroupName            = $group
                    MemberName           = $memberDetails.Name
                    MemberSamAccountName = $memberDetails.SamAccountName
                    Mail                 = $memberDetails.mail
                    CN                   = $memberDetails.CN
                    MemberType           = $memberDetails.ObjectClass
                    Enabled              = $memberDetails.Enabled

                    RecursionLevel       = $recursionLevel - $currentLevel + 1
                }
                $results += $details
            }
            elseif ($member.objectClass -eq 'group') {
                $details = New-Object PSObject -Property @{
                    GroupName            = $group
                    MemberName           = $member.Name
                    MemberSamAccountName = $member.SamAccountName
                    Mail                 = "N/A"
                    CN                   = "N/A"
                    MemberType           = $member.objectClass
                    Enabled              = "N/A"

                    RecursionLevel       = $recursionLevel - $currentLevel + 1
                }
                $results += $details
                $results += Get-ADGroupMembersRecursive -GroupName $member.Name -currentLevel ($currentLevel - 1)
            }
            else{
                Write-Host "$($memberDetails.Name) n'est ni un groupe, ni un utilisateur, type : ($($memberDetails.objectClass))" -ForegroundColor DarkYellow
            }
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

    $GroupList = Get-ADGroup -Filter "name -like '$GroupName'" -Properties SamAccountName | Select-Object -ExpandProperty SamAccountName
    
    $results = @()
    foreach ($group in $GroupList) {
        $memberOf = Get-ADGroup -Identity $group -Properties MemberOf | Select-Object -ExpandProperty MemberOf 
        foreach ($parentGroupDN in $memberOf) {
            $parentGroup = Get-ADGroup -Identity $parentGroupDN
            $details = New-Object PSObject -Property @{
                ChildGroupName            = $group
                ParentGroupName           = $parentGroup.Name
                ParentGroupSamAccountName = $parentGroup.SamAccountName
                ParentGroupType           = $parentGroup.GroupCategory
                RecursionLevel            = $recursionLevel - $currentLevel + 1
            }
            $results += $details
            $results += Get-ADGroupMemberOfRecursive -GroupName $parentGroup.Name -currentLevel ($currentLevel - 1)
        } 
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

$membersCSV  = "Group_${groupFilter}_Members_Level${recursionLevel}.csv"
$memberOfCSV = "Group_${groupFilter}_MemberOf_Level${recursionLevel}.csv"
    
# Exporter les membres du groupe dans un fichier CSV
$groupMembersDetails = Get-ADGroupMembersRecursive -GroupName $groupFilter -currentLevel $recursionLevel
$membersCsvPath      = $membersCSV.Replace('*','').Replace('__','_')
$groupMembersDetails | Export-Csv -Path $membersCsvPath -NoTypeInformation
Write-Host "Les membres du groupe $groupName jusqu'au niveau de récursivité $recursionLevel ont été exportés dans '$membersCsvPath'."

# Exporter les groupes dont le groupe est membre dans un autre fichier CSV
$groupMemberOfDetails = Get-ADGroupMemberOfRecursive -GroupName $groupFilter -currentLevel $recursionLevel
$memberOfCsvPath      = $memberOfCSV.Replace('*','').Replace('__','_')
$groupMemberOfDetails | Export-Csv -Path $memberOfCsvPath -NoTypeInformation
Write-Host "Les groupes dont le groupe $groupName est membre jusqu'au niveau de récursivité $recursionLevel ont été exportés dans '$memberOfCsvPath'."