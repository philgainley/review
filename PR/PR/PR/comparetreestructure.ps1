$version = "8.2."

$path1 = "C:\Users\pga\Desktop\Phil\projects\sitecoreTools\PowerShellProject1\Review\tocompare\82u0\"
$path2 = ""

cls;

$setone = Get-ChildItem -Recurse -path $path1

$settwo = Get-ChildItem -Recurse -path $path2
Write-Host -ForegroundColor Green 'Comparing folders'
Compare-Object -ReferenceObject $setone -DifferenceObject $settwo
Write-Host -ForegroundColor Green 'Extra Added In Web.config'
Compare-Object -ReferenceObject $(Get-Content $($path1+"\web.config")) -DifferenceObject $(Get-Content $($path2+"\web.config"))