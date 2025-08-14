# ClickOnce kurulum projesi oluşturma scripti

# Değişkenler
$publisherName = "PGD"
$productName = "PGD Word Add-in"
$version = "1.0.0"
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$projectPath = Split-Path -Parent $scriptPath
$outputPath = Join-Path $projectPath "publish"
$manifestPath = Join-Path $projectPath "manifest.xml"
$distPath = Join-Path $projectPath "dist"
$appFilesPath = Join-Path $outputPath "Application Files"
$versionFolderName = "PGD_Word_Add-in_$($version.Replace('.', '_'))"
$applicationFilesPath = Join-Path $appFilesPath $versionFolderName

# Klasörleri temizle ve yeniden oluştur
Remove-Item -Path $outputPath -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
New-Item -ItemType Directory -Force -Path $applicationFilesPath | Out-Null

# Dist klasöründeki dosyaları kopyala
Copy-Item -Path "$distPath\*" -Destination $applicationFilesPath -Recurse -Force
Copy-Item -Path $manifestPath -Destination $applicationFilesPath -Force

# Her dosyayı .deploy uzantısıyla yeniden adlandır
Get-ChildItem -Path $applicationFilesPath -Recurse -File | ForEach-Object {
    Move-Item -Path $_.FullName -Destination "$($_.FullName).deploy" -Force
}

# Application manifest oluştur
$appManifestContent = @"
<?xml version="1.0" encoding="utf-8"?>
<asmv1:assembly manifestVersion="1.0" xmlns="urn:schemas-microsoft-com:asm.v1" xmlns:asmv1="urn:schemas-microsoft-com:asm.v1" xmlns:asmv2="urn:schemas-microsoft-com:asm.v2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <assemblyIdentity version="$version" name="$productName.dll"/>
  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v2">
    <security>
      <applicationRequestMinimum>
        <PermissionSet version="1" ID="Custom" SameSite="site" />
        <defaultAssemblyRequest permissionSetReference="Custom" />
      </applicationRequestMinimum>
      <requestedPrivileges xmlns="urn:schemas-microsoft-com:asm.v3">
        <requestedExecutionLevel level="asInvoker" uiAccess="false" />
      </requestedPrivileges>
    </security>
  </trustInfo>
  <dependency>
    <dependentAssembly>
      <assemblyIdentity type="win32" name="Microsoft.Windows.Common-Controls" version="6.0.0.0" processorArchitecture="*" publicKeyToken="6595b64144ccf1df" language="*" />
    </dependentAssembly>
  </dependency>
  <dependency>
    <dependentAssembly>
      <assemblyIdentity type="win32" name="Microsoft.Office.Tools" version="10.0.0.0" publicKeyToken="b03f5f7f11d50a3a" processorArchitecture="msil" />
    </dependentAssembly>
  </dependency>
  <compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1">
    <application>
      <supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}"/>
    </application>
  </compatibility>
</asmv1:assembly>
"@
$appManifestContent | Out-File -FilePath (Join-Path $applicationFilesPath "app.manifest") -Encoding UTF8

# Setup.application oluştur
$setupAppContent = @"
<?xml version="1.0" encoding="utf-8"?>
<asmv1:assembly xsi:schemaLocation="urn:schemas-microsoft-com:asm.v1 assembly.adaptive.xsd" manifestVersion="1.0" xmlns:asmv1="urn:schemas-microsoft-com:asm.v1" xmlns="urn:schemas-microsoft-com:asm.v2" xmlns:asmv2="urn:schemas-microsoft-com:asm.v2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:co.v1="urn:schemas-microsoft-com:clickonce.v1">
  <assemblyIdentity name="$productName.application" version="$version" publicKeyToken="0000000000000000" language="neutral" processorArchitecture="msil" xmlns="urn:schemas-microsoft-com:asm.v1" />
  <description asmv2:publisher="$publisherName" co.v1:suiteName="$productName" asmv2:product="$productName" xmlns="urn:schemas-microsoft-com:asm.v1" />
  <deployment install="true" mapFileExtensions="true" minimumRequiredVersion="$version">
    <subscription>
      <update>
        <beforeApplicationStartup />
      </update>
    </subscription>
    <deploymentProvider codebase="https://pgdwordaddin.azurewebsites.net/setup.application" />
  </deployment>
  <compatibleFrameworks xmlns="urn:schemas-microsoft-com:clickonce.v2">
    <framework targetVersion="4.7.2" profile="Full" supportedRuntime="4.0.30319" />
  </compatibleFrameworks>
  <dependency>
    <dependentAssembly dependencyType="install" codebase="Application Files/$versionFolderName/app.manifest">
      <assemblyIdentity name="$productName.app" version="$version" publicKeyToken="0000000000000000" language="neutral" processorArchitecture="msil" type="win32" />
      <hash>
        <dsig:Transforms xmlns:dsig="http://www.w3.org/2000/09/xmldsig#">
          <dsig:Transform Algorithm="urn:schemas-microsoft-com:HashTransforms.Identity" />
        </dsig:Transforms>
        <dsig:DigestMethod xmlns:dsig="http://www.w3.org/2000/09/xmldsig#" Algorithm="http://www.w3.org/2000/09/xmldsig#sha256" />
        <dsig:DigestValue xmlns:dsig="http://www.w3.org/2000/09/xmldsig#">placeholder</dsig:DigestValue>
      </hash>
    </dependentAssembly>
  </dependency>
</asmv1:assembly>
"@
$setupAppContent | Out-File -FilePath (Join-Path $outputPath "setup.application") -Encoding UTF8

Write-Host "ClickOnce kurulum projesi başarıyla oluşturuldu: $outputPath" -ForegroundColor Green
Write-Host "`nKurulum dosyaları:" -ForegroundColor Yellow
Write-Host "- setup.application" -ForegroundColor White
Write-Host "- Application Files\$versionFolderName\" -ForegroundColor White

Write-Host "`nYapılacaklar:" -ForegroundColor Yellow
Write-Host "1. 'publish' klasöründeki tüm dosyaları web sunucunuza yükleyin" -ForegroundColor White
Write-Host "2. Web sunucunuzdaki setup.application dosyasını kullanarak eklentiyi dağıtın" -ForegroundColor White
