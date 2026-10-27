# Firma un .exe con el certificado de firma de código de Capital (está en Cert:\CurrentUser\My de esta PC, con el
# nombre "Capital - firma de código"). Lo usan armar.ps1 y Inno Setup (para el instalador y el desinstalador).
# Uso: powershell -File firmar.ps1 <archivo.exe>
param([Parameter(Mandatory = $true)][string]$Archivo)

$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert |
	Where-Object { $_.FriendlyName -eq "Capital - firma de código" } | Select-Object -First 1
if (-not $cert) { Write-Error "No está el certificado de Capital en esta PC."; exit 1 }
# El sello de tiempo hace que la firma siga valiendo aunque el certificado venza
$r = Set-AuthenticodeSignature -FilePath $Archivo -Certificate $cert -HashAlgorithm SHA256 `
	-TimestampServer "http://timestamp.digicert.com"
if (-not $r.SignerCertificate) { Write-Error "No se pudo firmar $Archivo : $($r.StatusMessage)"; exit 1 }
Write-Output "Firmado: $Archivo"
exit 0
