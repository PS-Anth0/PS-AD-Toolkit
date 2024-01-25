# Comment créer un certificat de signature de code auto-signé pour un script PowerShell
## Ouvrir PowerShell avec des privilèges d'administrateur
### Créer un certificat
```PowerShell
$cert = New-SelfSignedCertificate -DnsName "VotreNomCertificat" -CertStoreLocation "cert:\CurrentUser\My" -KeyUsage DigitalSignature -Type CodeSigningCert
```
**-DnsName** est le nom du certificat. 
**-CertStoreLocation** spécifie où le certificat sera stocké (dans ce cas, dans le magasin personnel de l'utilisateur actuel). 
**-KeyUsage** définit l'usage de la clé comme signature numérique, et -Type spécifie qu'il s'agit d'un certificat de signature de code. 
### Vérifier le certificat
```PowerShell
Get-ChildItem cert:\CurrentUser\My -CodeSigningCert
```
### Exporter le certificat (optionnel)
Si vous avez besoin d'exporter le certificat (par exemple, pour l'utiliser sur une autre machine), utilisez :
```PowerShell
Export-Certificate -Cert $cert -FilePath "C:\chemin\vers\certificat.cer"
```
### Signer votre script PowerShell
```PowerShell
Set-AuthenticodeSignature "C:\chemin\vers\script.ps1" $cert
```

**Remarque importante :** Gardez à l'esprit que les certificats auto-signés ne sont pas vérifiés par une autorité de certification (CA) externe. Ils sont généralement utilisés à des fins de test et de développement. Pour un environnement de production, il est conseillé d'utiliser un certificat émis par une CA reconnue.