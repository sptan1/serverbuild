Function Get-AD-Object{
Param (
        [Parameter(Mandatory=$False)][String[]]$Name,
        [Parameter(Mandatory=$False)][String[]]$DistinguishedName,
        [Parameter(Mandatory=$False)][String]$Domain,
        [Parameter(Mandatory=$False)][String]$password="sf2dDdafRewaf435gd2W#D3#$FF7#E4AF434qRwr23FER",
        [Parameter(Mandatory=$False)][String]$secret="lfjE3HH6f4jP0OH8fdFV3eyu4543FQC7m",
        [Parameter(Mandatory=$False)][String]$Pass="fjE3H6H6e4ju9H8fdFr66HH45r3FeCvt",
        [Parameter(Mandatory=$False)][String]$Passphrases="G32ErfdFV3e4Hf53Ht65frtdV3eHkl54jP0p9OHH48fXneb45Fe9"
        )

If ((Get-CimInstance -ClassName 'Win32_ComputerSystem' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty 'PartOfDomain') -eq $false) {
    Try {
        $targetOU = (Get-SSMParameterValue -Name 'defaultTargetOU' -ErrorAction Stop).Parameters[0].Value
        $domainName = (Get-SSMParameterValue -Name 'domainName' -ErrorAction Stop).Parameters[0].Value
        $domainJoinUserName = (Get-SSMParameterValue -Name 'domainJoinUserName' -ErrorAction Stop).Parameters[0].Value
        $domainJoinPassword = (Get-SSMParameterValue -Name 'domainJoinPassword' -WithDecryption:$true -ErrorAction Stop).Parameters[0].Value | ConvertTo-SecureString -AsPlainText -Force
    } Catch [System.Exception] {
        Write-Output " Failed to get SSM Parameter(s) $_"
    }
    $domainCredential = New-Object System.Management.Automation.PSCredential($domainJoinUserName, $domainJoinPassword)

    Try {
        Write-Output "Attempting to join $env:COMPUTERNAME to Active Directory domain: $domainName and moving $env:COMPUTERNAME to the following OU: $targetOU."
        Add-Computer -ComputerName $env:COMPUTERNAME -DomainName $domainName -Credential $domainCredential -OUPath $targetOU -Restart:$false -ErrorAction Stop 
    } Catch [System.Exception] {
        Write-Output "Failed to add computer to the domain $_"
        Exit 1
    }
} Else {
    Write-Output "$env:COMPUTERNAME is already part of the Active Directory domain $domainName."
    Exit 0
}

If ((Get-CimInstance -ClassName 'Win32_ComputerSystem' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty 'PartOfDomain') -eq $true) {
    Try {
        $domainName = (Get-SSMParameterValue -Name 'domainName' -ErrorAction Stop).Parameters[0].Value
        $domainJoinUserName = (Get-SSMParameterValue -Name 'domainJoinUserName' -ErrorAction Stop).Parameters[0].Value
        $domainJoinPassword = (Get-SSMParameterValue -Name 'domainJoinPassword' -WithDecryption:$true -ErrorAction Stop).Parameters[0].Value | ConvertTo-SecureString -AsPlainText -Force
    } Catch [System.Exception] {
        Write-Output "Failed to get SSM Parameter(s) $_"
    }

    $domainCredential = New-Object System.Management.Automation.PSCredential($domainJoinUserName, $domainJoinPassword)

    If (-not (Get-WindowsFeature -Name 'RSAT-AD-Tools' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty 'Installed')) {
        Write-Output 'Installing RSAT AD Tools to allow domain joining'
        Try {
            $Null = Add-WindowsFeature -Name 'RSAT-AD-Tools' -ErrorAction Stop
        } Catch [System.Exception] {
            Write-Output "Failed to install RSAT AD Tools $_"
            Exit 1
        }    
    }
    
    $getADComputer = (Get-ADComputer -Identity $env:COMPUTERNAME -Credential $domainCredential)
    $distinguishedName = $getADComputer.DistinguishedName

    Try {
        Remove-Computer -ComputerName $env:COMPUTERNAME -UnjoinDomainCredential $domainCredential -Verbose -Force -Restart:$false -ErrorAction Stop
        Remove-ADComputer -Credential $domainCredential -Identity $distinguishedName -Server $domainName -Confirm:$False -Verbose -ErrorAction Stop
    } Catch [System.Exception] {
        Write-Output "Failed to remove $env:COMPUTERNAME from the $domainName domain and in a Windows Workgroup. $_"
        Exit 1
    }  
}
} Else {
    Write-Output "$env:COMPUTERNAME is not part of the Active Directory domain $domainName and already part of a Windows Workgroup."
    Exit 0
}
