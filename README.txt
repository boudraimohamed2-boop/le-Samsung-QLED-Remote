Samsung QLED Remote — application iPhone native (SwiftUI)

Pour compiler :
1. Sur un Mac, ouvrir Xcode, créer un projet iOS App (SwiftUI, Swift).
2. Remplacer le fichier App Swift créé par SamsungQLEDRemoteApp.swift.
3. Dans les réglages de la cible, ajouter la clé Privacy - Local Network Usage Description
   avec le texte fourni dans Info.plist. Ajouter NSAppTransportSecurity/NSAllowsLocalNetworking si nécessaire.
4. Choisir votre équipe de signature et installer sur votre iPhone.
5. Sur la TV : Paramètres > Réseau > État du réseau pour trouver son adresse IP.
6. Connecter l'iPhone au même Wi-Fi et autoriser l'accès sur l'écran Samsung.

Cette application utilise le protocole WebSocket Samsung sur le port 8002.
Elle est un prototype non testé sur votre modèle exact.
Certaines TV utilisent d'autres protocoles ou réglages; l'allumage peut nécessiter Wake-on-LAN.
La validation du certificat auto-signé est limitée à l'IP saisie et au port 8002.
