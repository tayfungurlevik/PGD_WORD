param(
    [string]$publishUrl = "https://tayfungurlevik.github.io/PGD_WORD/",
    [string]$certificateFileName = "PGD_Word_Addin.pfx",
    [SecureString]$certificatePassword = (ConvertTo-SecureString -String "1234" -Force -AsPlainText)
)

$ErrorActionPreference = "Stop"

# Variables
$projectName = "PGD_Word_Add-in"
$version = "1.0.0"
$manufacturer = "PGD"
$productName = "PGD Word Add-in"
$publishDir = Join-Path $PSScriptRoot "..\publish"
$distDir = Join-Path $PSScriptRoot "..\dist"

# Create certificate if it doesn't exist
if (-not (Test-Path $certificateFileName)) {
    $cert = New-SelfSignedCertificate -Subject "CN=PGD Word Add-in" -Type CodeSigningCert -CertStoreLocation "Cert:\CurrentUser\My"
    $certPath = "Cert:\CurrentUser\My\$($cert.Thumbprint)"
    Export-PfxCertificate -Cert $certPath -FilePath $certificateFileName -Password $certificatePassword
}

# Build the project
Write-Host "Building project..."
npm run build

# Create application manifest
$appManifestXml = @"
<?xml version="1.0" encoding="utf-8"?>
<asmv1:assembly xsi:schemaLocation="urn:schemas-microsoft-com:asm.v1 assembly.adaptive.xsd" manifestVersion="1.0" xmlns:asmv1="urn:schemas-microsoft-com:asm.v1" xmlns="urn:schemas-microsoft-com:asm.v2" xmlns:asmv2="urn:schemas-microsoft-com:asm.v2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:co.v1="urn:schemas-microsoft-com:clickonce.v1" xmlns:asmv3="urn:schemas-microsoft-com:asm.v3" xmlns:dsig="http://www.w3.org/2000/09/xmldsig#" xmlns:co.v2="urn:schemas-microsoft-com:clickonce.v2">
  <asmv1:assemblyIdentity name="$projectName.dll" version="$version" publicKeyToken="0000000000000000" language="neutral" processorArchitecture="msil" type="win32" />
  <description asmv2:publisher="$manufacturer" asmv2:product="$productName" xmlns="urn:schemas-microsoft-com:asm.v1" />
  <deployment install="true" mapFileExtensions="true">
    <subscription>
      <update>
        <beforeApplicationStartup />
      </update>
    </subscription>
    <deploymentProvider codebase="$publishUrl/$projectName.application" />
  </deployment>
</asmv1:assembly>
"@

# Create deployment manifest
$deploymentManifestXml = @"
<?xml version="1.0" encoding="utf-8"?>
<asmv1:assembly xsi:schemaLocation="urn:schemas-microsoft-com:asm.v1 assembly.adaptive.xsd" manifestVersion="1.0" xmlns:asmv1="urn:schemas-microsoft-com:asm.v1" xmlns="urn:schemas-microsoft-com:asm.v2" xmlns:asmv2="urn:schemas-microsoft-com:asm.v2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:co.v1="urn:schemas-microsoft-com:clickonce.v1" xmlns:asmv3="urn:schemas-microsoft-com:asm.v3" xmlns:dsig="http://www.w3.org/2000/09/xmldsig#" xmlns:co.v2="urn:schemas-microsoft-com:clickonce.v2">
  <assemblyIdentity name="$projectName.application" version="$version" publicKeyToken="0000000000000000" language="neutral" processorArchitecture="msil" xmlns="urn:schemas-microsoft-com:asm.v1" />
  <description asmv2:publisher="$manufacturer" asmv2:product="$productName" xmlns="urn:schemas-microsoft-com:asm.v1" />
  <deployment install="true" mapFileExtensions="true">
    <subscription>
      <update>
        <beforeApplicationStartup />
      </update>
    </subscription>
    <deploymentProvider codebase="$publishUrl/$projectName.application" />
  </deployment>
  <compatibleFrameworks xmlns="urn:schemas-microsoft-com:clickonce.v2">
    <framework targetVersion="4.8" profile="Full" supportedRuntime="4.0.30319" />
  </compatibleFrameworks>
  <dependency>
    <dependentAssembly dependencyType="install" codebase="Application Files\\$($projectName)_$($version.Replace('.', '_'))\\$projectName.dll.manifest" size="0">
      <assemblyIdentity name="$projectName.dll" version="$version" publicKeyToken="0000000000000000" language="neutral" processorArchitecture="msil" type="win32" />
      <hash>
        <dsig:Transforms>
          <dsig:Transform Algorithm="urn:schemas-microsoft-com:HashTransforms.Identity" />
        </dsig:Transforms>
        <dsig:DigestMethod Algorithm="http://www.w3.org/2000/09/xmldsig#sha256" />
        <dsig:DigestValue></dsig:DigestValue>
      </hash>
    </dependentAssembly>
  </dependency>
</asmv1:assembly>
"@

# Create publish directory structure
$versionFolder = $version.Replace(".", "_")
$appFilesDir = Join-Path $publishDir "Application Files\$($projectName)_$versionFolder"
New-Item -ItemType Directory -Path $appFilesDir -Force | Out-Null

# Copy files to publish directory
Remove-Item -Path $appFilesDir\* -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item "$distDir\*" -Destination $appFilesDir -Recurse -Force
Get-ChildItem -Path $appFilesDir -Recurse -File | ForEach-Object {
    $newName = "$($_.Name).deploy"
    if (-not (Test-Path (Join-Path (Split-Path $_.FullName) $newName))) {
        Rename-Item -Path $_.FullName -NewName $newName -Force
    }
}

# Save manifests
$appManifestPath = Join-Path $appFilesDir "$projectName.dll.manifest"
$deploymentManifestPath = Join-Path $publishDir "$projectName.application"
$appManifestXml | Out-File -FilePath $appManifestPath -Encoding UTF8
$deploymentManifestXml | Out-File -FilePath $deploymentManifestPath -Encoding UTF8

# Temporarily skip signing
Write-Host "Skipping manifest signing for now..."

Write-Host "COM installer created successfully at: $publishDir"
