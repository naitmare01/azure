function New-AzureRMDefaultVM{
<#
.Synopsis
Creates a default VM with Windows server from the marketplace at Azure.
.DESCRIPTION

.NOTES   

.LINK
https://github.com/naitmare01/azure/tree/master/New-AzureRMDefaultVM

.PARAMETER Location
Specifies the location for the resources to be located in. Default is West Europe.

.PARAMETER Tags
Specifies which tag the resource will be tagged with. Default is "Environmen:Demo"

.PARAMETER Size
Specifies the Size of the VM. Default is Standard_D2s_v3.

.EXAMPLE

#>
    [CmdletBinding()]
    param(
        $Location = "west europe",
        $Tags = @{Environment="Demo"},
        $RgName = "LabRG",
        $Size = "Standard_D2s_v3"
    )#End Param
    
    begin{
        #Get ResourcegroupName
        $ResourceGroups = Get-AzureRmResourceGroup | Where-Object{$_.ResourceGroupName -like "$RgName*"}
        if($ResourceGroups -eq $null){
            $ResourceGroupName = $RgName + "1"
        }#End if
        else{
            $FreeResourceGroupName = ($ResourceGroups.resourcegroupname | Sort-Object)

            if(($ResourceGroups | Measure-Object).count -gt 1){
                $FreeResourceGroupName = $FreeResourceGroupName[-1]
            }#End if

            [int]$FreeResourceGroupNumber = $FreeResourceGroupName.Split($FreeResourceGroupName.Substring(0,5))[-1]
            $FreeResourceGroupNumber = $FreeResourceGroupNumber + 1
            $ResourceGroupName = "$RgName$FreeResourceGroupNumber"
        }#End else

        $ReturnArray = [System.Collections.ArrayList]@()

    }#End begin
    
    process{
        #Confirmation
        $Answer = Read-Host "This will create a Resource Group, a VM and a virtual network, do you want to proceed? [Y/N]"

        if($Answer -like "y"){
            #Create the resourcegroup
            Write-Verbose "Creating the resourcegroup $ResourceGroupName..."
            $null = New-AzureRmResourceGroup -Name $ResourceGroupName -Tag $Tags -Location $Location

            #Create and configure the virtual network
            $vnetName = $ResourceGroupName + "-vnet"
            $nsgName = $ResourceGroupName + "-nsg"
            Write-Verbose "Creating the virtual network $vnetname..."
            $Nsgrule1 = New-AzureRmNetworkSecurityRuleConfig -Name rdp-rule -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389
            $nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Location $Location -Name $nsgName -SecurityRules $Nsgrule1 -Tag $Tags
            $virtualNetwork = New-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroupName -Location $Location -Name $vnetName -AddressPrefix 10.0.0.0/16 -Tag $Tags
            $null = Add-AzureRmVirtualNetworkSubnetConfig -Name default -AddressPrefix 10.0.0.0/24 -VirtualNetwork $virtualNetwork -NetworkSecurityGroup $nsg
            $null = $virtualNetwork | Set-AzureRmVirtualNetwork
            $NIC = New-AzureRmNetworkInterface -Name "default" -ResourceGroupName $ResourceGroupName -Location $Location -SubnetId ((Get-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroupName).subnets.id)

            #Create and config the vm
            $VMName = $ResourceGroupName + "-vm"
            Write-Verbose "Creating the vm $VMName..."
            $VMLocalAdminUser = "LocalAdminUser"
            $Password = Read-Host "Enter password for the localadmin account"
            $VMLocalAdminSecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword)
            $VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $Size
            $VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VMName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
            $VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
            $VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2016-Datacenter' -Version latest
            $null = New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $VirtualMachine -Tag $Tags

            #Get the public IP of the VM 
            Write-Verbose "Getting public ip of the vm $VMName..."
            $PublicIP = Get-AzureRmPublicIpAddress -Name $VMName -ResourceGroupName $ResourceGroupName

        }#End if
        else{
            return
        }


        #Construct custom Object
        $CustomObject = New-Object System.Object
        $CustomObject | Add-Member -Type NoteProperty -Name "ResourceGroupName" -Value $ResourceGroupName
        $CustomObject | Add-Member -Type NoteProperty -Name "VM Name" -Value $VMName
        $CustomObject | Add-Member -Type NoteProperty -Name "VMLocalAdminUser" -Value $VMLocalAdminUser
        $CustomObject | Add-Member -Type NoteProperty -Name "VM Public IP" -Value $PublicIP.IpAddress
        $CustomObject | Add-Member -Type NoteProperty -Name "VNet Name" -Value $vnetName
        $CustomObject | Add-Member -Type NoteProperty -Name "Tag" -Value $tags['Environment']
        $null = $ReturnArray.Add($CustomObject)

    }#End process
    
    end{
        return $ReturnArray
    }#End end
}
