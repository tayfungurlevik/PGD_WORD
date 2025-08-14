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

# VSTO kurulum araçlarını kontrol et
$vstoPath = "${env:ProgramFiles(x86)}\Common Files\microsoft shared\VSTO\10.0\VSTOInstaller.exe"
if (-not (Test-Path $vstoPath)) {
    Write-Error "VSTO Runtime bulunamadı. Lütfen yükleyin: https://www.microsoft.com/en-us/download/details.aspx?id=56961"
    exit 1
}

# Manifest dosyasını kopyala
Copy-Item $manifestPath $outputPath -Force

# Sertifika varsa kullan, yoksa yeni oluştur
$cert = Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert | Where-Object {$_.Subject -eq "CN=$publisherName"} | Select-Object -First 1
if (-not $cert) {
    $cert = New-SelfSignedCertificate -Subject "CN=$publisherName" -Type CodeSigning -CertStoreLocation "Cert:\CurrentUser\My" -KeyUsage DigitalSignature -KeySpec Signature
}

# Application Files klasörüne gerekli dosyaları kopyala
Copy-Item $distPath\* $applicationFilesPath -Recurse
Copy-Item $manifestPath $applicationFilesPath

# Tüm dosyaları .deploy uzantısıyla yeniden adlandır
Get-ChildItem -Path $applicationFilesPath -Recurse -File | ForEach-Object {
    Move-Item $_.FullName "$($_.FullName).deploy"
}

# ClickOnce application manifest ve setup.application oluştur
$applicationManifest = @"
<?xml version="1.0" encoding="utf-8"?>
<asmv1:assembly xsi:schemaLocation="urn:schemas-microsoft-com:asm.v1 assembly.adaptive.xsd" manifestVersion="1.0" xmlns:asmv1="urn:schemas-microsoft-com:asm.v1" xmlns="urn:schemas-microsoft-com:asm.v2" xmlns:asmv2="urn:schemas-microsoft-com:asm.v2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:co.v1="urn:schemas-microsoft-com:clickonce.v1" xmlns:asmv3="urn:schemas-microsoft-com:asm.v3" xmlns:dsig="http://www.w3.org/2000/09/xmldsig#" xmlns:co.v2="urn:schemas-microsoft-com:clickonce.v2">
  <asmv1:assemblyIdentity name="$productName" version="$version" publicKeyToken="0000000000000000" language="neutral" processorArchitecture="msil" type="win32" />
  <description asmv2:publisher="$publisherName" asmv2:product="$productName" xmlns="urn:schemas-microsoft-com:asm.v1" />
  <deployment install="true" mapFileExtensions="true">
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
    <dependentAssembly dependencyType="preRequisite" allowDelayedBinding="true">
      <assemblyIdentity name="Microsoft.Office.Tools" version="10.0.0.0" publicKeyToken="b03f5f7f11d50a3a" language="neutral" processorArchitecture="msil" />
    </dependentAssembly>
  </dependency>
</asmv1:assembly>
"@

$setupApplication = @"
<?xml version="1.0" encoding="utf-8"?>
<asmv1:assembly xsi:schemaLocation="urn:schemas-microsoft-com:asm.v1 assembly.adaptive.xsd" manifestVersion="1.0" xmlns:asmv1="urn:schemas-microsoft-com:asm.v1" xmlns="urn:schemas-microsoft-com:asm.v2" xmlns:asmv2="urn:schemas-microsoft-com:asm.v2" xmlns:xrml="urn:mpeg:mpeg21:2003:01-REL-R-NS" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:asmv3="urn:schemas-microsoft-com:asm.v3" xmlns:dsig="http://www.w3.org/2000/09/xmldsig#" xmlns:co.v1="urn:schemas-microsoft-com:clickonce.v1" xmlns:co.v2="urn:schemas-microsoft-com:clickonce.v2">
  <assemblyIdentity name="$productName.application" version="$version" publicKeyToken="0000000000000000" language="neutral" processorArchitecture="msil" xmlns="urn:schemas-microsoft-com:asm.v1" />
  <description asmv2:publisher="$publisherName" asmv2:product="$productName" xmlns="urn:schemas-microsoft-com:asm.v1" />
  <deployment install="true" mapFileExtensions="true">
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
    <dependentAssembly dependencyType="install" codebase="Application Files/PGD_Word_Add-in_$($version.Replace('.', '_'))/PGD Word Add-in.dll.manifest" size="0">
      <assemblyIdentity name="$productName.exe" version="$version" publicKeyToken="0000000000000000" language="neutral" processorArchitecture="msil" type="win32" />
      <hash>
        <dsig:Transforms>
          <dsig:Transform Algorithm="urn:schemas-microsoft-com:HashTransforms.Identity" />
        </dsig:Transforms>
        <dsig:DigestMethod Algorithm="http://www.w3.org/2000/09/xmldsig#sha256" />
        <dsig:DigestValue>placeholder</dsig:DigestValue>
      </hash>
    </dependentAssembly>
  </dependency>
</asmv1:assembly>
"@

# Manifest dosyalarını oluştur
$applicationManifest | Out-File "$outputPath\application.manifest" -Encoding UTF8
$setupApplication | Out-File "$outputPath\setup.application" -Encoding UTF8

# Sign the manifests
try {
    Set-AuthenticodeSignature "$outputPath\application.manifest" $cert -ErrorAction Stop
    Set-AuthenticodeSignature "$applicationFilesPath\PGD Word Add-in.dll.manifest" $cert -ErrorAction Stop
    Set-AuthenticodeSignature "$outputPath\setup.application" $cert -ErrorAction Stop
    Write-Host "Manifests başarıyla imzalandı."
} catch {
    Write-Warning "Manifest imzalama hatası: $_"
}

Write-Host "ClickOnce kurulum projesi oluşturuldu: $outputPath"
Write-Host "Lütfen şunları yapın:"
Write-Host "1. Dosyaları bir web sunucusuna yükleyin"
Write-Host "2. Web sunucusundaki manifest.xml dosyasını Word'de kullanarak eklentiyi yükleyin"
