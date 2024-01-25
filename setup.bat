@echo off
CHCP 65001
SETLOCAL

:: Dossier où sont stockés les fichiers de configuration
SET "ConfigDir=%~dp0ConfigFiles"

:: Vérifier si le dossier de configuration existe
IF NOT EXIST "%ConfigDir%" (
    echo Le dossier de configuration %ConfigDir% n'existe pas.
    exit /b
)

:: Nom du fichier de certificat
SET "CertFileName=Create-ADUsersFromCSV.cer"

:: Chemin complet du certificat
SET "CertFilePath=%ConfigDir%\%CertFileName%"

:: Importer le certificat dans le magasin de certificats de la machine
certutil -addstore -f "Root" "%CertFilePath%"

:: Vérifier si l'importation a réussi
IF %ERRORLEVEL% EQU 0 (
    echo Certificat importé avec succès.
) ELSE (
    echo Erreur lors de l'importation du certificat.
)

:: Demander à l'utilisateur s'il souhaite modifier la politique d'exécution de PowerShell
echo =================================================================
echo Voulez-vous modifier la politique d'exécution de PowerShell pour autoriser les scripts signés (AllSigned)?
echo (Y)es - Modifier la politique d'exécution
echo (N)o - Ne pas modifier
set /p UserChoice=Votre choix [Y/N]: 

IF /I "%UserChoice%"=="Y" (
    powershell -Command "Set-ExecutionPolicy -ExecutionPolicy AllSigned -Scope CurrentUser -Force"
    IF %ERRORLEVEL% EQU 0 (
    echo Politique d'exécution modifiée avec succès.
    ) ELSE (
        echo Erreur lors de la modification de la politique d'exécution.
    )
) ELSE IF /I "%UserChoice%"=="N" (
    echo Modification de la politique d'exécution ignorée.
) ELSE (
    echo Choix non valide, veuillez entrer Y ou N.
    goto :eof
)

:: Demander à l'utilisateur s'il souhaite installer le module RSAT Active Directory
echo =================================================================
echo Voulez-vous installer le module RSAT Active Directory?
echo (Y)es - Installer le module RSAT AD
echo (N)o - Ne pas installer
set /p UserChoice=Votre choix [Y/N]: 

IF /I "%UserChoice%"=="Y" (
    powershell -Command "Install-WindowsFeature RSAT-AD-PowerShell"
    IF %ERRORLEVEL% EQU 0 (
    echo Module RSAT Active Directory installé avec succès.
    ) ELSE (
        echo Erreur lors de l'installation du module RSAT Active Directory.
    )
    echo Module RSAT Active Directory installe.
) ELSE IF /I "%UserChoice%"=="N" (
    echo Installation du module RSAT AD ignorée.
) ELSE (
    echo Choix non valide, veuillez entrer Y ou N.
    goto :eof
)

echo Fin du setup.
pause
ENDLOCAL
