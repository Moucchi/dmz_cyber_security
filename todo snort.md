1. manisy copie an'ilay fichier de configuration original ( sao dia misy erreur )
```bash
cp /etc/snort/snort.conf /etc/snort/snort.conf.bak
```

2. mametaka ny adresse ip an'ilay dmz en tant que local ( 19.4.3.9 ny ana eto )
```bash
sed -i 's/^ipvar HOME_NET.*/ipvar HOME_NET 19.4.3.9/' /etc/snort/snort.conf
sed -i 's/^ipvar EXTERNAL_NET.*/ipvar EXTERNAL_NET !$HOME_NET/' /etc/snort/snort.conf
```

3. manampy an'ilay type d'output ( log ) amin'ny fichier de configuration an'ny snort (snort.conf)
```bash
nano /etc/snort/snort.conf
# manao recherche hoe "unified2" : 'ctrl w' ny manao azy sur linux dia apetaka ilay type ana output : efa misy anakiray par defaut mandeha ao : ilay unufied2 fa afaka ampiana hafa ( http://manual-snort-org.s3-website-us-east-1.amazonaws.com/node21.html )
```

4. micreer regle personnalisée amin'ilay fichier local.rules
```text 
mandeha any amin'ny https://snorpy.cyb3rs3c.net/ na manontany chatgpt
```
5. mi créer ny dossier asiana an'ilay log ( izay notenenina tao amin'ilay output teo)

6. manome permission an'ilay groupe sy user "snort" amin'ilay dossier misy log

8. Verifier-na ilay configuration 
```bash
snort -T -c /etc/snort/snort.conf -i eth0
```

9. raha tsy misy erreur dia alefa ilay snort ( '/var/log/snort/' ny ana eto ny chemin makany amin'ilay dossier asina an'ilay log)
```bash
snort -A console -q -u snort -g snort -c /etc/snort/snort.conf -l /var/log/snort/ -i eth0
```