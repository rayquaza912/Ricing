# GnuPG Messages Manager

![alt text](https://github.com/rayquaza912/Ricing/raw/master/gpg-mm-3.gif "gpg-mm screen")

#### Gpg-messages-manager is an interactive bash script that lets you manage messages and recipients for use with GnuPG. It is powered by [fzf](https://github.com/junegunn/fzf) and provides the following features :

* Show GPG keyring
* Generate a new key pair
* Import a public key
* Export a public key
* Remove a public key
* Encrypt your address
* Encrypt a message
* Decrypt a message
* Sign a file
* Verify a file

The architecture of your `gpgDir` must match this tree in order to make the utility working.
```
.
├── asc
│   ├── adr_for_antoine.asc
│   ├── adr_for_aurelien.asc
│   ├── msg_for_antoine_20191015_182013.asc
│   ├── msg_for_antoine_20191015_203924.asc
│   ├── msg_for_aurelien_20191023_013644.asc
│   └── msg_for_aurelien_20191202_013102.asc
├── pub
│   ├── polandteam_pub.asc
│   ├── grenouille_rouge.asc
│   └── madeingermany_pub.asc
├── sig
│   ├── adr_for_antoine_rayquaza.asc.sig
│   ├── adr.txt.sig
│   └── msg_for_aurleien.txt.sig
└── txt
    ├── adr.txt
    ├── msg_for_antoine_20191015_203924.asc.txt
    ├── msg_for_antoine_20191107_165132.asc.txt
    └── msg_for_antoine_20191108_141425.asc.txt
```

By default, it refers to `~/Documents/pgp/`, where
* `asc` is your encrypted files folder, it contains addresses or messages in plain ASCII PGP.
* `pub` is where you put your recipients public key.
* `sig` is your signed files folder.
* `txt` is your decrypted messages folder. It also contains your plain addresse text.

Here is the common output when you launch the script :

```
Welcome to GnuPG !

[0] Show keyring
[1] Generate a new public key
[2] Import a public key
[3] Export a public key
[4] Remove a public key
[5] Encrypt your addresse
[6] Encrypt a message
[7] Decrypt a message
[8] Sign a file
[9] Verify a file

[!] Exit

>>>

```

