

"C:\Program Files (x86)\IIS\Microsoft Web Deploy V3\msdeploy" -verb=sync -source:package="C:\projects\review\PR\output\v1-ProductionSlot\deploymentslotdemo.zip" -dest:auto,Computername=https://pga-demoworkshop-appname.scm.azurewebsites.net:443/msdeploy.axd?site='pga-demoworkshop-appname',Username='$pga-demoworkshop-appname',Password='KZK3ZRkoqjsTdZ9ooRGZHCxpMTmemgpCfKkDlFovL4AFYdakJ1iX5pS2nql7',AuthType='Basic' -enableRule:DoNotDeleteRule -allowUntrusted