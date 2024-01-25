# Créer un certificat de signature de code auto-signé
## Créer un certificat de signature de code :
```PowerShell
$cert = New-SelfSignedCertificate -DnsName "VotreNomCertificat" -CertStoreLocation "cert:\CurrentUser\My" -KeyUsage DigitalSignature -Type CodeSigningCert
```
## Vérifier le certificat :
```PowerShell
Get-ChildItem cert:\CurrentUser\My -CodeSigningCert
```
## Exporter le certificat (optionnel) :
```PowerShell
Export-Certificate -Cert $cert -FilePath "C:\chemin\vers\certificat.cer"
```
## Signer votre script PowerShell :
```PowerShell
Set-AuthenticodeSignature "C:\chemin\vers\script.ps1" $cert
```