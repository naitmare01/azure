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
            $pip = New-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName -Location $Location -Name ($ResourceGroupName + "-pip") -AllocationMethod Dynamic -IdleTimeoutInMinutes 4
            $NIC = New-AzureRmNetworkInterface -Name "default" -ResourceGroupName $ResourceGroupName -Location $Location -SubnetId ((Get-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroupName).subnets.id) -PublicIpAddressId $pip.Id

            #Create and config the vm
            $VMName = $ResourceGroupName + "-vm"
            Write-Verbose "Creating the vm $VMName..."
            $Credential = Get-Credential -Message "Type the name and password of the local administrator account for $VMName."
            $VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $Size
            $VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VMName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
            $VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
            $VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2016-Datacenter' -Version latest
            $StorageAcc = New-AzureRmStorageAccount -Name ($ResourceGroupName.ToLower() + "storage") -ResourceGroupName $ResourceGroupName –Type Standard_LRS -Location $location -Tag $Tags
            $OSDiskUri = $StorageAcc.PrimaryEndpoints.Blob.ToString() + "vhds/" + $VMName + "osdisk" + ".vhd"
            $VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -Name $VMName -VhdUri $OSDiskUri -CreateOption fromImage
            $null = New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $VirtualMachine -Tag $Tags
            
        }#End if
        else{
            return
        }

        #Construct custom Object
        $CustomObject = New-Object System.Object
        $CustomObject | Add-Member -Type NoteProperty -Name "ResourceGroupName" -Value $ResourceGroupName
        $CustomObject | Add-Member -Type NoteProperty -Name "VM Name" -Value $VMName
        $CustomObject | Add-Member -Type NoteProperty -Name "VMLocalAdminUser" -Value $Credential.UserName
        $CustomObject | Add-Member -Type NoteProperty -Name "VM Public IP" -Value $pip.IpAddress    
        $CustomObject | Add-Member -Type NoteProperty -Name "VNet Name" -Value $vnetName
        $CustomObject | Add-Member -Type NoteProperty -Name "Tag" -Value $tags['Environment']
        $null = $ReturnArray.Add($CustomObject)

    }#End process
    
    end{
        return $ReturnArray
    }#End end
}
