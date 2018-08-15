Creates a vnet(10.0.0.0/16) with 4 subnet and default NSG associated with all subnets. 
</br>
</br>
The subnets is called DC, App, Web and SQL. 
</br>
</br>
Subnets are: 10.0.0.0/24-10.0.3.0/24
</br>
</br>
<b>#1.<b> Edit <i>parameters.json</i>, change null to desired value. 
</br>
</br>
<b>#2.</b> Run <i>deploy.ps1</i>, <i>deploy.sh</i>, <i>DeploymentHelper.cs</i> or <i>deployer.rb</i>
</br>
</br>
<b>#3.</b> Optionall, copy <i>deploy.ps1</i> to <b>Templates</b> in the Azure Portal and deploy the template from the portal. 
